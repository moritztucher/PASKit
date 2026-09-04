# ADR-0004 — `PASKitHealth` is not re-exported by the `PASKit` umbrella

**Status:** Accepted — drafted and implemented 2026-09-04.

## Context

`PASKitHealth` (action-plan **P7**) is a HealthKit facade extracted from two apps' independently
written, structurally identical `HealthManager`/`HealthProfileReader` code. Every other PASKit
module is re-exported by the `PASKit` umbrella target (`@_exported import`), and both
`CLAUDE.md`'s module table and `CLAUDE-INTEGRATION.md` (`"PASKit (umbrella) | Re-exports every
module"`) currently state that as an unqualified promise.

SwiftPM targets are statically linked into the consuming app's binary — there is no dynamic,
load-on-demand linking for a library product. A binary that references `HKHealthStore` or its
authorization API fails App Store upload validation with ITMS-90683 ("Missing purpose string in
Info.plist") unless the app declares `NSHealthShareUsageDescription` (and
`NSHealthUpdateUsageDescription` if it also writes), regardless of whether the app ever executes
the HealthKit code path at runtime. Two of PASKit's three consuming apps take the `PASKit`
umbrella today (WorkoutApp, XueTangV2) and only one of them (WorkoutApp) has any HealthKit feature
at all.

## Decision

**`PASKitHealth` is deliberately excluded from the `PASKit` umbrella target.** Apps that use Health
add the `PASKitHealth` product explicitly, the same way every per-module product already works
alongside the umbrella. `Sources/PASKit/PASKit.swift` carries a comment explaining the omission
rather than silently doing something an app-side session would have to reverse-engineer from a
missing symbol.

The alternative — include it, and accept that every umbrella consumer must add
`NSHealthShareUsageDescription` to ship — was rejected. It would force XueTangV2, which has no
HealthKit feature today or planned, to carry a permission string it never uses (which is itself a
minor App Review smell — a declared usage description for a capability the app never asks
permission for) purely because of how it links a dependency that has nothing to do with the
umbrella's actual purpose (one import line for convenience).

This is the one place PASKit's "the umbrella re-exports everything" rule is broken, and the break
is intentional rather than an oversight — hence this ADR, and the correction of that promise
wherever it was stated as unqualified (`CLAUDE.md`, `CLAUDE-INTEGRATION.md`, the DocC landing page,
and `GettingStarted.md`).

## Consequences

- **Existing umbrella consumers link nothing new from P7.** WorkoutApp and XueTangV2's `import
  PASKit` continues to resolve exactly the six modules it always has; neither picks up HealthKit
  by moving their `Package.resolved` pin to a release that contains `PASKitHealth`.
- **Every HealthKit app, including WorkoutApp** (today's only umbrella consumer with a Health
  feature), **must add the `PASKitHealth` product to its target explicitly** — an
  `XCSwiftPackageProductDependency` alongside the umbrella, not instead of it. This is a one-time,
  explicit adoption step, tracked as separate work per the app's own migration.
- **Precedent for future modules**: any module whose *linking alone* — independent of whether the
  app calls into it — creates an App Store review or entitlement obligation for every consumer
  (a usage string, a background mode, a restricted API) is a candidate for the same exclusion.
  `PASKitPurchases` and `PASKitAnalytics` don't qualify — RevenueCat and PostHog impose no linking-time
  review obligation — so this is not a general precedent against vendor SDKs in the umbrella, only
  against system-framework permission surfaces.
- The module table in `CLAUDE.md`, the modules table in `CLAUDE-INTEGRATION.md`, the DocC landing
  page, and `GettingStarted.md` all now say "six modules in the umbrella, seven modules total" (or
  equivalent), rather than implying `PASKitHealth` is one `import PASKit` away.
