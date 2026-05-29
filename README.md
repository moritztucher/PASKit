# PASKit

Shared service package for **Pocket Apps Studio** — the reusable core across every PAS app.

## What it is

PASKit collects the cross-cutting infrastructure every Pocket Apps Studio app needs, so each new app ships a core feature instead of rebuilding its plumbing. Build it once, reuse it across the portfolio.

## Modules

One Swift package, one library product per module — an app imports only what it needs. Each module has a spec in [`docs/`](docs/); see [`CLAUDE.md`](CLAUDE.md) for the build philosophy.

- **PASKitCore** — foundational utilities (`AppInfo`, `NetworkMonitor`) + the `PASTheme` contract — [docs](docs/PASKitCore.md)
- **PASKitLifecycle** — app-lifecycle UI: rate prompt, update check, what's-new, feedback, app-info footer — [docs](docs/PASKitLifecycle.md)
- **PASKitAnalytics** — PostHog facade — [docs](docs/PASKitAnalytics.md)
- **PASKitPurchases** — **Planned (v0.2.0)** — not in v0.1.0. RevenueCat wrapper: entitlements, gating, hosted paywall — [docs](docs/PASKitPurchases.md)

Modules are built on first real need, not scaffolded up front.

## Status

Early. PASKit accretes out of live app builds — reusable parts are extracted in as they emerge.

## Installation

Swift Package Manager — add the dependency in Xcode or `Package.swift`:

```swift
.package(url: "git@github.com:moritztucher/PASKit.git", branch: "main")
```

## License

MIT. © 2026 Moritz Tucher. See [LICENSE](LICENSE).
