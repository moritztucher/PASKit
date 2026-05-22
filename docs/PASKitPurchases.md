# PASKitPurchases

**Status:** Scaffolded — target + RevenueCat dependency wired (`Sources/PASKitPurchases/`). Module API not yet written.
**Build trigger:** When the first app needs to take payment. (Candidate: the Analytics Dashboard, if it ships public with a paywall.)
**Dependencies:** `RevenueCat` SDK (`purchases-ios-spm`, from 5.67.0) + `PASKitCore`. `RevenueCatUI` is wired in alongside the hosted-paywall code, not the scaffold.

## Purpose

A thin, concrete wrapper over RevenueCat — entitlements, feature gating, and presentation of the RevenueCat-hosted paywall. A convenience wrapper, **not** a vendor-abstraction layer: RevenueCat is the committed vendor, the wrapper does not pretend it is swappable.

## Scope

- Wrap the `RevenueCat` + `RevenueCatUI` SDKs behind one facade.
- Entitlements as an app-supplied enum (typed, not stringly).
- Feature-gate helpers — check entitlement, gate a view/feature.
- Present the RevenueCat **hosted paywall** (dashboard-configured, remotely updatable, Experiments for A/B). No custom paywall UI — RevenueCat renders it.
- User identity — `logIn` / `logOut`. **Shares one identity with `PASKitAnalytics`** (see below).

## Out of scope

- Custom paywall layouts — the paywall is RevenueCat-hosted by decision.
- Code-level Apple-compliance enforcement — not possible with a hosted paywall (see below).

## Design decisions

- **Paywall = RevenueCat hosted.** There is no separate "paywall" module; paywall presentation lives here. Configured in the RevenueCat dashboard, updatable without an app release.
- **Apple 2026 paywall compliance is a config checklist, not code.** Because the paywall is RC-hosted, PASKit cannot enforce layout. Compliance is a checklist for configuring the RC offering. Source: `decisions-pas.md` 2026-05-19.
- **Unified identity.** `PASKitPurchases.logIn` and `PASKitAnalytics.identify` consume the same app-supplied user ID, so revenue and analytics data join on one key. XueTang does NOT do this — PostHog uses its own UUID, RevenueCat a separate `appUserID`. PASKit fixes it.

## Apple 2026 paywall compliance checklist

- [ ] Billed amount is the visually dominant number (no oversized weekly-equivalent).
- [ ] No stacked-discount paywall; no decline → downsell modal (bannable under 3.1.2c).
- [ ] IAP present alongside any external payment link (external links US-only).

## What needs to be done

- [ ] Facade over `RevenueCat` + `RevenueCatUI`.
- [ ] App-supplied entitlement enum + gating helpers.
- [ ] Hosted-paywall presentation helper.
- [ ] `logIn`/`logOut` wired to the shared `PASKitAnalytics` identity.
