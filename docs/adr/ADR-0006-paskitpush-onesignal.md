# ADR-0006 — `PASKitPush`: OneSignal facade, taps stay with `PASNotifications`, not in the umbrella

**Status:** Accepted — drafted and implemented 2026-10-02.

## Context

`PASKitNotifications` covers local notifications only and listed remote push as future work
("when the first app adopts server-side push"). XueTang is that app, and the studio expects more
of its apps to follow. OneSignal was chosen as the provider over Firebase Cloud Messaging: the
campaign dashboard, segments and journeys come without writing server-side sending code, at the
cost of a new data processor per app.

Three questions had to be settled: where the integration lives, who owns notification taps, and
whether the umbrella re-exports it.

## Decision 1 — a PASKit module, not per-app integrations

The hard part of adding OneSignal is not its API but its coexistence with `PASNotifications`.
`UNUserNotificationCenter` has exactly one delegate, `PASNotifications.configure()` installs it,
and every studio app that schedules local notifications depends on it for foreground presentation
and cold-start-buffered tap routing. Solving that per app means solving it once per app, with
silent failure modes (double-routed or lost taps). Consent gating and the identity join with
`PASPurchases.logIn` / `PASAnalytics.identify` are likewise identical across apps. That is
mechanism, which PASKit owns; tags, payload keys and consent policy stay app vocabulary.

## Decision 2 — `PASNotifications` keeps the delegate; `PASPush` registers no click listener

OneSignal swizzles `UNUserNotificationCenter.setDelegate` and the installed delegate's
`willPresent` / `didReceive`. When a delegate already exists it re-assigns it to trigger the
swizzle; it then forwards **every** response, OneSignal's own included, to that delegate, and lets
it decide foreground presentation options (iOS honours the first completion-handler call).

So `PASNotifications`' bridge keeps both jobs, and `PASPush` deliberately does not register
`OneSignal.Notifications.addClickListener` — doing so would route each OneSignal tap twice. The
one gap is payload shape: OneSignal nests custom data under `custom.a`. `PASKitNotifications`
gained a vendor-neutral seam for that, `PASNotificationPayload.registerUnwrapper(_:)`, which
`PASPush.configure` uses; responses also gained `isRemote`. Apps keep a single
`PASNotifications.onResponse` router for local and remote taps alike.

## Decision 3 — not re-exported by the umbrella

Same reasoning as ADR-0004 and ADR-0005: the product links a vendor SDK, and using it needs the
Push Notifications capability, an APNs key uploaded to OneSignal, an App Group and a Notification
Service Extension target. None of that should be forced on an app without server push. The
OneSignal dependency is iOS-only (`condition: .when(platforms: [.iOS])`); on macOS the module
compiles to its SDK-free payload helper.

## Consequences

- The Notification Service Extension cannot ship in a package. Apps add the target themselves and
  link OneSignal's `OneSignalExtension` product directly — the one sanctioned direct SDK use.
- Deleting the OneSignal user on account deletion is server-side (OneSignal REST API); the SDK
  only detaches the device (`logout()`).
- In-app messaging and location are separate OneSignal products and are not linked. Add them when
  the first app uses them.
