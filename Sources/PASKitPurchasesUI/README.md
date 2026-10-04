# PASKitPurchasesUI

The RevenueCat dashboard-designed paywall (`RevenueCatUI`) for a placement, reduced to two outcomes: entitled, or closed without it. PASKit owns the mechanism (placement → offering lookup, the once-only outcome, no self-dismissal); the app owns the placement and entitlement identifiers and when the paywall appears. Layout, copy, prices and the close button come from the RevenueCat dashboard. **Not in the umbrella** — link the `PASKitPurchasesUI` product explicitly.

## API

- `PASPaywallView` — SwiftUI view. `init(placementID:entitlementID:displayCloseButton:fonts:onEntitled:onClose:)`, plus a typed `init(placement:entitlement:…)` for the app's `String`-backed enums. Resolves the offering through `PASPurchases.offering(forPlacement:)` (falling back to the current offering, then to RevenueCat's own current-offering paywall if the lookup fails). `onEntitled` fires once a purchase or restore leaves the entitlement active; `onClose` when the paywall asks to be dismissed without it. Exactly one fires per presentation. Never dismisses itself, so it works embedded (a non-swipeable paywall) and in a `.sheet`.

## Example

```swift
import PASKitPurchasesUI

enum Entitlement: String { case premium }
enum Placement: String { case onboarding = "onboarding", lockedFeature = "locked_feature" }

.sheet(item: $paywallPlacement) { placement in
    PASPaywallView(placement: placement,
                   entitlement: Entitlement.premium,
                   onEntitled: { paywallPlacement = nil },
                   onClose: { paywallPlacement = nil })
}
```

## Notes

- **Placements** are created in the RevenueCat dashboard (Targeting → Placements) and mapped to offerings; each offering carries its own paywall. An unmapped placement gets the dashboard's fallback, then the current offering.
- **App Review**: the dashboard paywall must itself carry Restore, Terms, Privacy and the post-trial price — the app no longer draws them.
- `PASPurchases.shared.configure(...)` must have run first, as for every PASKitPurchases call.
