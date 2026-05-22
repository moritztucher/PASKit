//
//  PASLogger.swift
//  PASKitCore
//
//  Logging entry point for PASKit and the apps that consume it. Wraps swift-log
//  so call sites have a portable API; the handler underneath bridges to
//  `os.Logger`, so every line shows up in Console.app and Instruments, grouped
//  under the consuming app's bundle identifier.
//
//  Bootstrap exactly once at app startup, before any logger is created —
//  `LoggingSystem.bootstrap` is one-shot.
//

import Foundation
@_exported import Logging
import os

public enum PASLogger {
    /// Loggers are grouped under the consuming app's bundle identifier.
    public static var subsystem: String { AppInfo.bundleIdentifier }

    /// Install the `os.Logger`-backed handler. Call once from the app's `init()`.
    public static func bootstrap() {
        LoggingSystem.bootstrap { label in
            OSLogHandler(label: label)
        }
    }

    /// Create a category-scoped logger. Keep the category short — it shows up
    /// in Console.app's "Category" column.
    public static func make(category: String) -> Logging.Logger {
        Logging.Logger(label: "\(subsystem).\(category)")
    }
}

/// Forwards `Logging.Logger` calls to an `os.Logger`. Each handler instance
/// owns one `os.Logger` configured with the right subsystem + category.
struct OSLogHandler: LogHandler {
    private let osLogger: os.Logger
    var logLevel: Logging.Logger.Level = .info
    var metadata: Logging.Logger.Metadata = [:]

    init(label: String) {
        // swift-log labels look like "subsystem.dot.path.category" — split on
        // the last dot so the subsystem stays grouped and the category is the
        // tail. Falls back to a single-component label if no dot is present.
        if let lastDot = label.lastIndex(of: ".") {
            let subsystem = String(label[..<lastDot])
            let category = String(label[label.index(after: lastDot)...])
            self.osLogger = os.Logger(subsystem: subsystem, category: category)
        } else {
            self.osLogger = os.Logger(subsystem: label, category: "default")
        }
    }

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let osLevel = osLogType(from: level)
        let merged = self.metadata.merging(metadata ?? [:], uniquingKeysWith: { _, new in new })
        let body: String
        if merged.isEmpty {
            body = message.description
        } else {
            let pairs = merged.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            body = "\(message) \(pairs)"
        }
        // `.public` so the message survives redaction in release builds —
        // never put credentials into log messages.
        osLogger.log(level: osLevel, "\(body, privacy: .public)")
    }

    private func osLogType(from level: Logging.Logger.Level) -> OSLogType {
        switch level {
        case .trace, .debug: return .debug
        case .info, .notice: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}
