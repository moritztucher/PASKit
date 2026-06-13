# Purchases Overview

PASKit's RevenueCat facade — entitlement state, offerings, and the purchase flow. The app owns the paywall UI and the IDs.

## Overview

`PASKitPurchases` is a thin concrete facade over the RevenueCat SDK — a convenience wrapper, not a vendor abstraction. RevenueCat's own types (`Offering`, `Package`, `CustomerInfo`, `StoreProduct`) pass through unwrapped. PASKit owns the mechanism (configure, observe, purchase, restore, identity); each app owns its vocabulary (entitlement IDs, product IDs, paywall UI).

## Configure once at launch

```swift
import PASKitPurchases

PASPurchases.shared.configure(.init(apiKey: AppKeys.revenueCat))
```

Subsequent calls log a warning and no-op. From `configure` onward, `customerInfo` is kept current by RevenueCat's stream — purchases, renewals, refunds, restores, and other-device changes all land there.

## Gate on entitlements

```swift
enum Entitlement: String { case premium }

if PASPurchases.shared.isEntitled(Entitlement.premium) {
    PremiumContent()
}
```

`isEntitled` reads the observable `customerInfo`, so gate features on it directly rather than caching a boolean. It's `false` until the first customer info arrives — treat that as "not entitled yet", not an error.

## Offerings & purchase

```swift
let offering = try await PASPurchases.shared.currentOffering()
let result = try await PASPurchases.shared.purchase(package)

if result.userCancelled { return }          // inspect before treating as success
// derive access from the entitlement, not from the absence of an error
```

`offerings()` / `currentOffering()` / `offering(identifier:)` surface what's configured in the dashboard; `products(_:)` fetches store products directly for offering-less consumables.

## Restore & identity

```swift
try await PASPurchases.shared.restorePurchases()   // wire to an explicit "Restore Purchases" control (App Review requires one)
try await PASPurchases.shared.logIn(userId: user.id)   // same ID as PASAnalytics.identify, so revenue + analytics join
try await PASPurchases.shared.logOut()
```

## Paywall logic, not UI

PASKit ships the pricing *math* — `PASPaywallFlow` and helpers like `pasSavingsPercent` for "save 40%" badges — but no paywall rendering. The first consuming app ships a custom-designed paywall; the hosted RevenueCat paywall (`RevenueCatUI`) is deferred until an app actually wants it.
