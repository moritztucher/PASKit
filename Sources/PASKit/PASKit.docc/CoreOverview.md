# Core Overview

The foundational layer — metadata, networking, persistence, and calendar math every other module and app builds on.

## Overview

`PASKitCore` is the only module every app and every other module depends on. It carries the brand-free infrastructure that gets re-derived in app after app: app/device metadata, a networking seam, logging, reachability, keychain credentials, observable settings, calendar/streak math, and App Group storage. Nothing here knows anything app-specific — values and vocabulary are injected at the call site.

## Metadata

```swift
import PASKitCore

AppInfo.version             // "1.2"
AppInfo.versionWithBuild    // "1.2 (45)"
AppInfo.displayName
DeviceInfo.modelIdentifier  // "iPhone16,1" — cross-platform
```

## Logging

```swift
private let log = PASLogger.make(category: "purchases")
log.info("user \(id, privacy: .public) signed in")
```

A thin facade over `os.Logger` — no bootstrap step, subsystem resolves to `AppInfo.bundleIdentifier`, output lands in Console.app and the Logging instrument.

## Networking & reachability

```swift
let service = URLSessionNetworkService()
let user: User = try await service.send(request, as: User.self)   // 2xx + 429/Retry-After handled, decoded
log.error("\(request.cURL(pretty: true), privacy: .public)")       // replayable curl for debugging

@State private var reachability = NWReachability()
// observe reachability.status: .unknown / .online / .offline

PASError.localizer = { … }   // app copy for network errors; English developer text otherwise
```

## Settings

`PASSettingsStore` + `@PASDefault` replace hand-rolled UserDefaults plumbing — subclass once, one line per setting, observation for free:

```swift
@MainActor
final class SettingsStore: PASSettingsStore {
    @PASDefault("settings.hapticsEnabled") var hapticsEnabled = true
    @PASDefault("settings.customRest")     var customRest: Int?   // nil = key absent
}
```

`PASDraft<Value: Codable>` is the resume-after-kill box for in-progress forms and onboarding.

## Calendar math & streaks

```swift
today.pasDaysSince(start)        // whole days, startOfDay-normalized both ends
PASDurationFormat.clock(seconds: 3852)   // "1:04:12"

let (next, outcome) = PASStreakEngine.rolledOver(state, config: .init(freezeCap: 3))
```

`PASStreakEngine` is a pure state machine — survival/reset, freezes, free-freeze grants — with persistence left to the app (`PASStreakState` is `Codable`).

## Styling mechanisms

Brand-free *mechanisms* only — token values stay per-app: `Color(light:dark:)`, `Font.pasScaled`, `View.pasAnimation` (Reduce Motion-aware), `PASFontRegistration`, `.buttonStyle(.pasPressable())`.

## App Group storage

`PASAppGroupContainer` resolves a shared container and one-time-migrates an existing store (Realm, SQLite/SwiftData, or JSON) into it so a widget or extension can read it — store-engine-agnostic, with no persistence dependency of its own.
