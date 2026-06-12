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
├── Haptics/       PASHaptic.swift, Haptics.swift, View+HapticOnTap.swift
├── Settings/      UserDefaultsStorable.swift, PASSettingsStore.swift, PASDefault.swift,
│                  PASDraft.swift
├── Styling/       Animation+ReducedMotion.swift, Color+LightDark.swift,
│                  Font+PASScaled.swift, PASFontRegistration.swift
└── Time/          Date+PASCalendar.swift, PASDurationFormat.swift
```

## Components

### AppMetadata — ✅ built
- `AppInfo` — `version`, `build`, `versionWithBuild` (`"1.2 (45)"`), `displayName`, `bundleIdentifier`.
- `DeviceInfo` — `modelIdentifier` cross-platform; `systemName` / `systemVersion` / `model` / `summary` iOS-only.

### Networking — ✅ built
- `NetworkService` protocol — the networking seam. Two sends: decode-response (`send(_:as:decoder:)`) and fire-and-forget (`send(_:)` — status-validated, body discarded; for webhooks/pings that return 204 or an unneeded body).
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

### Settings — ✅ built
- `PASSettingsStore` — `@Observable open class` base for an app's UserDefaults-backed settings store. Holds the injected `UserDefaults` (`.standard` default; pass a suite for App Groups/tests) and a single tracked anchor; `removeValue(forKey:)` resets a setting to its declared default.
- `@PASDefault("key")` — one-line write-through property on a `PASSettingsStore` subclass. The declared initial value is the fallback (kept in the wrapper, not the registration domain). Optionals store `nil` as key absence — declare optional settings with a `nil` default.
- `UserDefaultsStorable` — round-trip protocol. Conformances: `Bool`, `Int`, `Double`, `String`, `Date`, `Data`, `URL`, `Optional`; `RawRepresentable` enums conform via an empty extension.
- `PASDraft<Value: Codable>` — one JSON-encoded in-progress value under a UserDefaults key (`save` / `load` / `clear`), best-effort. The "resume after kill" box for onboarding/forms — pairs with `PASOnboardingFlow` in PASKitLifecycle.

Design notes: no macro (keeps swift-syntax out of the dependency graph), so observation granularity is per-store, not per-key — any change invalidates views reading any setting from that store, which is imperceptible at settings-store scale. The subclass needs no `@Observable`/`@ObservationIgnored` of its own and may be `@MainActor`; the base is nonisolated so widget/off-main reads work.

### Styling — ✅ built
Brand-free styling *mechanisms* — the layer the per-app token systems sit on. Token values and vocabularies (spacing/radius/color/motion enums) stay per-app.
- `Animation.respectingReducedMotion(_:)` — `nil` when Reduce Motion is on; for call sites that read the environment themselves.
- `View.pasAnimation(_:reducedMotion:value:)` — `animation(_:value:)` that honors Reduce Motion itself; substitute defaults to `nil` (snap), pass a short ease for a gentler swap.
- `Color(light:dark:)` — appearance-resolving color without an asset catalog (UIColor/NSColor bridged, cross-platform).
- `Font.pasScaled(_:relativeTo:weight:design:)` — system font at a custom point size that tracks Dynamic Type via `UIFontMetrics` (fixed-size fallback on macOS).
- `PASFontRegistration.registerBundledFonts(named:bundle:)` — `CTFontManagerRegisterFontsForURL` loop working around Xcode's `GENERATE_INFOPLIST_FILE` dropping `UIAppFonts`; logs failures via `PASLogger`, never throws.

### Time — ✅ built
- `Date` extension (`pas`-prefixed, `calendar:` injectable for tests, defaults `.current`): `pasStartOfDay` / `pasEndOfDay`, `pasIsSameDay(as:)`, `pasDaysSince(_:)` (both ends startOfDay-normalized — kills the cross-midnight off-by-one), `pasAdding(days:)`, `pasStartOfWeek()` (honors `firstWeekday`), `pasHoursUntilMidnight()`. The day-gating/streak/rollover building blocks.
- `PASDurationFormat` — `compact(seconds:)` (`"42s"` / `"4m 12s"` / `"1h 03m"`) and `clock(seconds:)` (`"4:12"` / `"1:04:12"`); `TimeInterval` + `Int` overloads, negatives clamp.
- Deliberately **not** wrapped: date-to-string formatting (`formatted(.dateTime…)`, `RelativeDateTimeFormatter` already cover it) and 1:1 `Calendar` aliases (`isToday` etc.).

## Notes

- Design tokens stay per-app. PASKit has no design module — apps use SwiftUI defaults and their own per-app theme. Brand-free styling *mechanisms* (accessibility-aware animation, color/font plumbing) are the exception and live in `Styling/`.

## Remaining

- [ ] Unit tests.
