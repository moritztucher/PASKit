# Getting Started

Add PASKit to your iOS project and make your first call in under five minutes.

## Overview

PASKit is one Swift Package with seven modules: `PASKitCore`, `PASKitLifecycle`, `PASKitAnalytics`, `PASKitPurchases`, `PASKitNotifications`, `PASKitSharing`, and `PASKitHealth`. Depend on the umbrella ``PASKit`` product for the first six in one line, or pull individual modules to keep the binary lean and the dependency graph minimal — an app that takes no payment never links RevenueCat. `PASKitHealth` is never part of the umbrella — see <doc:HealthOverview> — so an app that uses Health always adds that product explicitly, umbrella or not.

## Add the package

In Xcode → File → Add Packages, paste:

```
https://github.com/moritztucher/PASKit
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/moritztucher/PASKit", from: "0.1.0")
```

Then choose the umbrella or individual modules:

```swift
// Umbrella — one import gives access to everything.
.product(name: "PASKit", package: "PASKit")
```

```swift
// Or individually — link only what you use.
.product(name: "PASKitCore", package: "PASKit"),
.product(name: "PASKitLifecycle", package: "PASKit"),
.product(name: "PASKitAnalytics", package: "PASKit"),
.product(name: "PASKitPurchases", package: "PASKit"),
.product(name: "PASKitNotifications", package: "PASKit"),
.product(name: "PASKitSharing", package: "PASKit"),
.product(name: "PASKitHealth", package: "PASKit"),   // always explicit — never part of the umbrella
```

## First call

Read app metadata — no setup required:

```swift
import PASKitCore

print(AppInfo.versionWithBuild)   // "1.2 (45)"
print(AppInfo.displayName)        // your CFBundleDisplayName
```

Attach a rate prompt to your root view — caller supplies the conditions:

```swift
import PASKitLifecycle

ContentView()
    .presentAppRating(
        initialCondition: { await sessions.count >= 7 },
        askLaterCondition: { await sessions.count >= 14 }
    )
```

Configure analytics once at launch, then capture from anywhere:

```swift
import PASKitAnalytics

PASAnalytics.shared.setup(.init(apiKey: AppKeys.posthog))
PASAnalytics.shared.capture("app_launched")
```

That's the surface. Read <doc:BuildPhilosophy> next for the rules that shape what PASKit ships, or jump straight into <doc:LifecycleOverview> or <doc:AnalyticsOverview>.
