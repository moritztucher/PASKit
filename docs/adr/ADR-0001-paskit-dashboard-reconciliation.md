# ADR-0001 — PASKit ↔ AnalyticsDashboard reconciliation

**Status:** Accepted — drafted 2026-05-22, executed 2026-05-22 → 2026-05-23.

## Context

PASKit (this repo) was created as the studio's shared Swift package for cross-app infrastructure — auth, purchases, analytics, lifecycle, utilities. The AnalyticsDashboard already shipped its own multi-target local packages — `ADServicesKit` (8 targets) and `ADDesignKit` — backed by its own `docs/decisions/ADR-0002-package-architecture.md`.

Several `ADCoreKit` files overlapped exactly with PASKit's intended scope (`NetworkService`, `ADError`, `ADLogger`, `Reachability` / `NWReachability`, `CredentialVault` / `KeychainCredentialVault`), and `ADPaywallKit` was conceptually the same as `PASKitPurchases`. Two parallel studio-shared-package efforts inside one studio is the fragmentation risk both packages exist to avoid.

The discovery (mid-reconciliation, while migrating XueTang utilities into PASKit) forced a structural decision.

## Decision

**1. One studio shared package = PASKit.** The studio-generic code that lived inside the AnalyticsDashboard migrates out into PASKit; the Dashboard depends on PASKit. The `AD` prefix is app-scoped — the wrong scope for code reused across the portfolio.

**2. Baseline: iOS 18 / macOS 15 / swift-tools 6.3 / Swift 6 mode.** Matches the Dashboard so migrated code ports without down-port checks. New apps target iOS 18+ regardless. Cost: PASKit cannot serve an iOS-17 app — older apps in the portfolio will not be refactored onto it anyway.

**3. One package, multiple targets, per-module + umbrella products.** Rejected the separate-packages-per-module restructure. Per-module products keep extension targets surgical (a widget cannot accidentally link RevenueCat); the umbrella `PASKit` product gives the main app target a single dependency line. Same shape as ADR-0002 for the same reasons.

**4. PASKit owns no design layer.** A draft `PASKitUI` (Theme + Color+LightDark) was added then reverted — UI / theme is per-app. Every app owns its own visual identity. PASKit imposes no styling; lifecycle views use SwiftUI defaults and read app styling via the standard environment (`.tint`, `.font`, `.preferredColorScheme`).

**5. Logging uses `os.Logger` directly, not swift-log.** `PASLogger` is a thin facade over `os.Logger` — what gives Instruments and Console.app visibility in the first place. The swift-log abstraction earned nothing on an iOS / macOS-only studio package; dropped entirely.

**6. ADPaywallKit retired.** The Dashboard's stub paywall target is removed; `PASKitPurchases` takes its role when implemented (wraps `RevenueCat` + `RevenueCatUI`).

## Migration executed

**PASKit gained:**
- `PASKitCore` — `AppInfo`, `DeviceInfo`, `NetworkService`, `PASError`, `PASLogger`, `Reachability` / `NWReachability`, `CredentialVault` / `KeychainCredentialVault`. Single third-party dep: `KeychainAccess`.
- `PASKitLifecycle` — `AppRatingHelper`, `VersionCheckManager`, `AppUpdateView`, `WhatsNewView`, `MailComposerView`, `AppInfoFooter`. Depends on `PASKitCore`.
- `PASKitPurchases` (stub) + `RevenueCat` SDK dependency wired.
- `PASKitAnalytics` (stub) + `PostHog` SDK dependency wired.
- Umbrella `PASKit` product re-exporting all four.
- SwiftLint via `SimplyDanny/SwiftLintPlugins`, config copied from the Dashboard so the studio runs one style baseline.

**The Dashboard:**
- `ADServicesKit/Package.swift` — added `.package(path: "../../PASKit")`. `ADCoreKit` depends on `PASKitCore`. Dropped `apple/swift-log` and `KeychainAccess` top-level deps. Retired the `ADPaywallKit` target, product, and the `purchases-ios` dep that backed it.
- Deleted: 7 migrated `ADCoreKit` files + `ADPaywallKit/ADPaywallKit.swift`.
- `ADCoreKit/ADCoreKit.swift` — version bumped to `0.2.0-paskit`, doc comment updated.
- Both `AnalyticsDashboardApp.swift` app shells — `import PASKitCore` added, `ADLogger.bootstrap()` removed (no bootstrap needed with `os.Logger`), `ADLogger.make` → `PASLogger.make`.
- `ADDesignKit` untouched — theme stays per-app.

## Consequences

- `ADCoreKit` shrinks to Dashboard-specific infrastructure (`DataSource` protocol, SwiftData stack, layout / filter stores, `MockDataService`).
- New PAS apps depend directly on PASKit; the Dashboard transitively pulls in `PASKitCore` through its `ADCoreKit` dependency.
- PASKit's `develop` is the single source of truth for studio-shared infrastructure.
- ADR-0002 (the Dashboard's package architecture) still governs `ADServicesKit`'s Dashboard-internal multi-target shape — it now sits one layer above PASKit in the dependency graph instead of acting as the studio's outer layer.
- Future per-source kits (`ADPostHogKit`, `ADRevenueCatKit`, etc.) will add their own `PASKitCore` target dependency when implemented — none of them needs it yet at the stub stage.

## References

- AnalyticsDashboard `docs/decisions/ADR-0002-package-architecture.md`
- PASKit `docs/PASKitCore.md`, `docs/PASKitLifecycle.md`, `docs/PASKitPurchases.md`, `docs/PASKitAnalytics.md`
- Commits — PASKit: `b9c6e90` (Core migration), `d01b9d7` → `ec3ce3a` (PASKitUI added + reverted), `3fc233f` (SwiftLint), `1f1cf56` (PASKitLifecycle), `83c9c1c` (os.Logger). Dashboard: `c9c91ba` (Phase 2 reconciliation).
