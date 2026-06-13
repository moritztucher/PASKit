# ``PASKit``

Modular Swift Package for solo iOS founders and small studios shipping multiple apps.

## Overview

PASKit is one Swift Package, multiple modules. Each module is a thin, library-quality facade over the infrastructure every iOS app eventually needs — networking, keychain, reachability, logging, app metadata, rate prompts, what's-new sheets, changelog views, version checks, feedback forms, and a generic analytics surface. Apps depend only on the modules they use.

The umbrella `PASKit` module re-exports every submodule, so apps that take the umbrella product can `import PASKit` once. Apps that depend only on a specific module import it directly.

### Modules

- **PASKitCore** — foundational utilities: `AppInfo`, `DeviceInfo`, `NetworkService`, `PASLogger`, `NWReachability`, `KeychainCredentialVault`, `Haptics`, `PASSettingsStore` + `@PASDefault`, `PASDraft`, styling mechanisms (`Color(light:dark:)`, `Font.pasScaled`, `pasAnimation`), `Date.pas…` calendar math + `PASDurationFormat`, `PASStreakEngine`, `PASAppGroupContainer`.
- **PASKitLifecycle** — app-lifecycle UI: `presentAppRating`, `presentAppFeedback`, `FeedbackSheet`, `loading` overlay, `paskitGlass`, `VersionCheckManager`, `AppUpdateView`, `WhatsNewView`, `ChangelogView`, `MailComposerView`, `AppInfoFooter`, onboarding engine (`PASOnboardingFlow`), `pasDevelopmentOverlay`, `pasToast`, `PASProgressRing`.
- **PASKitAnalytics** — thin PostHog facade: `PASAnalytics.shared.setup(...)` / `.capture` / `.screen` / `.identify` / `.register` / `.reset` / `.flush` / `.isFeatureEnabled` / `.featureFlagPayload`. Apps own the event vocabulary as an extension.
- **PASKitPurchases** — thin RevenueCat facade: `configure`, observable `customerInfo`, `isEntitled`, offerings/products, `purchase`/`restorePurchases`, `logIn`/`logOut`, plus the paywall logic layer (`PASPaywallFlow`, `pasSavingsPercent`). Apps own entitlement/product IDs and paywall UI.
- **PASKitNotifications** — thin `UNUserNotificationCenter` facade: `configure`, observable `authorizationStatus`, `onResponse` tap routing, `schedule`/`fireTest`/`cancel`, `.dailyAt` trigger sugar. Apps own scheduling policy and copy.
- **PASKitSharing** — share-card export: `PASShareCard.render`, `PASInstagramStories`, `PASPhotoLibrary`, `PASActivitySheet`. Apps own card designs and captions.

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
