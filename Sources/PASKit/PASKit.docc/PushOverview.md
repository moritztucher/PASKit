# Push Overview

PASKit's OneSignal facade — consent-gated remote push whose taps arrive through the same handler as
local notifications. iOS only. Not part of the `PASKit` umbrella; link the product explicitly.

## Overview

`PASKitPush` is a thin concrete facade over the OneSignal SDK, the same shape ``PASKitPurchases``
has over RevenueCat. PASKit owns the mechanism — consent gating, subscription state, identity, and
coexistence with `PASNotifications`. Each app owns its vocabulary: when consent is given, tag keys,
payload routing keys, and where a tap navigates.

**Not re-exported by the `PASKit` umbrella.** It links the OneSignal SDK, and using it needs the
Push Notifications capability, an App Group and a Notification Service Extension target — so apps
with server push add the product explicitly:

```swift
.product(name: "PASKitPush", package: "PASKit")
```

## One delegate

`PASNotifications` keeps the `UNUserNotificationCenter` delegate. OneSignal wraps whichever delegate
is installed and forwards every response to it, so OneSignal taps reach the app's single
`PASNotifications.onResponse` handler with `isRemote == true` and OneSignal's additional data
flattened into `userInfo`. `PASPush` registers no click listener — one would route each tap twice.

```swift
PASNotifications.shared.configure()
PASPush.shared.configure(.init(appID: AppKeys.oneSignal))   // nothing sent until setConsent(true)

if try await PASNotifications.shared.requestAuthorization() {
    PASPush.shared.setConsent(true)
    PASPush.shared.registerIfAuthorized()
}
PASPush.shared.login(userID: uid)
```

See `docs/PASKitPush.md` for per-app setup and `docs/adr/ADR-0006-paskitpush-onesignal.md` for
the design rationale.
