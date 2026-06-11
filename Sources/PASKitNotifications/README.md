# PASKitNotifications

Thin facade over `UNUserNotificationCenter`. PASKit owns the mechanism (delegate plumbing, observable authorization state, schedule/cancel primitives, tap routing with cold-start buffering); apps own their vocabulary — when to schedule, the copy, notification identifiers, and where a tap navigates. UserNotifications types (`UNAuthorizationStatus`, `UNAuthorizationOptions`, `UNNotificationPresentationOptions`) pass through where they are the natural currency.

## API

- `PASNotifications` — `@MainActor @Observable` singleton (`PASNotifications.shared`). Observable `authorizationStatus` (+ `isAuthorized`), `configure` installs the notification-center delegate, `onResponse` registers the tap router, `requestAuthorization` / `schedule` / `cancel` / `cancelAll` / `pendingIDs` / `setBadgeCount`.
- `PASNotificationsConfig` — config struct passed to `configure` (`foregroundPresentation` options; default `[.banner, .sound]`).
- `PASNotificationRequest` — Sendable description of a local notification (`id`, `title`, `body`, `subtitle`, `sound`, `badge`, `userInfo` routing payload, `trigger`).
- `PASNotificationTrigger` — `.interval(_:repeats:)`, `.calendar(_:repeats:)`, `.at(Date)`.
- `PASNotificationResponse` — what `onResponse` receives (`notificationID`, `actionID`, `userInfo`, `isDefaultTap`).

## Example

```swift
import PASKitNotifications

// At launch (installs the delegate — before a cold-start tap can arrive):
PASNotifications.shared.configure()

// Where navigation lives (cold-start taps are buffered until this runs):
PASNotifications.shared.onResponse { response in
    router.handle(destination: response.userInfo["destination"])
}

// At the app's earned moment — never at first launch:
let granted = try await PASNotifications.shared.requestAuthorization()

// Schedule — re-using an id replaces the pending request (idempotent):
try await PASNotifications.shared.schedule(PASNotificationRequest(
    id: "streak-protection",
    title: "Your streak ends at midnight",
    body: "4 hours left — one quick lesson keeps it alive.",
    userInfo: ["destination": "path"],
    trigger: .calendar(DateComponents(hour: 20), repeats: false)
))

// Cancel when the condition clears (e.g. the user opened the app):
PASNotifications.shared.cancel(ids: ["streak-protection"])
```

`configure` is idempotent — a second call logs a warning and no-ops. Scheduling and authorization work without `configure`; only foreground presentation and tap routing need the delegate installed.

## Notes

- **Permission timing is app policy.** The module ships the primitive; ask at an earned moment (after the first delight), never at first launch.
- **Authorization state**: observe `authorizationStatus` — refreshed on configure, after the request, and on every foreground return (iOS). Never cache a boolean.
- **Identifiers are the contract**: stable, app-vocabulary ids (`"streak-protection"`), not UUIDs — scheduling the same id replaces, `cancel(ids:)` addresses it.
- **Remote push is out of scope** — server-side push (FCM/OneSignal) is a separate decision per app. The delegate already routes taps on remote notifications too, so a provider can slot in without changing this surface.
