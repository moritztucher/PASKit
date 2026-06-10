# PASKitPurchases

> **Status: Shipped (v0.2.0-dev).** Built when XueTang V2 became the first consuming app to take payment (premium subscription + consumable coin packs).

**Dependencies:** `RevenueCat` SDK (`purchases-ios-spm`, from 5.67.0) + `PASKitCore`. `RevenueCatUI` is **not** linked — it joins the module if/when an app wants the hosted paywall (see below).

## Purpose

A thin, concrete wrapper over RevenueCat — configuration, live entitlement state, offerings/products, the purchase + restore flow, and user identity. A convenience wrapper, **not** a vendor-abstraction layer: RevenueCat is the committed vendor, RevenueCat types (`Offering`, `Package`, `CustomerInfo`, `StoreProduct`) pass through unwrapped.

## Surface

| API | Purpose |
|---|---|
| `PASPurchases.shared.configure(PASPurchasesConfig)` | One-time SDK setup at launch (public SDK key, optional `appUserID`, `debugLogs`). Idempotent. Starts the customer-info stream. |
| `customerInfo` | Observable, kept live by RevenueCat's customer-info stream — purchases, renewals, refunds, restores, other-device changes. The single source of truth for gating. |
| `isEntitled(_:)` | Entitlement check; accepts a raw `String` or any `String`-backed enum so apps keep a typed entitlement vocabulary. |
| `offerings()` / `currentOffering()` / `offering(identifier:)` | Dashboard offerings for custom paywall UI. |
| `products(_:)` | Direct `StoreProduct` fetch by product ID — for consumables addressed outside an offering. |
| `purchase(_ package:)` / `purchase(_ product:)` → `PASPurchaseResult` | Purchase flow; result carries `customerInfo`, `transaction`, `userCancelled`. |
| `restorePurchases()` | Wire to an explicit "Restore Purchases" control (App Review requirement). |
| `logIn(userId:)` / `logOut()` | Identity. **Shares one identity with `PASKitAnalytics`** — pass the same app-supplied user ID to both so revenue and analytics join on one key (convention, not code coupling — the modules stay independent). |

## Out of scope

- Custom paywall layouts — each app owns its paywall UI and merchandising copy.
- Wallet/virtual-currency state — RevenueCat's server-side Virtual Currencies require a backend (secret key) to debit. Backend-less apps sell **consumable products** through `purchase` and keep the wallet client-side; the app credits coins after a non-cancelled purchase. PASKit owns the purchase mechanism, the app owns the wallet.
- Code-level Apple-compliance enforcement — paywall layout is app territory; compliance is a checklist (below).

## Design decisions

- **Custom-paywall-first.** The original spec planned hosted-paywall-only. The first real consumer (XueTang V2) ships a locked, custom-designed paywall — so the module's surface is the purchase *flow* (offerings → purchase → entitlement), not paywall rendering. **Hosted paywall (`RevenueCatUI`) is deferred** until the first app wants the dashboard-rendered paywall; it will land as an additive presentation helper without changing the flow surface.
- **No vendor abstraction.** RevenueCat types pass through. Apps `import PASKitPurchases` and use `Package` / `CustomerInfo` directly.
- **Entitlements as app vocabulary.** The module takes `String`-backed enums; entitlement IDs live in the app.
- **Unified identity.** `PASPurchases.logIn` and `PASAnalytics.identify` consume the same app-supplied user ID — by documented convention, not a cross-module dependency.

## Apple 2026 paywall compliance checklist (for consuming apps)

- [ ] Billed amount is the visually dominant number (no oversized weekly-equivalent).
- [ ] No stacked-discount paywall; no decline → downsell modal (bannable under 3.1.2c).
- [ ] IAP present alongside any external payment link (external links US-only).
- [ ] Explicit "Restore Purchases" control wired to `restorePurchases()`.

## Future work

- [ ] Hosted-paywall presentation helper (`RevenueCatUI`) — when the first app wants it.
- [ ] Promo-code / win-back offer helpers — when the first app runs them.
