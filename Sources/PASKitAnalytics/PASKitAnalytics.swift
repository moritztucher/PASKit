//
//  PASKitAnalytics.swift
//  PASKitAnalytics
//
//  Thin concrete facade over PostHogSDK. PASKit owns the generic surface
//  (configure, identify, register, reset, capture, screen, opt in/out,
//  flush, feature flags); each app owns its event vocabulary as a thin
//  extension over `capture`.
//

import Foundation
import PASKitCore
import PostHog

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

/// PostHog facade. `PASAnalytics.shared.setup(...)` once at launch, then
/// `capture` / `identify` / `register` / `reset` / `screen` from anywhere.
///
/// Apps grow their typed vocabulary as an extension:
/// ```swift
/// extension PASAnalytics {
///     func captureOnboardingCompleted() { capture("onboarding_completed") }
/// }
/// ```
@MainActor
@Observable
public final class PASAnalytics {

    public static let shared = PASAnalytics()

    public private(set) var isConfigured = false

    private let log = PASLogger.make(category: "analytics")

    private init() {}

    // MARK: - Setup

    /// Configure the PostHog SDK. Safe to call once; subsequent calls log a
    /// warning and no-op.
    public func setup(_ config: PASAnalyticsConfig) {
        guard !isConfigured else {
            log.warning("PASAnalytics.setup called twice — ignoring the second call.")
            return
        }
        let posthog = PostHogConfig(projectToken: config.apiKey, host: config.host)
        posthog.captureApplicationLifecycleEvents = config.captureApplicationLifecycleEvents
        posthog.captureScreenViews = config.captureScreenViews
        posthog.debug = config.debug
        #if os(iOS)
        posthog.sessionReplay = config.sessionReplay
        #endif
        PostHogSDK.shared.setup(posthog)
        isConfigured = true
        log.info("PostHog configured.")
    }

    // MARK: - Events

    /// Capture an event. Event names are app-owned — keep them snake_case
    /// for consistency with the PostHog ecosystem.
    public func capture(_ event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// Track a screen view. Use for top-level screens, not every subview.
    public func screen(_ name: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.screen(name, properties: properties)
    }

    // MARK: - Identity

    /// Associate the anonymous session with a known user. Use the same ID
    /// passed to `PASKitPurchases.logIn` so analytics and revenue join.
    public func identify(userId: String, traits: [String: Any]? = nil) {
        PostHogSDK.shared.identify(userId, userProperties: traits)
    }

    /// Register super-properties — sent with every subsequent event.
    public func register(_ properties: [String: Any]) {
        PostHogSDK.shared.register(properties)
    }

    /// Clear the current user — call on logout.
    public func reset() {
        PostHogSDK.shared.reset()
    }

    // MARK: - Consent

    public func optIn() {
        PostHogSDK.shared.optIn()
    }

    public func optOut() {
        PostHogSDK.shared.optOut()
    }

    // MARK: - Lifecycle

    /// Force-flush the pending queue. PostHog batches by default — apps
    /// rarely need to call this.
    public func flush() {
        PostHogSDK.shared.flush()
    }

    // MARK: - Feature Flags

    public func isFeatureEnabled(_ key: String) -> Bool {
        PostHogSDK.shared.isFeatureEnabled(key)
    }

    public func featureFlagPayload(_ key: String) -> Any? {
        PostHogSDK.shared.getFeatureFlag(key)
    }
}
