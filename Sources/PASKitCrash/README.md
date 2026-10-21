# PASKitCrash

Sentry facade: consent-gated crash and error reporting with a hardcoded privacy floor.

Full documentation: [docs/PASKitCrash.md](../../docs/PASKitCrash.md).
Design rationale: [ADR-0008](../../docs/adr/ADR-0008-paskitcrash-sentry.md).

**Not part of the `PASKit` umbrella.** Add the product explicitly.

## API

`PASCrash.shared`: `@MainActor start(_:)` (idempotent, empty DSN is a no-op) / `@MainActor stop()`,
`isRunning`, `capture(error:context:)`, `capture(message:level:)`,
`addBreadcrumb(_:category:data:)`, `setTag(_:forKey:)`. Capture calls work from any actor and are
no-ops while not running.

`PASCrashConfig(dsn:environment:releaseName:tracesSampleRate:debug:)`: defaults `"production"`,
`nil` (SDK default release), `0` (tracing off), `false`. `PASCrashLevel`: `.debug` / `.info` /
`.warning` / `.error` / `.fatal`.

Privacy-relevant options (PII, screenshots, view hierarchy, replay, network breadcrumbs, failed
requests, interaction tracing, logs) are off and not configurable.

## Example

```swift
import PASKitCrash

if consent.crashReports {   // never start before consent
    PASCrash.shared.start(.init(dsn: AppKeys.sentryDSN))
}

PASCrash.shared.capture(error: error, context: ["screen": "review"])

PASCrash.shared.stop()      // on withdrawal; cached reports wait for the next start
```
