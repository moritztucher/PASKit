# Notifications Overview

PASKit's local-notification facade — delegate plumbing, observable authorization, and tap routing. The app owns policy and copy.

## Overview

`PASKitNotifications` is a thin concrete facade over `UNUserNotificationCenter`. PASKit owns the mechanism (delegate plumbing, observable authorization state, schedule/cancel primitives, tap routing); each app owns its vocabulary (when to schedule, the copy, the identifiers, and where a tap navigates).

## Configure once at launch

```swift
import PASKitNotifications

PASNotifications.shared.configure()   // installs the delegate — call before a cold-start tap can arrive
```

`configure` installs the notification-center delegate for foreground presentation and tap routing. Scheduling and authorization work without it; only presentation and tap routing need the delegate.

## Authorization

```swift
let granted = try await PASNotifications.shared.requestAuthorization()
// drive permission UI from the observable authorizationStatus / isAuthorized
```

Ask at an earned moment — after the first delight, never at first launch. `authorizationStatus` refreshes on configure, after a request, and on every foreground return.

## Schedule & cancel

```swift
try await PASNotifications.shared.schedule(
    PASNotificationRequest(id: "streak.reminder", title: "Keep your streak", body: "…", trigger: .dailyAt(hour: 20, minute: 0))
)
PASNotifications.shared.cancel(ids: ["streak.reminder"])
```

Re-using an `id` replaces that pending request, so schedule idempotently. `fireTest(_:)` fires a request's content almost immediately under a `test.<id>` identifier — the "test this notification now" button for a DEBUG dev menu.

`sound` takes a `PASNotificationSound` — `.default` (the system sound, the default), `.silent`, or `.named("file.wav")` for a bundled clip ≤ 30s in the app's main bundle. Bool literals (`sound: true` / `sound: false`) still compile.

## Route taps

```swift
PASNotifications.shared.onResponse { response in
    // map response.userInfo to the app's own navigation
}
```

A tap that cold-started the app is buffered and delivered as soon as the handler registers, so no deep link is lost to launch timing.
