# PASKitNotifications

> **Status: Shipped (v0.2.0-dev).** Built when XueTang V2 became the first consuming app to need local notifications (streak-protection reminders, per its D-16/D-17 decisions).

**Dependencies:** `PASKitCore` only. `UserNotifications` is a system framework — no third-party SDK. iOS + macOS (the automatic foreground authorization refresh is iOS-only; macOS callers refresh manually).

## Purpose

A thin, concrete wrapper over `UNUserNotificationCenter` for **local** notifications — delegate plumbing, observable authorization state, schedule/cancel primitives, and tap routing. The raw API is already modern async/await; the module earns its place with the three things a pass-through doesn't give you:

1. **Delegate ownership + tap routing.** `UNUserNotificationCenter` allows exactly one delegate, installed at launch — the same "configured once, consumed everywhere" shape as `PASPurchases`. Cold-start taps (the app was launched by tapping a notification) are buffered until the app registers its `onResponse` handler.
2. **Observable authorization state.** `authorizationStatus` is `@Observable` and auto-refreshed on foreground return (iOS), so SwiftUI permission UI reacts without polling.
3. **Sendable value types.** `PASNotificationRequest` / `PASNotificationResponse` instead of `UNMutableNotificationContent` / `UNNotificationResponse` at app call sites — testable, Swift 6-clean.

PASKit owns the mechanism; each app owns its vocabulary: when to schedule, the copy, the identifiers, and where a tap navigates.

## Surface

| API | Purpose |
|---|---|
| `PASNotifications.shared.configure(PASNotificationsConfig)` | One-time delegate install at launch (foreground presentation options). Idempotent. Starts authorization tracking. |
| `authorizationStatus` / `isAuthorized` | Observable `UNAuthorizationStatus`, refreshed on configure, after the permission request, on iOS foreground return, and via `refreshAuthorizationStatus()`. |
| `onResponse(_:)` | Registers the tap router (`PASNotificationResponse` → app navigation). Delivers a buffered cold-start response immediately on registration. |
| `requestAuthorization(options:)` | Permission prompt primitive. Timing is app policy — ask at an earned moment. |
| `schedule(_ request:)` | Schedule a `PASNotificationRequest`. Re-using an `id` replaces the pending request — idempotent by design. |
| `fireTest(_ request:after:)` | Fire a notification's content now (≥1s), under a `test.<id>` identifier so it never replaces the real pending instance — the "test this notification" button apps wire into their DEBUG dev menu. |
| `cancel(ids:)` / `cancelAll()` / `pendingIDs()` | Pending-request management. |
| `setBadgeCount(_:)` | App-icon badge; `0` clears. |
| `PASNotificationTrigger` | `.interval(_:repeats:)`, `.calendar(_:repeats:)` (e.g. `DateComponents(hour: 20)` for 8pm local), `.at(Date)` one-shot sugar, `.dailyAt(hour:minute:)` / `.dailyAt(_ date:)` daily-reminder sugar (repeating calendar at a wall-clock time; the `Date` overload extracts hour/minute from the user's picked time). |

## Out of scope

- **When/what to send** — scheduling policy ("8pm if not opened today, cancel on open"), copy, and journey logic are app domain. The module ships primitives only.
- **Remote push** — APNs registration, FCM, OneSignal. A per-app decision (XueTang defers it to R5 per its D-16). The delegate already routes taps on remote notifications, so a provider can be added later without changing this surface.
- **Notification categories / custom actions** — `PASNotificationResponse.actionID` already carries custom action identifiers, but category registration lands when the first app ships action buttons.
- **Time-sensitive / critical interruption levels** — require entitlements; added when the first app carries one.

## Design decisions

- **No configure-gating on scheduling.** Unlike `PASPurchases` (the RevenueCat SDK is unusable unconfigured), `UNUserNotificationCenter` works without a delegate — so `schedule`/`cancel`/`requestAuthorization` don't throw when `configure` hasn't run. `configure` only governs foreground presentation and tap routing.
- **Cold-start buffering.** The delegate fires the tap response before SwiftUI builds the view that owns navigation. `deliver` stashes the response when no handler is registered and flushes it when `onResponse` runs — without this, launch-by-tap drops the deep link.
- **String-to-string `userInfo`.** The routing payload is `[String: String]` by design — small routing keys, not state. Non-string values on remote payloads are dropped at extraction.
- **Stable identifiers as the contract.** Apps schedule with vocabulary ids (`"streak-protection"`); replace-on-reschedule + `cancel(ids:)` make scheduling idempotent, which is what calendar-shaped logic (streaks, daily reminders) needs.
- **UserNotifications types pass through where natural.** `UNAuthorizationStatus`, `UNAuthorizationOptions`, `UNNotificationPresentationOptions` are not re-wrapped — this is a convenience wrapper, not a vendor abstraction (there is no vendor).

## Future work

- [ ] Notification categories + action buttons — when the first app ships them.
- [ ] Remote-push registration hook (APNs token surface) — when the first app adopts server-side push (XueTang R5 candidate, per its D-16).
- [ ] Time-sensitive interruption level — when the first app carries the entitlement.
