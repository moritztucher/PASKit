# PASKitPush

OneSignal facade — remote push, consent-gated, identity joined with purchases and analytics.

Full documentation: [docs/PASKitPush.md](../../docs/PASKitPush.md).
Design rationale: [ADR-0006](../../docs/adr/ADR-0006-paskitpush-onesignal.md).

**Not part of the `PASKit` umbrella.** Add the product explicitly. iOS only.

## API

`PASPush.shared` — `configure(_:)`, `setConsent(_:)`, `registerIfAuthorized()`, `optIn()` /
`optOut()`, `login(userID:)` / `logout()`, `addTags(_:)` / `removeTags(_:)`. Observable
`isConfigured` / `hasConsent` / `isOptedIn` / `subscriptionID` / `userID`.

Taps are not handled here: they arrive through `PASNotifications.shared.onResponse`, with
OneSignal's additional data flattened into `userInfo` and `isRemote == true`.
