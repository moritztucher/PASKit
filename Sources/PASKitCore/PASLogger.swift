//
//  PASLogger.swift
//  PASKitCore
//
//  Thin facade over `os.Logger`. Logs flow into Console.app and the Logging
//  instrument in Instruments, grouped under the consuming app's bundle id.
//

import Foundation
@_exported import os

public enum PASLogger {
    /// Loggers are grouped under the consuming app's bundle identifier.
    public static var subsystem: String { AppInfo.bundleIdentifier }

    /// Create a category-scoped `os.Logger`. Keep the category short — it
    /// shows up in Console.app's "Category" column and the Instruments filter.
    public static func make(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
