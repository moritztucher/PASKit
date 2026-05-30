# ``PASKit``

Modular Swift Package for solo iOS founders and small studios shipping multiple apps.

## Overview

PASKit is one Swift Package, multiple modules. Each module is a thin, library-quality facade over the infrastructure every iOS app eventually needs — networking, keychain, reachability, logging, app metadata, rate prompts, what's-new sheets, changelog views, version checks, feedback forms, and a generic analytics surface. Apps depend only on the modules they use.

The umbrella `PASKit` module re-exports every submodule, so apps that take the umbrella product can `import PASKit` once. Apps that depend only on a specific module — `PASKitCore`, `PASKitLifecycle`, `PASKitAnalytics` — import it directly.

### Modules

- **PASKitCore** — foundational utilities: `AppInfo`, `DeviceInfo`, `NetworkService`, `PASLogger`, `NWReachability`, `KeychainCredentialVault`, `Haptics`.
- **PASKitLifecycle** — app-lifecycle UI: `presentAppRating`, `presentAppFeedback`, `FeedbackSheet`, `loading` overlay, `paskitGlass`, `VersionCheckManager`, `AppUpdateView`, `WhatsNewView`, `ChangelogView`, `MailComposerView`, `AppInfoFooter`.
- **PASKitAnalytics** — thin PostHog facade: `PASAnalytics.shared.setup(...)` / `.capture` / `.screen` / `.identify` / `.register` / `.reset` / `.flush` / `.isFeatureEnabled` / `.featureFlagPayload`. Apps own the event vocabulary as an extension.

### Planned for v0.2.0

**PASKitPurchases** — RevenueCat wrapper. Not part of v0.1.0.

### Baseline

iOS 18+, macOS 15+. Swift 6 language mode. SwiftLint via `SimplyDanny/SwiftLintPlugins`.

### Build philosophy

PASKit is grown deliberately, not scaffolded upfront. A capability earns a place when the *first real app* needs it. Code is designed app-agnostic from line one. PASKit owns the *mechanism*; each app owns its *vocabulary* (event names, entitlement names, brand styling). The full version of these rules — and what they mean for contributors — lives in <doc:BuildPhilosophy>.

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:BuildPhilosophy>

### Modules
- <doc:LifecycleOverview>
- <doc:AnalyticsOverview>
