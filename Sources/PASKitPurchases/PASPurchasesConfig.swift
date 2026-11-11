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

    /// Collect the Apple Ads (AdServices) attribution token, so RevenueCat
    /// can attribute installs, trials and revenue to Apple Ads campaigns and
    /// keywords. Needs no App Tracking Transparency prompt, but the app's
    /// privacy policy should say that Apple Ads attribution is collected.
    /// The token is sent once per install.
    public let collectsAppleAdsAttribution: Bool

    public init(apiKey: String, appUserID: String? = nil, debugLogs: Bool = false,
                collectsAppleAdsAttribution: Bool = false) {
        self.apiKey = apiKey
        self.appUserID = appUserID
        self.debugLogs = debugLogs
        self.collectsAppleAdsAttribution = collectsAppleAdsAttribution
    }
}
