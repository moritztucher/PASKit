# PASKitCore

**Status:** In progress — `AppInfo` / `DeviceInfo` built. `NetworkMonitor`, `PASTheme` pending.
**Build trigger:** Built alongside the first module that depends on it (`PASKitLifecycle` needs `AppInfo` + `PASTheme`).
**Dependencies:** None third-party. Foundation / UIKit / Network / Observation / SwiftUI.
**Platforms:** iOS 17+, macOS 14+ (`UIKit`-only members are guarded with `#if canImport(UIKit)`).

## Purpose

Foundational, dependency-free utilities used by every other PASKit module and by apps directly. Also home to the `PASTheme` contract — the seam that lets PASKit's UI be un-branded.

## Components

### AppInfo / DeviceInfo — ✅ built (`Sources/PASKitCore/AppInfo.swift`)
App + bundle metadata. XueTang's `AppInfo` and `DeviceInfo` merged into one file.
- `AppInfo`: `version` (`CFBundleShortVersionString`), `build` (`CFBundleVersion`), `displayName` (`CFBundleDisplayName` → `CFBundleName`), `bundleIdentifier`, `versionWithBuild`.
- `DeviceInfo`: `modelIdentifier` (raw `uname` machine code, all platforms); `systemName`, `systemVersion`, `model`, `summary` (`UIKit`-guarded).
- Exposes **raw values** — no baked-in localized strings. XueTang's `"Version 1.2"` prefix stays app-side.
- XueTang bug fixed: `versionWithBuild` renders `"1.2 (45)"` with the conventional `(build)` parenthesis.

### NetworkMonitor — confirmed
Internet-connectivity monitor. **Rebuild clean** rather than lift XueTang's verbatim:
- Keep `NWPathMonitor` (Network framework) + `@Observable` for SwiftUI consumers.
- Add a non-SwiftUI consumption path — an `AsyncStream<Bool>` (XueTang's is `.shared`-singleton only).
- Guard against double-start (XueTang's `startMonitoring()` is public and re-callable — leaks the handler).
- `Sendable`-audit for strict concurrency.
- Fix the launch false-positive: `isConnected` defaults to `true` before the first path callback.

### PASTheme — confirmed
The minimal theme contract that lets `PASKitLifecycle` views be un-branded. NOT a component library.
- Spacing scale, corner-radius scale, semantic colour roles, a primary button style.
- Injected via the SwiftUI environment; each app supplies its own `PASTheme`.
- No component hard-codes a colour — it reads the theme.

### Candidate additions — not yet confirmed
Proposed, not yet justified by a real second use. Add per the build-on-need rule:
- Keychain wrapper — likely (the Analytics Dashboard stores API keys in Keychain).
- Networking base / API-client helper.

## Extraction sources

- `XueTang/XueTangApp/Core/Utilities/AppInfo.swift`
- `XueTang/XueTangApp/Core/Utilities/DeviceInfo.swift`
- `XueTang/XueTangApp/Core/Services/NetworkMonitor.swift`

## What needs to be done

- [ ] Define `PASTheme` and its environment injection.
- [x] Build `AppInfo` (merged App + Device), raw values, build-number bug fixed.
- [ ] Rebuild `NetworkMonitor` clean (AsyncStream, double-start guard, Sendable, launch state).
- [ ] Decide Keychain wrapper in/out when the first consumer is real.
