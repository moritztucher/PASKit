//
//  VersionCheckManager.swift
//  PASKitLifecycle
//
//  Detects whether a newer version of the running app is on the App Store by
//  hitting the public iTunes lookup endpoint and comparing against the bundle's
//  `CFBundleShortVersionString`. Compares major.minor only — patch differences
//  are ignored as bug fixes.
//

import Foundation
import PASKitCore

@MainActor
public final class VersionCheckManager {

    public init() {}

    /// Returns a ``Result`` when a newer major or minor version is on the App
    /// Store, otherwise `nil`. Network errors and parse failures are mapped to
    /// `nil` — this is informational UI, not a critical path.
    public func checkIfAppUpdateAvailable() async -> Result? {
        guard
            let bundleID = Bundle.main.bundleIdentifier,
            let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)")
        else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [Any],
                let first = results.first as? [String: Any],
                let availableVersion = first["version"] as? String,
                let trackViewURL = first["trackViewUrl"] as? String,
                let appURL = trackViewURL.components(separatedBy: "?").first
            else {
                return nil
            }
            let currentVersion = AppInfo.version
            guard requiresUpdate(current: currentVersion, available: availableVersion) else {
                return nil
            }
            return Result(
                currentVersion: currentVersion,
                availableVersion: availableVersion,
                appURL: appURL
            )
        } catch {
            return nil
        }
    }

    /// Compares only the major (x) and minor (y) components. Returns `true`
    /// when `available` has a newer major *or* a newer minor at the same major.
    nonisolated func requiresUpdate(current: String, available: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let availableComponents = available.split(separator: ".").compactMap { Int($0) }
        let currentMajor = currentComponents.first ?? 0
        let currentMinor = currentComponents.count > 1 ? currentComponents[1] : 0
        let availableMajor = availableComponents.first ?? 0
        let availableMinor = availableComponents.count > 1 ? availableComponents[1] : 0
        if availableMajor > currentMajor { return true }
        if availableMajor == currentMajor, availableMinor > currentMinor { return true }
        return false
    }

    /// Describes an available update.
    public struct Result: Identifiable, Sendable, Equatable {
        public var id = UUID().uuidString
        public let currentVersion: String
        public let availableVersion: String
        public let appURL: String
    }
}
