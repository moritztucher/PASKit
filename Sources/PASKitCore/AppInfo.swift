//
//  AppInfo.swift
//  PASKitCore
//
//  App, bundle, and device metadata — static, app-agnostic accessors.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

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

/// Static, app-agnostic access to device and OS metadata.
public enum DeviceInfo {

    /// Hardware model identifier, e.g. `"iPhone16,1"` / `"Mac15,3"`. All platforms.
    public static var modelIdentifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    #if canImport(UIKit)
    /// OS name, e.g. `"iOS"`.
    public static var systemName: String { UIDevice.current.systemName }

    /// OS version, e.g. `"18.0"`.
    public static var systemVersion: String { UIDevice.current.systemVersion }

    /// Device class, e.g. `"iPhone"`, `"iPad"`.
    public static var model: String { UIDevice.current.model }

    /// Compact OS + device descriptor, e.g. `"iOS 18.0 (iPhone, iPhone16,1)"`.
    public static var summary: String {
        "\(systemName) \(systemVersion) (\(model), \(modelIdentifier))"
    }
    #endif
}
