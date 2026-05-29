# PASKitCore

**Status:** Built — foundational utilities compiling.
**Dependencies:** `KeychainAccess`. Otherwise Foundation / Network / Observation / UIKit / os.
**Platforms:** iOS 18+, macOS 15+ (`UIKit`-only members guarded with `#if canImport(UIKit)`).

## Purpose

Foundational utilities used by every other PASKit module and by apps directly. `AppInfo` / `DeviceInfo` were built fresh; the networking, logging, reachability and credential code was lifted from a sibling internal package during a package-architecture reconciliation (see `docs/adr/ADR-0001`).

## Components

### AppInfo / DeviceInfo — ✅ built (`AppInfo.swift`)
App + bundle + device metadata. Static accessors, raw values; `AppInfo.versionWithBuild` renders `"1.2 (45)"`.

### Networking — ✅ built
- `NetworkService.swift` — the networking seam: `NetworkService` protocol + `URLSessionNetworkService` (2xx handling, 429/Retry-After, decode).
- `PASError.swift` — shared error domain.

### Reachability — ✅ built
`Reachability.swift` (protocol + `NetworkStatus`) and `NWReachability.swift` (`@MainActor @Observable`, `NWPathMonitor`-backed).

### Logging — ✅ built (`PASLogger.swift`)
`PASLogger` — a thin facade over `os.Logger`. `make(category:)` returns a logger scoped under the app's bundle id (via `AppInfo`) and the given category. Logs surface in Console.app and the Logging instrument in Instruments. No bootstrap step needed — `os.Logger` is per-instance.

### Credentials — ✅ built
`CredentialVault.swift` (protocol) + `KeychainCredentialVault.swift` (KeychainAccess-backed, per-source service scoping, iCloud-synced). `baseService` defaults to the bundle id.

### Haptics — ✅ built (`Haptics.swift`)
`Haptics.play(_:isEnabled:)` — one-call wrapper over `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` / `UISelectionFeedbackGenerator`. Primitive-only `PASHaptic` enum (`.light` … `.heavy`, `.success` / `.warning` / `.error`, `.selection`) — no semantic aliases; vocabulary stays per-app. Caller supplies the enabled-gate. `View.hapticOnTap(_:isEnabled:action:)` is a thin SwiftUI helper. iOS-only at the hardware level; macOS compiles to a no-op via `#if canImport(UIKit)`. Generators are created on demand (no preheated singletons) — kept simple until profiling justifies otherwise.

## Notes

- Design tokens stay per-app. PASKit has no design module — apps use SwiftUI defaults and their own per-app theme.

## Remaining

- [ ] Unit tests.
