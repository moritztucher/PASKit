# PASKitCore

**Status:** Built — foundational utilities compiling.
**Dependencies:** `swift-log`, `KeychainAccess`. Otherwise Foundation / Network / Observation / UIKit / os.
**Platforms:** iOS 18+, macOS 15+ (`UIKit`-only members guarded with `#if canImport(UIKit)`).

## Purpose

Foundational utilities used by every other PASKit module and by apps directly. `AppInfo` / `DeviceInfo` were built fresh; the networking, logging, reachability and credential code was migrated from the AnalyticsDashboard's `ADCoreKit` during the PASKit ↔ Dashboard reconciliation (see `docs/adr/`).

## Components

### AppInfo / DeviceInfo — ✅ built (`AppInfo.swift`)
App + bundle + device metadata. Static accessors, raw values; `AppInfo.versionWithBuild` renders `"1.2 (45)"`.

### Networking — ✅ built
- `NetworkService.swift` — the networking seam: `NetworkService` protocol + `URLSessionNetworkService` (2xx handling, 429/Retry-After, decode). Migrated from `ADCoreKit`.
- `PASError.swift` — shared error domain (migrated from `ADCoreKit`'s `ADError`).

### Reachability — ✅ built
`Reachability.swift` (protocol + `NetworkStatus`) and `NWReachability.swift` (`@MainActor @Observable`, `NWPathMonitor`-backed). Migrated from `ADCoreKit` — supersedes the `NetworkMonitor` first drafted for PASKit, which has been removed.

### Logging — ✅ built (`PASLogger.swift`)
`PASLogger` (migrated from `ADCoreKit`'s `ADLogger`) — a swift-log → `os.Logger` bridge. `bootstrap()` once at app startup; `make(category:)` for category loggers. Subsystem resolves to the app's bundle id via `AppInfo`, replacing the Dashboard's hardcoded constant.

### Credentials — ✅ built
`CredentialVault.swift` (protocol) + `KeychainCredentialVault.swift` (KeychainAccess-backed, per-source service scoping, iCloud-synced). Migrated from `ADCoreKit`; `baseService` defaults to the bundle id.

## Notes

- `PASTheme` / design tokens live in `PASKitUI`, not here.
- `OSLogHandler` emits a swift-log `log(event:)` deprecation warning — carried over verbatim from `ADCoreKit`; harmless, cleanup deferred.

## Remaining

- [ ] Unit tests.
- [ ] Resolve the swift-log `log(event:)` deprecation.
