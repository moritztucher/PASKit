# PASKitAnalytics

**Status:** Built — thin PostHog facade compiling. Sources split across `PASAnalytics.swift` (the facade class) and `PASAnalyticsConfig.swift` (the config struct).
**Dependencies:** `PostHog` SDK (`posthog-ios`, from 3.48.3) + `PASKitCore`.
**Platforms:** iOS 18+, macOS 15+. Session replay is iOS-only at the SDK level (`#if os(iOS)`-gated); the rest of the surface works on both.

## Purpose

A thin, concrete facade over PostHog. PostHog is the committed analytics vendor — this is **not** a vendor-agnostic protocol (one conformer forever is a YAGNI tax). Apps call the PASKit facade, not `PostHogSDK` directly.

## Scope — mechanism only

PASKit owns the generic **mechanism**:

- `setup(_:)` — configure PostHog from `PASAnalyticsConfig`. API key injected, never read from Info.plist.
- `capture(_:properties:)` / `screen(_:properties:)` — generic event + screen surface.
- `identify(userId:traits:)` / `register(_:)` / `reset()` — identity, super-properties, logout.
- `optIn()` / `optOut()` / `flush()` — consent + lifecycle.
- `isFeatureEnabled(_:)` / `featureFlagPayload(_:)` — feature-flag reads.

Each app owns its **vocabulary** — its typed `captureXxx` methods, declared as a thin extension over `capture`. Event names and domain types never enter PASKit. (One prior app had 35 typed `captureXxx` methods — all of them 100% app-specific vocabulary that belongs in the app, not in PASKit.)

## Public surface

```swift
public struct PASAnalyticsConfig: Sendable {
    public let apiKey: String
    public let host: String                              // default us.i.posthog.com
    public let captureApplicationLifecycleEvents: Bool   // default true
    public let captureScreenViews: Bool                  // default true
    public let sessionReplay: Bool                       // default false — iOS only
    public let debug: Bool                               // default false
}

@MainActor @Observable
public final class PASAnalytics {
    public static let shared: PASAnalytics
    public private(set) var isConfigured: Bool
    public func setup(_ config: PASAnalyticsConfig)
    public func capture(_ event: String, properties: [String: Any]? = nil)
    public func screen(_ name: String, properties: [String: Any]? = nil)
    public func identify(userId: String, traits: [String: Any]? = nil)
    public func register(_ properties: [String: Any])
    public func reset()
    public func optIn()
    public func optOut()
    public func flush()
    public func isFeatureEnabled(_ key: String) -> Bool
    public func featureFlagPayload(_ key: String) -> Any?
}
```

## Design decisions

- **Concrete facade, no protocol.** Wrapped for ergonomics + one chokepoint, not for swappability.
- **API key injected** via `PASAnalyticsConfig`. PASKit does not read from `Info.plist` — apps source the key from their secrets layer and pass it in.
- **Session replay** is a `PASAnalyticsConfig` field, **default OFF**. Replay has cost + privacy weight, opt in per app. iOS-only at the SDK level.
- **`projectToken`** is used internally — PostHog deprecated the `apiKey` initializer. The PASKit-side parameter stays named `apiKey` for familiarity.
- **No automatic DEBUG gate.** Apps decide whether to wire `setup` behind `#if !DEBUG`; PASKit does not silently swallow events. The `debug:` flag toggles PostHog SDK-side debug logging, not consent.
- **Unified identity** — `identify` consumes the same user ID as `PASKitPurchases.logIn`, so analytics and revenue join on one key (once `PASKitPurchases` ships).
- **`@MainActor @Observable`** — matches `NWReachability` and the rest of the PASKit surface; safe to observe from SwiftUI.

## Remaining

- [ ] Feature-flag reload hook (PostHog supports `reloadFeatureFlags`; add when an app actually drives the lifecycle).
- [ ] Group analytics (`group(type:key:groupProperties:)`) if any consuming app grows a B2B surface.
- [ ] Unit tests — facade is thin, but the `isConfigured` guard is worth a test.
