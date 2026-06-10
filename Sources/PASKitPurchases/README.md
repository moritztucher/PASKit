# PASKitPurchases

Thin facade over the RevenueCat SDK. PASKit owns the mechanism (`configure`, customer-info observation, `offerings`, `purchase`, `restorePurchases`, `logIn`/`logOut`); apps own their vocabulary — entitlement IDs, product IDs, and the paywall UI itself. RevenueCat types (`Offering`, `Package`, `CustomerInfo`, `StoreProduct`) pass through unwrapped: this is a convenience wrapper, not a vendor abstraction.

## API

- `PASPurchases` — `@MainActor @Observable` singleton (`PASPurchases.shared`). Observable `customerInfo` kept live via RevenueCat's customer-info stream; `isEntitled(_:)` accepts a raw `String` or any `String`-backed enum.
- `PASPurchasesConfig` — config struct passed to `configure` (`apiKey` (public SDK key), `appUserID`, `debugLogs`).
- `PASPurchaseResult` — named result of `purchase` (`customerInfo`, `transaction`, `userCancelled`).

## Example

```swift
import PASKitPurchases

// At launch:
PASPurchases.shared.configure(.init(apiKey: AppKeys.revenueCat))

// App-level entitlement vocabulary:
enum Entitlement: String { case premium }

// Gate features (observable — SwiftUI views update automatically):
if PASPurchases.shared.isEntitled(Entitlement.premium) { … }

// Custom paywall flow:
let offering = try await PASPurchases.shared.currentOffering()
let result = try await PASPurchases.shared.purchase(offering!.availablePackages[0])
if !result.userCancelled, result.customerInfo.entitlements["premium"]?.isActive == true { … }

// Consumables addressed by product ID (e.g. coin packs):
let products = try await PASPurchases.shared.products(["app.coins.200"])
let outcome = try await PASPurchases.shared.purchase(products[0])
// App credits its own wallet after a non-cancelled purchase.
```

`configure` is idempotent — a second call logs a warning and no-ops. Every other call throws `PASError.unexpected` if `configure` hasn't run.

## Notes

- **Entitlement state**: gate on `customerInfo.entitlements[…]?.isActive` (via `isEntitled`) — never cache a boolean. The stream keeps it current across renewals, refunds, and other-device purchases.
- **Identity**: pass the same user ID to `logIn(userId:)` and `PASAnalytics.identify(userId:)` so revenue and analytics join on one key.
- **Virtual currency**: RevenueCat's server-side Virtual Currencies need a backend (secret key) to debit. Backend-less apps sell consumable products through `purchase` and keep the wallet client-side.
- **Hosted paywall** (`RevenueCatUI`): not part of this module yet — added when the first app wants the dashboard-rendered paywall instead of its own UI.
