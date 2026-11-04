//
//  AppInfo.swift
//  PASKitCore
//
//  Static, app-agnostic access to the running app's bundle metadata.
//

import Foundation
import StoreKit

/// Static, app-agnostic access to the running app's bundle metadata.
public enum AppInfo {

    /// Marketing version — `CFBundleShortVersionString`, e.g. `"1.2"`.
    public static var version: String {
        string(for: "CFBundleShortVersionString")
    }

    /// Build number — `CFBundleVersion`, e.g. `"45"`.
    public static var build: String {
        string(for: "CFBundleVersion")
    }

    /// User-facing app name — `CFBundleDisplayName`, falling back to `CFBundleName`.
    public static var displayName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? "—"
    }

    /// Bundle identifier, e.g. `"studio.pocketapps.xuetang"`.
    public static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }

    /// Version and build formatted as `"1.2 (45)"`. No localized prefix — add a
    /// `"Version "` label app-side if one is wanted.
    public static var versionWithBuild: String {
        "\(version) (\(build))"
    }

    private static func string(for key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? "—"
    }
}

// MARK: - Distribution

extension AppInfo {
    static let distributionDefaultsKey = "pas.appInfo.distribution"

    /// Last value resolved by `distribution()` in this or a previous launch, or `nil`.
    /// A hint, not the truth: use it to start crash reporting early at launch, then
    /// re-check with `distribution()` and correct if they disagree.
    public static var lastKnownDistribution: PASDistribution? {
        UserDefaults.standard.string(forKey: distributionDefaultsKey).flatMap(PASDistribution.init(rawValue:))
    }

    /// How this install reached the device. Resolved once per process (memoised) from
    /// `AppTransaction.shared`, waiting at most `timeout` on StoreKit. Never throws:
    /// a failure or timeout yields `.unknown` (`.development` in DEBUG builds) and is
    /// retried on the next call rather than cached.
    public static func distribution(timeout: Duration = .seconds(3)) async -> PASDistribution {
        await DistributionResolver.shared.resolve(timeout: timeout, probe: storeKitEnvironment)
    }

    /// Default probe: `AppTransaction.shared`, verified or unverified alike. Verification can
    /// fail on clock skew or a jailbroken device; the environment field is still meaningful.
    @Sendable static func storeKitEnvironment() async throws -> AppStore.Environment {
        switch try await AppTransaction.shared {
        case .verified(let transaction):
            return transaction.environment
        case .unverified(let transaction, let error):
            PASLogger.make(category: "appinfo")
                .notice("AppTransaction unverified: \(String(describing: error), privacy: .public)")
            return transaction.environment
        }
    }
}

/// Memoises the first successful distribution resolution. Injectable probe, timeout,
/// defaults suite and build flavour make it testable without StoreKit.
actor DistributionResolver {
    typealias Probe = @Sendable () async throws -> AppStore.Environment

    static let shared = DistributionResolver()

    private let defaults: UserDefaults
    private let debugBuild: Bool
    private var task: Task<PASDistribution, Never>?

    /// - Parameter defaultsSuiteName: `nil` = `UserDefaults.standard` (where `lastKnownDistribution` reads).
    init(defaultsSuiteName: String? = nil, debugBuild: Bool = PASDistribution.isDebugBuild) {
        self.defaults = defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.debugBuild = debugBuild
    }

    func resolve(timeout: Duration, probe: @escaping Probe) async -> PASDistribution {
        if let task { return await task.value }
        let debugBuild = debugBuild
        let task = Task {
            PASDistribution.classify(await Self.probeEnvironment(timeout: timeout, probe: probe), debugBuild: debugBuild)
        }
        self.task = task
        let value = await task.value
        if value == .unknown {
            self.task = nil // never cache a failure; the next call retries
        } else {
            defaults.set(value.rawValue, forKey: AppInfo.distributionDefaultsKey)
        }
        return value
    }

    /// Races the probe against `timeout`; `nil` when the probe throws or loses the race.
    static func probeEnvironment(timeout: Duration, probe: @escaping Probe) async -> AppStore.Environment? {
        await withTaskGroup(of: AppStore.Environment?.self) { group in
            group.addTask { try? await probe() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
