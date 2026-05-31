//
//  DeviceInfo.swift
//  PASKitCore
//
//  Static, app-agnostic access to device and OS metadata.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

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
