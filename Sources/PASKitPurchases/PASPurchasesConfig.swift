//
//  PASPurchasesConfig.swift
//  PASKitPurchases
//
//  Configuration handed to `PASPurchases.shared.configure(_:)` once at launch.
//

import Foundation

/// Configuration for the RevenueCat SDK. The API key is the **public** SDK
/// key (`appl_…` / `test_…`) — never a secret key.
public struct PASPurchasesConfig: Sendable {

    /// RevenueCat public SDK key.
    public let apiKey: String

    /// Known user ID to configure with (e.g. from the app's auth system).
    /// `nil` starts an anonymous user; identify later via `logIn`. Use the
    /// same ID passed to `PASAnalytics.identify` so revenue and analytics
    /// data join on one key.
    public let appUserID: String?

    /// Emit verbose RevenueCat SDK logs. Keep off in Release.
    public let debugLogs: Bool

    public init(apiKey: String, appUserID: String? = nil, debugLogs: Bool = false) {
        self.apiKey = apiKey
        self.appUserID = appUserID
        self.debugLogs = debugLogs
    }
}
