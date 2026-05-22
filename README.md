# PASKit

Shared service package for **Pocket Apps Studio** — the reusable core across every PAS app.

## What it is

PASKit collects the cross-cutting infrastructure every Pocket Apps Studio app needs, so each new app ships a core feature instead of rebuilding its plumbing. Build it once, reuse it across the portfolio.

## Modules

Built incrementally — modules are lifted into PASKit as they prove reusable across live app builds, not designed up front.

- **Auth** — sign-in and account handling
- **Purchases** — RevenueCat integration and user / entitlement state
- **Paywall** — paywall presentation, remotely configurable
- **Analytics** — analytics abstraction (PostHog / TelemetryDeck)
- **Onboarding** — first-run flows
- **Settings** — shared settings surface
- **Design System** — shared visual components
- **Feedback** *(planned)* — in-app feedback tooling

## Status

Early. PASKit accretes out of live app builds — reusable parts are extracted in as they emerge.

## Installation

Swift Package Manager — add the dependency in Xcode or `Package.swift`:

```swift
.package(url: "git@github.com:moritztucher/PASKit.git", branch: "main")
```

## License

Proprietary. © 2026 Pocket Apps Studio. All rights reserved. See [LICENSE](LICENSE).
