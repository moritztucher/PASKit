# PASKit

> Modular Swift Package for solo iOS founders and small studios shipping multiple apps.

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2018%2B%20%7C%20macOS%2015%2B-blue.svg)](#)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![DocC](https://img.shields.io/badge/docs-DocC-blue.svg)](https://moritztucher.github.io/PASKit/documentation/paskit/)

## What it is

One Swift Package, multiple modules. Each module is a thin, library-quality facade over the infrastructure every iOS app eventually needs — networking, keychain, reachability, logging, app metadata, rate prompts, what's-new sheets, changelog views, version checks, feedback forms, and a generic analytics surface. Built and extracted from production apps over 12 months. Apps depend only on what they use.

## Who it's for

- Solo iOS founders shipping app #2, #3, #4 who don't want to rebuild the plumbing every time
- Small studios with shared cross-app infrastructure
- Anyone who wants a thin, modern (Swift 6 / iOS 18+ / SwiftUI) facade over RevenueCat (v0.2.0+), PostHog, and the system frameworks for networking, keychain, and reachability

## Install

Swift Package Manager — add the dependency in Xcode or `Package.swift`:

```swift
.package(url: "https://github.com/moritztucher/PASKit.git", from: "0.1.0")
```

Then add the modules you need to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "PASKitCore", package: "PASKit"),
        .product(name: "PASKitLifecycle", package: "PASKit"),
        .product(name: "PASKitAnalytics", package: "PASKit"),
    ]
)
```

Or take the umbrella `PASKit` product for one dependency line; `import` modules individually.

## Modules

One Swift package, one library product per module — an app imports only what it needs. Each module has a spec in [`docs/`](docs/); see [`CLAUDE.md`](CLAUDE.md) for the build philosophy.

| Module | Status | Purpose | Spec |
|--------|--------|---------|------|
| `PASKitCore` | v0.1.0 | App + device metadata, networking, reachability, keychain, logging, haptics | [docs/PASKitCore.md](docs/PASKitCore.md) |
| `PASKitLifecycle` | v0.1.0 | Rate prompt, version check, what's-new, changelog, feedback form, app-info footer, Liquid Glass | [docs/PASKitLifecycle.md](docs/PASKitLifecycle.md) |
| `PASKitAnalytics` | v0.1.0 | Thin PostHog facade — generic capture surface, app owns the vocabulary | [docs/PASKitAnalytics.md](docs/PASKitAnalytics.md) |
| `PASKitPurchases` | **Planned (v0.2.0)** | RevenueCat wrapper — entitlements, gating, hosted paywall | [docs/PASKitPurchases.md](docs/PASKitPurchases.md) |

Modules are built on first real need, not scaffolded up front.

## Quick tour

**PASKitCore** — logger, app metadata, reachability:

```swift
import PASKitCore

private let log = PASLogger.make(category: "purchases")
log.info("user \(id, privacy: .public) signed in")

AppInfo.version             // "1.2"
AppInfo.versionWithBuild    // "1.2 (45)"
AppInfo.displayName

@State private var reachability = NWReachability()
// .onAppear { reachability.start() } / .onDisappear { reachability.stop() }
// observe reachability.status: .unknown / .online / .offline
```

**PASKitLifecycle** — rate prompt, changelog, what's-new:

```swift
import PASKitLifecycle

// Two-stage rate-the-app prompt
SomeView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 }
)

// One-shot post-update sheet
WhatsNewView(appName: "MyApp", title: "What's New") {
    WhatsNewCard(symbol: "star.fill", title: "X", subtitle: "Y")
    WhatsNewCard(symbol: "bolt.fill", title: "A", subtitle: "B")
} onContinue: { dismiss() }

// Multi-version Settings screen
ChangelogView(entries: [
    ChangelogEntry(version: "1.2.0", date: .now, items: [
        .added("Live Activities on the home screen"),
        .changed("Faster sync"),
        .fixed("Crash on launch under iOS 18.0"),
    ])
])
```

**PASKitAnalytics** — PostHog facade, app owns vocabulary:

```swift
import PASKitAnalytics

// At launch
PASAnalytics.shared.setup(.init(apiKey: AppKeys.posthog))

// From anywhere
PASAnalytics.shared.capture("paywall_viewed")
PASAnalytics.shared.screen("Home")
PASAnalytics.shared.identify(userId: user.id, traits: ["plan": "pro"])

// App-side vocabulary lives as an extension — never inside PASKit
extension PASAnalytics {
    func captureOnboardingCompleted() { capture("onboarding_completed") }
}
```

## Architecture decisions

Linked: [ADR-0001 — PASKit reconciliation](docs/adr/ADR-0001-paskit-dashboard-reconciliation.md). Per-module products + umbrella, iOS 18+ baseline, no design layer, thin vendor facades not abstract protocols, `os.Logger` over swift-log.

## Claude Code integration

PASKit ships with [CLAUDE-INTEGRATION.md](CLAUDE-INTEGRATION.md) — drop `@../PASKit/CLAUDE-INTEGRATION.md` (sibling-repo path) into your consuming app's `CLAUDE.md`, and Claude Code sessions automatically know PASKit's API surface and conventions. One of the few Swift Packages designed for AI-augmented iOS development from day one.

## Documentation

DocC-generated reference: [moritztucher.github.io/PASKit](https://moritztucher.github.io/PASKit/documentation/paskit/) (published from `main`).

Inline `///` comments drive the docs — no catalog needed. Generate locally with:

```bash
swift package generate-documentation
```

## Versioning

Semantic versioning. `v0.x.y` while modules stabilise. `v1.0.0` marks API freeze and adoption commitment.

## License

MIT. © 2026 Moritz Tucher. See [LICENSE](LICENSE).
