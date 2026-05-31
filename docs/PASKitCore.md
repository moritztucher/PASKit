# PASKitCore

**Status:** Built — foundational utilities compiling.
**Dependencies:** `KeychainAccess`. Otherwise Foundation / Network / Observation / UIKit / os.
**Platforms:** iOS 18+, macOS 15+ (`UIKit`-only members guarded with `#if canImport(UIKit)`).

## Purpose

Foundational utilities used by every other PASKit module and by apps directly. `AppInfo` / `DeviceInfo` were built fresh; the networking, logging, reachability and credential code was lifted from a sibling internal package during a package-architecture reconciliation (see `docs/adr/ADR-0001`).

## Layout

Sources are grouped by topic — one public type per file:

```
Sources/PASKitCore/
├── AppMetadata/   AppInfo.swift, DeviceInfo.swift
├── Networking/    NetworkService.swift, URLSessionNetworkService.swift, URLRequest+cURL.swift
├── Reachability/  NetworkStatus.swift, Reachability.swift, NWReachability.swift
├── Credentials/   CredentialVault.swift, KeychainCredentialVault.swift
├── Logging/       PASLogger.swift
├── Errors/        PASError.swift
└── Haptics/       PASHaptic.swift, Haptics.swift, View+HapticOnTap.swift
```

## Components

### AppMetadata — ✅ built
- `AppInfo` — `version`, `build`, `versionWithBuild` (`"1.2 (45)"`), `displayName`, `bundleIdentifier`.
- `DeviceInfo` — `modelIdentifier` cross-platform; `systemName` / `systemVersion` / `model` / `summary` iOS-only.

### Networking — ✅ built
- `NetworkService` protocol — the networking seam.
- `URLSessionNetworkService` — default implementation (2xx handling, 429/Retry-After, decode).
- `URLRequest.cURL(pretty:)` — render a request as a paste-ready `curl` command for terminal replay during debugging.

### Reachability — ✅ built
- `NetworkStatus` — observed value (`.unknown` / `.online` / `.offline`).
- `Reachability` — protocol contract.
- `NWReachability` — `@MainActor @Observable`, `NWPathMonitor`-backed implementation.

### Credentials — ✅ built
- `CredentialVault` — protocol contract.
- `KeychainCredentialVault` — KeychainAccess-backed, per-source service scoping, iCloud-synced. `baseService` defaults to the bundle id.

### Errors — ✅ built
- `PASError` — shared error domain (`networkUnreachable`, `requestFailed(status:body:)`, `rateLimited(retryAfter:)`, `decodingFailed`, `cancelled`, `unexpected`).

### Logging — ✅ built
- `PASLogger` — a thin facade over `os.Logger`. `make(category:)` returns a logger scoped under the app's bundle id (via `AppInfo`) and the given category. No bootstrap step.

### Haptics — ✅ built
- `PASHaptic` — primitive-only enum (`.light` … `.heavy`, `.success` / `.warning` / `.error`, `.selection`) — no semantic aliases; vocabulary stays per-app.
- `Haptics.play(_:isEnabled:)` — one-call wrapper over `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` / `UISelectionFeedbackGenerator`. Caller supplies the enabled-gate.
- `View.hapticOnTap(_:isEnabled:action:)` — SwiftUI sugar that fires the haptic on tap then runs the action.

iOS-only at the hardware level; macOS compiles to a no-op via `#if canImport(UIKit)`.

## Notes

- Design tokens stay per-app. PASKit has no design module — apps use SwiftUI defaults and their own per-app theme.

## Remaining

- [ ] Unit tests.
