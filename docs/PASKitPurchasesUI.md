# PASKitPurchasesUI

> **Status: Shipped (0.7.0).** Built when XueTang moved its paywall design into the RevenueCat dashboard (2026-10-04).

**Dependencies:** `PASKitPurchases`, `RevenueCat` + `RevenueCatUI` (`purchases-ios-spm`). **Not part of the `PASKit` umbrella** — see [ADR-0007](adr/ADR-0007-paskitpurchasesui-hosted-paywall.md).

## Purpose

Render the paywall an app designs in the RevenueCat dashboard, for a placement, and report the outcome. The companion to `PASKitPurchases`' custom-paywall flow (`PASPaywallFlow`): an app uses one or the other per paywall.

## Surface

| API | Purpose |
|---|---|
| `PASPaywallView(placementID:entitlementID:displayCloseButton:fonts:onEntitled:onClose:)` | The dashboard paywall for the offering the placement resolves to. `onEntitled` once the entitlement is active after a purchase or restore; `onClose` on a dismissal request without it (close button, acknowledged error). Exactly one outcome per presentation; never dismisses itself. |
| `PASPaywallView(placement:entitlement:…)` | Typed variant for `String`-backed placement and entitlement enums. |
| `PASPurchases.offering(forPlacement:)` *(in PASKitPurchases)* | Placement → offering lookup with current-offering fallback; usable without this module. |

## Design decisions

- **Outcome callbacks, not dismissal.** RevenueCatUI dismisses itself through `@Environment(\.dismiss)` unless a dismissal handler is set. The wrapper always sets one, so the caller decides what "done" means — required for paywalls embedded directly in a flow rather than presented.
- **Entitlement, not purchase success.** A completed purchase or restore only counts when the passed entitlement is active, matching the `PASPaywallFlow` rule.
- **Fallback over failure.** A failed placement lookup renders RevenueCat's current-offering paywall, which carries its own error and retry UI, instead of a PASKit error view (PASKit ships no design layer).
- **Separate product.** RevenueCatUI is a UI framework with bundled resources; an app drawing its own paywall should not link it.

## Future work

- [ ] Paywall footer / `presentPaywallIfNeeded` helpers — when an app wants them.
