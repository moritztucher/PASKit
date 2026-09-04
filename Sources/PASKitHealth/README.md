# PASKitHealth

Thin facade over `HKHealthStore`. **Writes may gate on authorization and may catch — reads may
not, and never can.** HealthKit gives no honest read-authorization signal (a denied read looks
identical to no data), so this module ships no read status at all: no `isAuthorized`, no
`authorizationStatus`, no `connectionState`. The only status is `writeAuthorization` (aggregate)
and `writeAuthorization(for:)` (per type) — both named with the word "write" so nothing with a
neutral name is there to be grabbed by autocomplete and used to gate a read by mistake.

Not part of the `PASKit` umbrella — see `docs/adr/ADR-0004-paskithealth-umbrella-exclusion.md`.
Apps that use Health add the `PASKitHealth` product explicitly.

## API

- `PASHealth` — `@MainActor @Observable` singleton (`PASHealth.shared`). `store` (the app's single `HKHealthStore` — escape hatch for anything unwrapped, e.g. `HKWorkoutBuilder`), `isAvailable`, `configure(permissions:)`, `requestAuthorization()` (never throws — a failure here is a developer error, logged), `authorizationRequestStatus()` (`HKAuthorizationRequestStatus` — the one honest pre-prompt signal, covers read-only types too), observable `writeAuthorization` (`PASHealthWriteAuthorization`), `writeAuthorization(for:)` (`HKAuthorizationStatus?`, `nil` for a read-only permission or an unavailable device), `refreshWriteAuthorization()`.
- Reads (never gated, never throw — `nil`/`[]` means "unavailable, denied, or empty"): `latestQuantitySample(_:includeOwnSamples:)`, `latestQuantity(_:unit:includeOwnSamples:)`, `samples(_:sortDescriptors:limit:)` (generic over `HKSamplePredicate<S>` — PASKit holds no activity-type or other domain vocabulary), `biologicalSex()`, `dateOfBirthComponents()`, `excludingOwnSamples` (`NSPredicate` to compose into your own predicates).
- Writes (may throw — HealthKit reports write failures truthfully): `save(_:)`, `saveQuantity(_:value:unit:date:metadata:)` (builds a point sample; use `save(_:)` directly for an interval sample).
- `PASHealthPermission` — descriptor (`id`, `readType: HKObjectType?`, `writeType: HKSampleType?`); conveniences `.quantity(_:permissionID:access:)`, `.characteristic(_:permissionID:)`, `.workouts(permissionID:access:)`. Labels/icons are your vocabulary — key your own enum by `id`.
- `PASHealthAccess` — `.read` / `.write` / `.readWrite`, passed to the `PASHealthPermission` conveniences.
- `PASHealthWriteAuthorization` — `.notDetermined` / `.granted` / `.denied`, derived over every configured *write* type only.

## Example

```swift
import PASKitHealth

// At launch — declare every type you'll ever request:
PASHealth.shared.configure(permissions: [
    .quantity(.bodyMass),
    .quantity(.height, access: .read),
    .characteristic(.dateOfBirth),
    .workouts(),
])

// Presents the system sheet (write + read together):
await PASHealth.shared.requestAuthorization()

// Drive UI off the one honest signal — write status:
switch PASHealth.shared.writeAuthorization {
case .granted: showConnectedBadge()
case .denied: showReconnectPrompt()
case .notDetermined: showConnectButton()
}

// Reads are never gated — call them directly, render nil/[] as "no data":
if let weightKg = await PASHealth.shared.latestQuantity(HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo)) {
    show(weightKg)
} else {
    showManualEntryPrompt()   // could be unavailable, denied, or genuinely no data — treat them the same
}

// Writes may throw — HealthKit tells the truth here:
do {
    try await PASHealth.shared.saveQuantity(HKQuantityType(.bodyMass), value: 72.4, unit: .gramUnit(with: .kilo), date: .now)
} catch {
    log.error("save failed: \(error.localizedDescription, privacy: .public)")
}
```

## Notes

- **Own-source exclusion defaults on.** `includeOwnSamples: Bool = false` on both `latestQuantitySample` and `latestQuantity` — an app that also writes the type it reads would otherwise see its own writes echoed back as "imports". A no-op for a read-only app.
- **One store, ever.** `PASHealth.shared.store` is the only `HKHealthStore` your app should construct — HealthKit expects exactly one per process. Pass it to any HealthKit API this facade doesn't wrap.
- **Foreground refresh is automatic (iOS).** `writeAuthorization` re-derives on `UIApplication.willEnterForegroundNotification` once `configure` has run — no `scenePhase` boilerplate needed at call sites.
- **Not in the `PASKit` umbrella, deliberately.** Statically linking HealthKit's authorization API makes App Store upload validation demand `NSHealthShareUsageDescription` from every consumer that links it — including apps with no Health feature. Add the `PASKitHealth` product to your target explicitly.
- **Out of scope in v1:** `HKWorkoutBuilder` (activity type / location is your vocabulary — build it against `PASHealth.shared.store`), observer queries / background delivery, statistics queries, anchored queries, deletes, category samples/correlations/clinical records/routes, unit conversions, and any user-facing string. Added when the first app needs them.
