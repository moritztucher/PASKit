# PASKitCore

**Status:** Spec — not yet built.
**Build trigger:** Built alongside the first module that depends on it (`PASKitLifecycle` needs `AppInfo` + `PASTheme`).
**Dependencies:** None third-party. Foundation / Network / SwiftUI / Observation only.

## Purpose

Foundational, dependency-free utilities used by every other PASKit module and by apps directly. Also home to the `PASTheme` contract — the seam that lets PASKit's UI be un-branded.

## Components

### AppInfo — confirmed
App + bundle metadata. Merge XueTang's `AppInfo` and `DeviceInfo` into one namespace.
- App: `version` (`CFBundleShortVersionString`), `build` (`CFBundleVersion`), `displayName` (`CFBundleDisplayName` → `CFBundleName`), `bundleIdentifier`.
- Device: `systemName`, `systemVersion`, `model`, `deviceIdentifier` (raw `uname` machine code).
- Expose **raw values** — no baked-in localized strings. XueTang's `"Version 1.2"` prefix stays app-side, or provide an optional formatter.
- Fix the XueTang bug: `fullVersionWithBuild` renders `"Version 1.2 45"` — missing the conventional `(build)` parenthesis.

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
- [ ] Build `AppInfo` (merged App + Device), raw values, build-number bug fixed.
- [ ] Rebuild `NetworkMonitor` clean (AsyncStream, double-start guard, Sendable, launch state).
- [ ] Decide Keychain wrapper in/out when the first consumer is real.
