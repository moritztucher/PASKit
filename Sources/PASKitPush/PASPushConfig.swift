//
//  PASPushConfig.swift
//  PASKitPush
//

import Foundation

/// Configuration for `PASPush.configure(_:)`.
public struct PASPushConfig: Sendable {

    /// The OneSignal App ID — public, not a secret. Use one OneSignal app
    /// per bundle ID (production and staging separately).
    public let appID: String

    /// Hold back every network call to OneSignal until the app calls
    /// `setConsent(true)`. Defaults to `true`: the SDK is linked and its
    /// notification-delegate wiring is in place, but nothing leaves the
    /// device until the app's consent policy says so.
    public let requiresConsent: Bool

    /// Verbose OneSignal SDK logging. Keep off outside DEBUG.
    public let verboseLogging: Bool

    public init(appID: String, requiresConsent: Bool = true, verboseLogging: Bool = false) {
        self.appID = appID
        self.requiresConsent = requiresConsent
        self.verboseLogging = verboseLogging
    }
}
