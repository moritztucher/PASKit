//
//  PASError.swift
//  PASKitCore
//
//  Shared error domain for PASKit infrastructure.
//

import Foundation

/// Error domain shared across PASKit's infrastructure. App- or feature-specific
/// errors should wrap a `PASError` case, or define their own `LocalizedError`
/// and bridge at the boundary.
public enum PASError: LocalizedError, Sendable, Equatable {
    case missingCredentials(source: String)
    case invalidCredentials(source: String)
    case networkUnreachable
    case requestFailed(statusCode: Int, body: String?)
    case decodingFailed(description: String)
    case rateLimited(retryAfter: TimeInterval?)
    case cancelled
    case unexpected(description: String)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials(let source):
            return "Add credentials for \(source) in Settings to enable it."
        case .invalidCredentials(let source):
            return "\(source) rejected the stored credentials. Re-enter them in Settings."
        case .networkUnreachable:
            return "No network connection."
        case .requestFailed(let statusCode, _):
            return "Request failed with status \(statusCode)."
        case .decodingFailed(let description):
            return "Could not decode the response: \(description)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited — try again in \(Int(retryAfter))s."
            }
            return "Rate limited — try again shortly."
        case .cancelled:
            return "Cancelled."
        case .unexpected(let description):
            return description
        }
    }
}
