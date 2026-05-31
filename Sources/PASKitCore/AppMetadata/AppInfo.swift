//
//  AppInfo.swift
//  PASKitCore
//
//  Static, app-agnostic access to the running app's bundle metadata.
//

import Foundation

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
