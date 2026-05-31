# PASKitAnalytics

Thin facade over `PostHogSDK`. PASKit owns the mechanism (`setup`, `capture`, `identify`, `register`, `reset`, `optIn`/`optOut`, `flush`, feature flags); apps own their event vocabulary as an extension on `PASAnalytics`.

## API

- `PASAnalytics` — `@MainActor @Observable` singleton (`PASAnalytics.shared`).
- `PASAnalyticsConfig` — config struct passed to `setup` (`apiKey`, `host`, `captureApplicationLifecycleEvents`, `captureScreenViews`, `sessionReplay` (iOS), `debug`).

## Example

```swift
import PASKitAnalytics

// At launch:
PASAnalytics.shared.setup(.init(apiKey: AppKeys.posthog))

// From anywhere:
PASAnalytics.shared.capture("app_launched")
PASAnalytics.shared.identify(userId: user.id, traits: ["plan": "pro"])

// App-level vocabulary as an extension:
extension PASAnalytics {
    func captureOnboardingCompleted() {
        capture("onboarding_completed")
    }
}
```

`setup` is idempotent — a second call logs a warning and no-ops.
