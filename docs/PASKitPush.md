# PASKitPush

Remote push through OneSignal. A thin concrete facade, the same shape as `PASPurchases` over
RevenueCat. **Not in the `PASKit` umbrella** and **iOS only** — see
[ADR-0006](adr/ADR-0006-paskitpush-onesignal.md).

PASKit owns the mechanism: consent gating, subscription state, identity, coexistence with
`PASNotifications`. The app owns its vocabulary: when consent is given, tag keys, payload routing
keys, and where a tap navigates.

## Setup (per app)

1. **OneSignal dashboard** — one OneSignal app per bundle ID (production and staging). Upload an
   APNs auth key (`.p8`).
2. **Xcode, app target** — link the `PASKitPush` product; add the *Push Notifications* capability
   (`aps-environment`), *Background Modes → Remote notifications*, and an *App Group*
   (`group.<bundle-id>.onesignal`).
3. **Notification Service Extension** — File → New → Target → Notification Service Extension,
   named `OneSignalNotificationServiceExtension`; same App Group; link OneSignal's
   `OneSignalExtension` product (from `https://github.com/OneSignal/OneSignal-XCFramework`). It
   powers images, badges and confirmed delivery. Its `NotificationService` is OneSignal's stock
   template; this is the only sanctioned direct OneSignal use.

## Launch

```swift
import PASKitNotifications
import PASKitPush

PASNotifications.shared.configure()                       // first — owns the delegate
PASPush.shared.configure(.init(appID: AppKeys.oneSignal)) // requiresConsent defaults to true
PASNotifications.shared.onResponse { response in          // local AND OneSignal taps
    router.handle(destination: response.userInfo["destination"])
}
```

## Consent, permission, registration

The permission prompt stays with `PASNotifications`; `PASPush` never shows it.

```swift
let granted = try await PASNotifications.shared.requestAuthorization()
if granted {
    PASPush.shared.setConsent(true)       // app policy — here, permission doubles as consent
    PASPush.shared.registerIfAuthorized() // hands the APNs token to OneSignal, no prompt
}
```

Call `registerIfAuthorized()` again at launch and on foreground return; it is a no-op without
consent or permission. `optOut()` / `optIn()` back an in-app push switch without touching the OS
permission.

## Identity

```swift
PASPush.shared.login(userID: uid)   // same id as PASPurchases.logIn / PASAnalytics.identify
PASPush.shared.logout()             // sign-out and account deletion
```

`logout()` only detaches the device. Delete the OneSignal user server-side (REST API) when the
app deletes an account — e.g. from the `PASAuthDelegate.willDeleteAccount` path.

## Payloads

Put routing keys in the OneSignal message's *additional data* (`{"destination": "path"}`). The
module registers a `PASNotificationPayload` unwrapper, so they arrive flattened in
`PASNotificationResponse.userInfo`, with `isRemote == true`. String values only.

## Design decisions

- **One delegate.** OneSignal wraps the delegate `PASNotifications` installs and forwards every
  response to it; registering OneSignal's click listener as well would route each tap twice.
- **Consent first.** `requiresConsent` defaults to `true`: nothing leaves the device until
  `setConsent(true)`.
- **Off-main observer.** OneSignal's subscription observer extracts Sendable values and hops to the
  main actor before touching observable state.

## Future work

- [ ] In-app messaging (`OneSignalInAppMessages`) — when the first app uses it.
- [ ] Live Activity push tokens — when the first app ships a Live Activity.
