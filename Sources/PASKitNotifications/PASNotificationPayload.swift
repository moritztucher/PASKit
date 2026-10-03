//
//  PASNotificationPayload.swift
//  PASKitNotifications
//
//  Turns a delivered notification's raw `userInfo` into the flat
//  `[String: String]` routing keys `PASNotificationResponse` carries.
//  Local notifications and plain APNs payloads keep their keys at the top
//  level; some remote-push providers nest the app's custom data inside
//  their own envelope. A provider module (e.g. PASKitPush) registers an
//  unwrapper once, so taps on its notifications reach the app's single
//  `onResponse` handler with the same flat keys a local notification has.
//

import Foundation
import os

/// Registry of payload unwrappers for remote-push providers.
public enum PASNotificationPayload {

    /// Returns the string routing keys a provider nested in `userInfo`, or
    /// `[:]` when the payload is not the provider's. Called synchronously,
    /// off the main actor, for every notification response.
    public typealias Unwrapper = @Sendable ([AnyHashable: Any]) -> [String: String]

    private static let unwrappers = OSAllocatedUnfairLock<[Unwrapper]>(initialState: [])

    /// Register a provider's unwrapper. Call once, at the provider's setup.
    public static func registerUnwrapper(_ unwrapper: @escaping Unwrapper) {
        unwrappers.withLock { $0.append(unwrapper) }
    }

    /// Top-level string pairs, plus whatever registered unwrappers surface.
    /// A top-level key wins over an unwrapped key of the same name.
    static func routingKeys(from userInfo: [AnyHashable: Any]) -> [String: String] {
        var extracted = stringPairs(in: userInfo)
        for unwrap in unwrappers.withLock({ $0 }) {
            extracted.merge(unwrap(userInfo)) { topLevel, _ in topLevel }
        }
        return extracted
    }

    /// The string-keyed, string-valued pairs of a payload dictionary.
    /// Non-string values (possible on remote payloads) are dropped.
    public static func stringPairs(in dictionary: [AnyHashable: Any]) -> [String: String] {
        var pairs: [String: String] = [:]
        for (key, value) in dictionary {
            if let key = key as? String, let value = value as? String {
                pairs[key] = value
            }
        }
        return pairs
    }
}
