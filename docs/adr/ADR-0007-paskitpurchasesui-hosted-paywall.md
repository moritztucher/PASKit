# ADR-0007 — `PASKitPurchasesUI`: the dashboard paywall as a separate product

**Status:** Accepted — drafted and implemented 2026-10-04.

## Context

`PASKitPurchases` deferred the hosted RevenueCat paywall (`RevenueCatUI`) "until the first app wants it". XueTang is that app: its paywall design moves into the RevenueCat dashboard so copy, layout and experiments change without an app release, with a different paywall per moment (onboarding, a locked unit, settings) via RevenueCat placements.

## Decision 1 — a new product, not an addition to `PASKitPurchases`

RevenueCatUI is a SwiftUI framework with its own bundled resources and a sizeable binary footprint. Every app that takes payment links `PASKitPurchases`; only apps that use the dashboard paywall need RevenueCatUI. Folding it into `PASKitPurchases` would make the custom-paywall apps pay for it. The placement lookup itself (`PASPurchases.offering(forPlacement:)`) is UI-free and lives in `PASKitPurchases`, so custom paywalls can use placements too.

## Decision 2 — not re-exported by the umbrella

Same reasoning as ADR-0004/0005/0006: the umbrella re-exports only what imposes nothing on an app that does not use it. Apps add `.product(name: "PASKitPurchasesUI", package: "PASKit")` explicitly.

## Decision 3 — outcome callbacks instead of RevenueCat's dismissal

`PASPaywallView` always installs `onRequestedDismissal`, so RevenueCatUI never calls `dismiss()` on its own, and reduces RevenueCat's callbacks to `onEntitled` / `onClose`, exactly one per presentation. This keeps the paywall usable both in a sheet and embedded directly in a flow (a paywall the user cannot swipe away), where the caller, not the paywall, decides what happens next.

## Consequences

- The dashboard paywall must carry the App Review essentials (Restore, Terms, Privacy, post-trial price); PASKit cannot enforce them.
- `PASPaywallFlow` and the pricing helpers stay for apps that draw their own paywall.
