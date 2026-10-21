# PASKitCrash

> **Status: Shipped.** Built for XueTang, the first consuming app; its wiring lands in a later
> step. Vendor: Sentry (EU region), `sentry-cocoa` 9.x.

Crash and error reporting through Sentry. A thin concrete facade over `SentrySDK`, the same shape as
`PASAnalytics` over PostHog. **Not in the `PASKit` umbrella**: see
[ADR-0008](adr/ADR-0008-paskitcrash-sentry.md).

PASKit owns the mechanism: a hardcoded privacy floor, idempotent start and stop, and capture calls
that are safe from any actor and silent while the SDK is not running. The app owns its vocabulary:
when consent is given, the DSN per build configuration, the environment name, tag keys and
breadcrumb categories.

## Setup (per app)

1. **Sentry project.** One project per app, created in the **EU region** (`de.sentry.io`). Under
   *Project Settings > Security & Privacy*, turn on **Prevent storing of IP addresses**.
2. **DSN per build configuration.** The DSN is public, not a secret: inject it through the build
   configuration (xcconfig to Info.plist) so staging and production report to separate
   environments or projects.
3. **Xcode, app target.** Link the `PASKitCrash` product. Never `import Sentry` in app code.
4. **dSYM upload.** The app's job, not PASKit's: run `sentry-cli debug-files upload` in a build
   phase on Archive builds only, so crash stacks are symbolicated. Leave `releaseName` at `nil`
   and the SDK default (`bundleID@version+build`) matches what `sentry-cli` uploads against.

## Consent

Sentry has no "requires consent" mode, so **the SDK is never started without consent**. The app
calls `start` only once its consent policy says yes, and `stop` when consent is withdrawn. Until
`start`, nothing is initialised and nothing leaves the device.

```swift
import PASKitCrash

// At launch, and whenever consent flips to yes:
if consent.crashReports {
    PASCrash.shared.start(.init(
        dsn: AppKeys.sentryDSN,
        environment: AppKeys.environment   // defaults to "production"
    ))
}

// When consent is withdrawn:
PASCrash.shared.stop()
```

`start` is idempotent: a second call while running logs a warning and does nothing. An empty DSN
logs and does nothing, so a build without a DSN runs without crash reporting. `stop` is safe when
not running.

**Cached envelopes.** `stop()` closes the SDK, but envelopes already cached on disk (for example a
crash captured before `stop`) are not deleted. They are sent on the next `start` only, which means
only after consent has been given again. Nothing is sent while consent is withdrawn.

## Capture

```swift
PASCrash.shared.capture(error: error, context: ["screen": "review"])
PASCrash.shared.capture(message: "Deck import skipped rows", level: .warning)
PASCrash.shared.addBreadcrumb("Opened deck", category: "navigation", data: ["deck": deckID])
PASCrash.shared.setTag("premium", forKey: "tier")
```

All four are callable from any actor and are no-ops while the SDK is not running, so call sites
need no consent check of their own. `context` is applied to a local scope for that one event only.
Values are `[String: String]` so they stay `Sendable`.

## API

`PASCrashConfig` (`Sendable`)

| Property | Default | Meaning |
|----------|---------|---------|
| `dsn: String` | required | Public project key; injected per build configuration. |
| `environment: String` | `"production"` | Sentry environment name. |
| `releaseName: String?` | `nil` | `nil` keeps the SDK default `bundleID@version+build`, which matches `sentry-cli` dSYM uploads. |
| `tracesSampleRate: Double` | `0` | `0` leaves performance tracing off; above `0` enables it. |
| `debug: Bool` | `false` | Verbose SDK logging. Keep off outside DEBUG. |

`PASCrashLevel` (`Sendable`): `.debug`, `.info`, `.warning`, `.error`, `.fatal`, mapped internally
to `SentryLevel`.

`PASCrash.shared` (`Sendable`, not `@MainActor`)

- `isRunning: Bool`: whether the SDK is enabled.
- `@MainActor start(_ config: PASCrashConfig)`: starts the SDK; idempotent; empty DSN is a no-op.
- `@MainActor stop()`: closes the SDK; safe when not running.
- `capture(error: any Error, context: [String: String]? = nil)`
- `capture(message: String, level: PASCrashLevel = .warning)`
- `addBreadcrumb(_ message: String, category: String, data: [String: String]? = nil)`
- `setTag(_ value: String, forKey key: String)`

Logging goes through `PASLogger` with category `crash`.

## Privacy floor

Hardcoded in the module and **not configurable**, so an app cannot turn any of it on by accident:

| Option | Value | Why |
|--------|-------|-----|
| `sendDefaultPii` | `false` | No IP address, user, or request data attached by default. |
| `attachScreenshot` | `false` | Screens can show personal content. |
| `attachViewHierarchy` | `false` | View text can show personal content. |
| Session replay `sessionSampleRate` | `0` | No replay. |
| Session replay `onErrorSampleRate` | `0` | No replay on error either. |
| `enableNetworkBreadcrumbs` | `false` | URLs can carry query parameters and tokens. |
| `enableCaptureFailedRequests` | `false` | Same reason: request URLs and headers. |
| `enableUserInteractionTracing` | `false` | No tap-level tracing. |
| `enableLogs` | `false` | App logs are not shipped to Sentry. |

Kept on at the SDK defaults: the crash handler, app hang tracking, watchdog termination tracking
(iOS), automatic session tracking (release health), and automatic lifecycle and navigation
breadcrumbs.

There is **no user-identity API**. XueTang deliberately sends no user ID, so deleting an account
never involves Sentry. Add one only when an app has a real need.

The options are built in an `internal` `makeOptions(_:)` function, so the test target asserts every
floor flag without ever starting the SDK.

## Design decisions

- **Consent by not starting.** There is no consent flag to forget: an unstarted SDK sends nothing,
  and every capture call is a silent no-op until `start`.
- **Floor in code, not config.** Privacy-relevant options are not on `PASCrashConfig` at all.
- **Any-actor capture.** `start` and `stop` are `@MainActor` because apps call them from launch
  and from their consent toggle, both on the main actor, which keeps start/stop ordering
  deterministic; capture calls are nonisolated and safe from any thread.
- **Pre-built static framework.** The package links Sentry's `Sentry` product: fastest app start and
  no source compile under Swift 6 language mode.

## Future work

- [ ] User identity (`setUser`), when an app needs to correlate reports with an account.
- [ ] Attachments or scoped context helpers, when the first app needs them.
