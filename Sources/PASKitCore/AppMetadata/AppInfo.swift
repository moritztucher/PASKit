//
//  AppInfo.swift
//  PASKitCore
//
//  Static, app-agnostic access to the running app's bundle metadata.
//

import Foundation
import StoreKit
import Synchronization

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

    /// Identifies the running build for the persisted hint: `"<version> (<build>)"`.
    static var buildIdentifier: String { versionWithBuild }

    /// Last value resolved by `distribution()` for **this build** (same
    /// `CFBundleShortVersionString` and `CFBundleVersion`), or `nil`. A hint, not the
    /// truth: use it to start crash reporting early at launch, then re-check with
    /// `distribution()` and correct if they disagree. A different build (an update, or a
    /// TestFlight build installed over an App Store one) never inherits the old answer.
    public static var lastKnownDistribution: PASDistribution? {
        storedDistribution(in: .standard, buildIdentifier: buildIdentifier)
    }

    /// How this install reached the device. Resolved once per process (memoised) from
    /// `AppTransaction.shared`, waiting at most `timeout` on StoreKit even if StoreKit
    /// ignores cancellation. Never throws: a failure or timeout yields `.unknown`
    /// (`.development` when PASKit is compiled in DEBUG) and is retried on the next call
    /// rather than cached.
    ///
    /// Concurrent callers share one in-flight resolution, so the first caller's
    /// `timeout` wins; later callers' `timeout` is ignored until a retry starts.
    public static func distribution(timeout: Duration = .seconds(3)) async -> PASDistribution {
        await DistributionResolver.shared.resolve(timeout: timeout, probe: storeKitEnvironment)
    }

    /// Default probe: `AppTransaction.shared`, verified or unverified alike (see
    /// `PASDistribution.environment(of:)`).
    @Sendable static func storeKitEnvironment() async throws -> AppStore.Environment {
        let check: AppTransactionCheck
        switch try await AppTransaction.shared {
        case .verified(let transaction):
            check = .verified(transaction.environment)
        case .unverified(let transaction, let error):
            PASLogger.make(category: "appinfo")
                .notice("AppTransaction unverified: \(String(describing: error), privacy: .public)")
            check = .unverified(transaction.environment)
        }
        return PASDistribution.environment(of: check)
    }

    // MARK: Hint storage

    static func storedDistribution(in defaults: UserDefaults, buildIdentifier: String) -> PASDistribution? {
        guard let entry = defaults.dictionary(forKey: distributionDefaultsKey) as? [String: String],
              entry["build"] == buildIdentifier,
              let raw = entry["value"] else { return nil }
        return PASDistribution(rawValue: raw)
    }

    static func storeDistribution(_ value: PASDistribution, in defaults: UserDefaults, buildIdentifier: String) {
        defaults.set(["build": buildIdentifier, "value": value.rawValue], forKey: distributionDefaultsKey)
    }
}

/// Memoises the first successful distribution resolution. Injectable probe, timeout,
/// defaults suite, build identifier and build flavour make it testable without StoreKit.
actor DistributionResolver {
    typealias Probe = @Sendable () async throws -> AppStore.Environment

    static let shared = DistributionResolver()

    private let defaults: UserDefaults
    private let buildIdentifier: String
    private let debugBuild: Bool
    private var task: Task<PASDistribution, Never>?
    /// Bumped per new resolution, so a caller only clears the task it started.
    private var generation = 0

    /// - Parameter defaultsSuiteName: `nil` = `UserDefaults.standard` (where `lastKnownDistribution` reads).
    init(defaultsSuiteName: String? = nil,
         buildIdentifier: String = AppInfo.buildIdentifier,
         debugBuild: Bool = PASDistribution.isDebugBuild) {
        self.defaults = defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.buildIdentifier = buildIdentifier
        self.debugBuild = debugBuild
    }

    func resolve(timeout: Duration, probe: @escaping Probe) async -> PASDistribution {
        if let task { return await task.value }
        generation += 1
        let myGeneration = generation
        let debugBuild = debugBuild
        let task = Task {
            PASDistribution.classify(await Self.probeEnvironment(timeout: timeout, probe: probe), debugBuild: debugBuild)
        }
        self.task = task
        let value = await task.value
        if value == .unknown {
            // Never cache a failure; the next call retries. Only clear our own task:
            // a newer retry may already be in flight.
            if generation == myGeneration { self.task = nil }
        } else {
            AppInfo.storeDistribution(value, in: defaults, buildIdentifier: buildIdentifier)
        }
        return value
    }

    /// Races the probe against `timeout`; `nil` when the probe throws or loses the race.
    /// Unstructured tasks + a resume-once continuation, so a probe that ignores
    /// cancellation cannot hold the caller past `timeout` (a task group would wait for it).
    static func probeEnvironment(timeout: Duration, probe: @escaping Probe) async -> AppStore.Environment? {
        await withCheckedContinuation { (continuation: CheckedContinuation<AppStore.Environment?, Never>) in
            let once = ResumeOnce(continuation)
            let timer = Task {
                try? await Task.sleep(for: timeout)
                once.resume(nil)
            }
            let prober = Task {
                let environment = try? await probe()
                once.resume(environment)
                timer.cancel()
            }
            Task {
                // Cancel the loser (best effort; never awaited).
                _ = await timer.result
                prober.cancel()
            }
        }
    }
}

/// Resumes a continuation exactly once; later calls are ignored.
private final class ResumeOnce: Sendable {
    private let continuation: Mutex<CheckedContinuation<AppStore.Environment?, Never>?>

    init(_ continuation: CheckedContinuation<AppStore.Environment?, Never>) {
        self.continuation = Mutex(continuation)
    }

    func resume(_ value: AppStore.Environment?) {
        continuation.withLock { pending in
            pending?.resume(returning: value)
            pending = nil
        }
    }
}
