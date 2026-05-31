//
//  PASAnalyticsConfig.swift
//  PASKitAnalytics
//
//  Config passed to `PASAnalytics.setup`. API key is injected, never read
//  from Info.plist — apps source it from their secrets layer.
//

import Foundation

/// Config passed to `PASAnalytics.setup`. API key is injected, never read
/// from Info.plist — apps source it from their secrets layer.
public struct PASAnalyticsConfig: Sendable {

    public let apiKey: String
    public let host: String
    public let captureApplicationLifecycleEvents: Bool
    public let captureScreenViews: Bool
    public let sessionReplay: Bool
    public let debug: Bool

    public init(
        apiKey: String,
        host: String = "https://us.i.posthog.com",
        captureApplicationLifecycleEvents: Bool = true,
        captureScreenViews: Bool = true,
        sessionReplay: Bool = false,
        debug: Bool = false
    ) {
        self.apiKey = apiKey
        self.host = host
        self.captureApplicationLifecycleEvents = captureApplicationLifecycleEvents
        self.captureScreenViews = captureScreenViews
        self.sessionReplay = sessionReplay
        self.debug = debug
    }
}
