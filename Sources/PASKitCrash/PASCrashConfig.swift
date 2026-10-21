//
//  PASCrashConfig.swift
//  PASKitCrash
//
//  Per-app crash reporting configuration. The privacy floor (no PII, no
//  screenshots, no view hierarchy, no session replay, no network
//  breadcrumbs) is hardcoded in `PASCrash` and deliberately not part of
//  this struct, so an app cannot turn it on by accident.
//

import Foundation

/// Configuration passed to `PASCrash.start(_:)`.
public struct PASCrashConfig: Sendable {

    /// Sentry DSN. Public, not a secret; apps inject it per build configuration.
    public let dsn: String

    /// Sentry environment tag (for example `production`, `staging`).
    public let environment: String

    /// Release name. `nil` keeps the SDK default (`bundleID@version+build`),
    /// which matches `sentry-cli` dSYM uploads.
    public let releaseName: String?

    /// Performance tracing sample rate. `0` leaves tracing off.
    public let tracesSampleRate: Double

    /// Verbose SDK logging. Keep off outside DEBUG builds.
    public let debug: Bool

    public init(
        dsn: String,
        environment: String = "production",
        releaseName: String? = nil,
        tracesSampleRate: Double = 0,
        debug: Bool = false
    ) {
        self.dsn = dsn
        self.environment = environment
        self.releaseName = releaseName
        self.tracesSampleRate = tracesSampleRate
        self.debug = debug
    }
}
