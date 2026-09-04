//
//  PASError.swift
//  PASKitCore
//
//  Shared error domain for PASKit infrastructure.
//

import Foundation
import Synchronization

/// App-supplied rendering of a `PASError` into user-facing text. Return `nil`
/// for any case you do not want to override; PASKit falls back to
/// `developerDescription` for it. The closure runs on every read (not just
/// once), so a `String(localized:bundle:)` body follows a runtime bundle or
/// language switch.
public typealias PASErrorLocalizer = @Sendable (PASError) -> String?

/// Error domain shared across PASKit's infrastructure. App- or feature-specific
/// errors should wrap a `PASError` case, or define their own `LocalizedError`
/// and bridge at the boundary. User-facing copy is the app's: install
/// `PASError.localizer` at launch.
public enum PASError: LocalizedError, Sendable, Equatable {
    case missingCredentials(source: String)
    case invalidCredentials(source: String)
    case networkUnreachable
    case requestFailed(statusCode: Int, body: String?)
    case decodingFailed(description: String)
    case rateLimited(retryAfter: TimeInterval?)
    case cancelled
    case unexpected(description: String)

    /// Process-wide localizer. Set once at launch (next to `PASPurchases.configure`
    /// / `PASAnalytics.configure`); every `errorDescription` / `localizedDescription`
    /// read afterwards goes through it. The closure runs per read, so a
    /// `String(localized:bundle:)` body follows a runtime bundle switch. `nil`
    /// (the default) falls back to PASKit's English developer copy.
    public static var localizer: PASErrorLocalizer? {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }

    private static let storage = Mutex<PASErrorLocalizer?>(nil)
    private static let hasWarnedNoLocalizer = Mutex<Bool>(false)

    /// App-facing text: the installed localizer's answer, else `developerDescription`.
    public var errorDescription: String? {
        if let localized = Self.localizer?(self) {
            return localized
        }
        Self.warnOnceIfLikelyLocalized()
        return developerDescription
    }

    /// PASKit's English, developer-facing description. Never localized; stable for
    /// logs and tests regardless of the installed localizer. Not user copy — install
    /// `localizer` for that.
    public var developerDescription: String {
        switch self {
        case .missingCredentials(let source):
            return "Missing credentials for \(source)."
        case .invalidCredentials(let source):
            return "\(source) rejected the stored credentials."
        case .networkUnreachable:
            return "Network unreachable."
        case .requestFailed(let statusCode, _):
            // Body is deliberately omitted — may be large or sensitive.
            return "Request failed: HTTP \(statusCode)."
        case .decodingFailed(let description):
            return "Decoding failed: \(description)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited; retry after \(Int(retryAfter))s."
            }
            return "Rate limited."
        case .cancelled:
            return "Cancelled."
        case .unexpected(let description):
            return description
        }
    }

    /// One-shot nudge: warns via `PASLogger` when `errorDescription` is read with
    /// no localizer installed *and* the app bundle carries more than one
    /// localization — the situation where developer-tone English is likely to
    /// reach a non-English user. Fires at most once per process. A no-op for
    /// single-localization apps.
    private static func warnOnceIfLikelyLocalized() {
        guard Bundle.main.localizations.count > 1 else { return }
        let shouldWarn = hasWarnedNoLocalizer.withLock { warned -> Bool in
            guard !warned else { return false }
            warned = true
            return true
        }
        guard shouldWarn else { return }
        PASLogger.make(category: "error").warning(
            "PASError.errorDescription read with no PASError.localizer installed, in an app with multiple localizations. Install PASError.localizer at launch."
        )
    }
}
