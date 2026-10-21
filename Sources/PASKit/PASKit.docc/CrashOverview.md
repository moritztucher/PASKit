# Crash Overview

PASKit's Sentry facade: consent-gated crash and error reporting with a hardcoded privacy floor. Not
part of the `PASKit` umbrella; link the product explicitly.

## Overview

`PASKitCrash` is a thin concrete facade over the Sentry SDK, the same shape ``PASKitAnalytics`` has
over PostHog. PASKit owns the mechanism: a privacy floor apps cannot turn off, idempotent start and
stop, and capture calls that are safe from any actor and silent while the SDK is not running. Each
app owns its vocabulary: when consent is given, the DSN per build configuration, the environment,
tag keys and breadcrumb categories.

**Not re-exported by the `PASKit` umbrella.** Linking Sentry ships its crash handler and its own
privacy manifest into the app, which then has to declare crash data in its App Store privacy labels
even if it never starts the SDK. Apps that report crashes add the product explicitly:

```swift
.product(name: "PASKitCrash", package: "PASKit")
```

## Consent by not starting

Sentry has no "requires consent" mode, so the SDK is never started without consent. The app calls
`start` once its consent policy says yes and `stop` when consent is withdrawn. Reports cached on
disk before `stop` are sent only after a renewed `start`.

```swift
PASCrash.shared.start(.init(dsn: AppKeys.sentryDSN))   // only after consent

PASCrash.shared.capture(error: error, context: ["screen": "review"])   // any actor, no-op when stopped
PASCrash.shared.addBreadcrumb("Opened deck", category: "navigation")

PASCrash.shared.stop()   // on withdrawal
```

## Privacy floor

PII, screenshots, view hierarchy, session replay, network breadcrumbs, failed-request capture, user
interaction tracing and Sentry logs are off and not configurable. Crash handling, app hangs,
watchdog terminations, release health and lifecycle breadcrumbs stay on. There is no user-identity
API.

See `docs/PASKitCrash.md` for per-app setup and `docs/adr/ADR-0008-paskitcrash-sentry.md` for the
design rationale.
