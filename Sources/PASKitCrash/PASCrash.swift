//
//  PASCrash.swift
//  PASKitCrash
//
//  Thin concrete facade over SentrySDK. The SDK is never started without
//  consent: the app calls `start` once its consent policy says yes and
//  `stop` when consent is withdrawn. Every capture call is a no-op while
//  the SDK is not running.
//

import Foundation
import PASKitCore
import Sentry

/// Sentry facade. `PASCrash.shared.start(...)` after consent, then
/// `capture` / `addBreadcrumb` / `setTag` from anywhere.
public final class PASCrash: Sendable {

    public static let shared = PASCrash()

    private let log = PASLogger.make(category: "crash")

    private init() {}

    // MARK: - State

    /// `true` while the Sentry SDK is started.
    public var isRunning: Bool { SentrySDK.isEnabled }

    // MARK: - Lifecycle

    /// Start the SDK. Call only after the user has consented. Idempotent:
    /// logs a warning and no-ops while running. An empty DSN logs and no-ops.
    ///
    /// Envelopes cached on disk before a previous `stop()` are sent on the
    /// next `start`, i.e. only after renewed consent.
    @MainActor
    public func start(_ config: PASCrashConfig) {
        guard !isRunning else {
            log.warning("PASCrash.start called while running — ignoring.")
            return
        }
        guard !config.dsn.isEmpty else {
            log.error("PASCrash.start called with an empty DSN — not starting.")
            return
        }
        SentrySDK.start(options: Self.makeOptions(config))
        log.info("Sentry started.")
    }

    /// Close the SDK, e.g. when consent is withdrawn. Safe when not running.
    @MainActor
    public func stop() {
        guard isRunning else { return }
        SentrySDK.close()
        log.info("Sentry stopped.")
    }

    // MARK: - Capture

    /// Report a handled error. `context` becomes extras on a local scope.
    public func capture(error: any Error, context: [String: String]? = nil) {
        guard isRunning else { return }
        SentrySDK.capture(error: error) { scope in
            for (key, value) in context ?? [:] {
                scope.setExtra(value: value, key: key)
            }
        }
    }

    /// Report a message at the given severity.
    public func capture(message: String, level: PASCrashLevel = .warning) {
        guard isRunning else { return }
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level.sentryLevel)
        }
    }

    /// Record a breadcrumb attached to subsequent events.
    public func addBreadcrumb(_ message: String, category: String, data: [String: String]? = nil) {
        guard isRunning else { return }
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Set a tag on the global scope.
    public func setTag(_ value: String, forKey key: String) {
        guard isRunning else { return }
        SentrySDK.configureScope { scope in
            scope.setTag(value: value, key: key)
        }
    }

    // MARK: - Options

    /// Builds the SDK options, including the hardcoded privacy floor.
    /// Internal so tests can assert the floor without starting the SDK.
    static func makeOptions(_ config: PASCrashConfig) -> Options {
        let options = Options()
        options.dsn = config.dsn
        options.environment = config.environment
        if let releaseName = config.releaseName {
            options.releaseName = releaseName
        }
        options.debug = config.debug
        if config.tracesSampleRate > 0 {
            options.tracesSampleRate = NSNumber(value: config.tracesSampleRate)
        }

        // Privacy floor — not configurable.
        options.sendDefaultPii = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false
        options.enableLogs = false
        #if os(iOS)
        options.attachScreenshot = false
        options.attachViewHierarchy = false
        options.enableUserInteractionTracing = false
        options.sessionReplay.sessionSampleRate = 0
        options.sessionReplay.onErrorSampleRate = 0
        #endif
        return options
    }
}
