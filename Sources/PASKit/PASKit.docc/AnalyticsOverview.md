# Analytics Overview

PASKit's PostHog facade — mechanism only, event vocabulary stays in the app.

## Overview

`PASKitAnalytics` is a thin facade over `PostHogSDK`. PASKit owns the generic surface — `setup`, `capture`, `screen`, `identify`, `register`, `reset`, `optIn`/`optOut`, `flush`, feature flags. The app owns its event vocabulary as a typed extension on `PASAnalytics` so the named events live at the call site, not inside the library.

## Configure once at launch

```swift
import PASKitAnalytics

PASAnalytics.shared.setup(.init(
    apiKey: AppKeys.posthog,
    captureScreenViews: true,
    sessionReplay: false
))
```

The `setup` call is idempotent — a second invocation logs a warning and no-ops, so it's safe to call from `App.init` or a top-level `task` modifier. Reach for `PASAnalyticsConfig` to tune lifecycle event capture, screen views, session replay, and debug logging.

## Capture events

PASKit ships *only* `.capture(_:properties:)`. Named events live in the app as a typed extension:

```swift
extension PASAnalytics {
    func captureOnboardingCompleted() {
        capture("onboarding_completed")
    }

    func captureLessonStarted(level: Int) {
        capture("lesson_started", properties: ["level": level])
    }
}
```

This is the "mechanism, not vocabulary" rule in action: PASKit doesn't get to decide what your events are called or what properties they carry.

## Identity

```swift
// On sign-in:
PASAnalytics.shared.identify(userId: user.id, traits: ["plan": "pro"])

// On sign-out:
PASAnalytics.shared.reset()
```

Use the same user ID for both analytics and any other identity-bearing service (RevenueCat, your backend), so events and revenue join cleanly in PostHog.

## Super-properties

Properties sent with every subsequent event — useful for slicing all events by a stable dimension:

```swift
PASAnalytics.shared.register([
    "device_model": DeviceInfo.modelIdentifier,
    "app_version": AppInfo.versionWithBuild,
])
```

## Feature flags

```swift
if PASAnalytics.shared.isFeatureEnabled("new_paywall") {
    PaywallV2()
} else {
    PaywallV1()
}
```

For payload-bearing flags use `PASAnalytics.featureFlagPayload(_:)`.

## Consent

`PASAnalytics.shared.optIn()` / `.optOut()` toggle PostHog's capture switch. Call from a privacy settings screen or in response to an in-app consent banner.
