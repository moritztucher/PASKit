//
//  PASCrashLevel.swift
//  PASKitCrash
//
//  Severity for `PASCrash.capture(message:level:)`. Mapped internally to
//  Sentry's level so apps never import Sentry.
//

import Sentry

/// Severity of a captured message.
public enum PASCrashLevel: Sendable {
    case debug
    case info
    case warning
    case error
    case fatal

    // MARK: - Mapping

    var sentryLevel: SentryLevel {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .warning
        case .error: .error
        case .fatal: .fatal
        }
    }
}
