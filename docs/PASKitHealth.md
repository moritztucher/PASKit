# PASKitHealth

**Status:** Built — extracted from two production apps.
**Dependencies:** `PASKitCore` (for `PASLogger`). `HealthKit` is a system framework — no vendor SDK.
**Platforms:** iOS 18+, macOS 15+. HealthKit's authorization/read/write API is available on macOS
13+, so the package's macOS 15 floor is not a constraint; `isAvailable` is simply always `false` on
a plain macOS host with no Health data. **Not part of the `PASKit` umbrella** — see
[ADR-0004](adr/ADR-0004-paskithealth-umbrella-exclusion.md).

## Purpose

A thin, concrete facade over `HKHealthStore`, extracted from two apps (WorkoutApp's
`HealthManager` + `HealthManager+Reading` + `HealthKitPermissionDescriptor`, 463 lines; CoupleCalorieTracker's
`HealthProfileReader`, 77 lines) that independently wrote the same plumbing — the same
availability check, the same descriptor-driven `requestAuthorization(toShare:read:)`, the same
latest-sample query — and, more tellingly, independently documented the same non-obvious HealthKit
trap in their own words: **a denied read grant is indistinguishable from no data, so reads must
never be gated on authorization.** PASKit owns the mechanism (single store, descriptor-driven
authorization, honest write status, foreground refresh); each app owns its vocabulary (which types
it reads/writes, labels, icons, units, and any user-facing copy).

## Layout

```
Sources/PASKitHealth/
├── PASHealth.swift                    facade: store, availability, configure, authorization, foreground refresh
├── PASHealth+Reading.swift            latestQuantitySample / latestQuantity / samples / biologicalSex / dateOfBirthComponents / excludingOwnSamples
├── PASHealth+Writing.swift            save / saveQuantity
├── PASHealthPermission.swift          descriptor + .quantity/.characteristic/.workouts conveniences
├── PASHealthWriteAuthorization.swift  enum + derive(from:isAvailable:)
└── README.md
```

Flat module (like `PASKitNotifications`/`PASKitSharing`) — no topic subfolders.

## The read-authorization contract

HealthKit never reports whether a *read* grant was denied — a denied read and "no data exists"
look identical, by design, to protect user privacy. Both source apps warned about this in their own
header comments; this module encodes the rule rather than merely documenting it, so it is hard to
violate by accident:

- **No `isAuthorized`, no `authorizationStatus`, no `connectionState` exists.** The only state is
  `writeAuthorization` (aggregate) and `writeAuthorization(for:)` (per type) — both named with the
  word "write" so nothing with a neutral name is there for autocomplete to offer as a read gate.
- **Per-type status is `HKAuthorizationStatus?`, `nil` for a read-only permission.** An app that
  tries to gate a read on it gets `nil` and cannot proceed without noticing, instead of a
  `.notDetermined` that looks like a real answer.
- **Every read returns an optional or an array and takes no authorization parameter, and none
  throw.** `nil` / `[]` is one state — "unavailable, denied, or genuinely empty" — not three, and
  the caller cannot and must not try to distinguish them. Reads are unavailable-guarded internally,
  so callers need no guard of their own before calling one.
- **The one honest pre-prompt signal HealthKit does give** —
  `HKAuthorizationRequestStatus` from `statusForAuthorizationRequest(toShare:read:)`, which also
  covers read-only types — is exposed as `authorizationRequestStatus()`, so there is no reason to
  invent a read-status proxy.
- **Writes are the asymmetric counterpart: they may be gated on `writeAuthorization` (it is
  truthful) and they do throw** — `HKError.errorAuthorizationDenied` and friends are HealthKit
  reporting a write failure honestly, unlike a read.
- The pure derivation, `PASHealthWriteAuthorization.derive(from:isAvailable:)`, is unit-tested,
  including "no configured write types → `.notDetermined`" — so a read-only app can never observe
  `.granted` and mistake it for read access.

What this does **not** do: stop an app from writing `if writeAuthorization == .granted { await
read() }` — the compiler cannot forbid that. The naming, the `nil`s, and this contract make it
self-evidently wrong when read.

## Surface

| API | Purpose |
|---|---|
| `PASHealth.shared.configure(permissions:)` | Declare every HealthKit type the app will ever request. Once, at launch. Idempotent. |
| `store` | The app's single `HKHealthStore` — escape hatch for anything unwrapped (`HKWorkoutBuilder`, statistics/observer queries). Never create a second store. |
| `isAvailable` | `HKHealthStore.isHealthDataAvailable()`. Every read/write already guards on this internally. |
| `requestAuthorization()` | Presents the system sheet. **Never throws** — a failure is a developer error (unavailable device, missing entitlement), logged via `PASLogger`; the only actionable output is the refreshed `writeAuthorization`. |
| `authorizationRequestStatus()` | `HKAuthorizationRequestStatus` — whether the system sheet still needs to be shown, for the configured set including read-only types. |
| `writeAuthorization` (observable) / `writeAuthorization(for:)` | Aggregate / per-type write status. See the read-authorization contract above — there is no read equivalent. |
| `refreshWriteAuthorization()` | Manual re-derive; called automatically after `configure`, after `requestAuthorization`, and on iOS foreground return. |
| `latestQuantitySample(_:includeOwnSamples:)` / `latestQuantity(_:unit:includeOwnSamples:)` | Latest sample/value by `endDate`, own-source-excluded by default. |
| `samples(_:sortDescriptors:limit:)` | Generic list read over a typed `HKSamplePredicate<S>` — PASKit holds no activity-type or other domain vocabulary, so callers compose their own predicate. |
| `biologicalSex()` / `dateOfBirthComponents()` | Characteristic reads; `.notSet` collapses to `nil`. |
| `excludingOwnSamples` | `NSPredicate` to compose into a caller's own predicate. |
| `save(_:)` / `saveQuantity(_:value:unit:date:metadata:)` | Writes — may throw. `saveQuantity` builds a point sample (`start == end == date`); build an `HKQuantitySample` and call `save(_:)` for an interval sample. |
| `PASHealthPermission` + `.quantity`/`.characteristic`/`.workouts` | Descriptor + conveniences. `permissionID` defaults to the HealthKit identifier's `rawValue`. |
| `PASHealthWriteAuthorization` | `.notDetermined` / `.granted` / `.denied`, derived over configured *write* types only. |

## Design decisions

- **Own-source exclusion defaults on** (`includeOwnSamples: Bool = false`). WorkoutApp had to learn
  this the hard way — its own writes echoed back as "imports" without it. A no-op for CoupleCalorieTracker,
  which never writes.
- **Reads never (re-)request authorization.** CoupleCalorieTracker's original code re-requested on every
  read, relying on the system not re-prompting once decided. This module makes `requestAuthorization()`
  an explicit call — permission timing is app policy, the same convention `PASKitNotifications` uses.
- **`requestAuthorization()` is non-throwing.** Both source apps logged and swallowed the request
  error; it is a developer error (unavailable device, missing entitlement), never a user decision,
  and the only actionable signal is the refreshed `writeAuthorization`. This is a deliberate
  departure from `PASNotifications.requestAuthorization`, which throws — consistency across facades
  lost out to not inviting the catch-block-denial-UI mistake this module exists to prevent.
- **`@MainActor @Observable final class` singleton**, matching `PASNotifications`/`PASPurchases` and
  HealthKit's own single-store rule. Both source apps read state synchronously inside SwiftUI view
  bodies and both consuming projects build with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so
  isolation costs nothing at the two known call sites.
- **Foreground refresh lives inside the facade** (iOS, `UIApplication.willEnterForegroundNotification`),
  replacing three duplicated `onChange(of: scenePhase)` blocks in WorkoutApp alone.
- **Deliberately excluded from the `PASKit` umbrella** — see [ADR-0004](adr/ADR-0004-paskithealth-umbrella-exclusion.md).
  Statically linking HealthKit's authorization API makes App Store upload validation demand
  `NSHealthShareUsageDescription` from any consumer that links it, even one with no Health feature.

## Out of scope (v1)

- `HKWorkoutBuilder` / `saveWorkout` — one app, and activity type/location/"what a workout is" are
  app vocabulary. Build it against `PASHealth.shared.store`.
- Observer queries, background delivery, statistics queries (`HKStatisticsQueryDescriptor`),
  anchored queries/change tracking, deletes, category samples, correlations, clinical records,
  workout routes, watchOS. Neither source app uses any of these — add when the first app needs one.
- Unit conversions (body-fat fraction ↔ percent, cm/kg) — vocabulary; units are passed in at the
  call site.
- Any user-facing string, and the permission tri-state + Open-Settings deep link (that is a
  separate, cross-framework action-plan item in `PASKitCore/Permissions`).

## Tests

`Tests/PASKitHealthTests/` (Swift Testing) covers the pure logic that needs neither `HKHealthStore`
nor an app bundle: `PASHealthWriteAuthorization.derive(from:isAvailable:)`'s six rules, and
`PASHealthPermission`'s identity/equality, the `.quantity`/`.characteristic`/`.workouts`
conveniences, and the read/write type-set de-duplication `requestAuthorization` relies on.
Constructing `HKQuantityType`/`HKCharacteristicType` needs no store or entitlement and runs on the
bundle-less macOS CI host. `PASHealth.shared` is never referenced from a test — constructing the
singleton constructs a live `HKHealthStore`. Everything that touches `HKHealthStore` directly
(`isAvailable`, `requestAuthorization`, `authorizationRequestStatus`, every read/write, foreground
refresh, `excludingOwnSamples` via `HKSource.default()`) is exercised by the two consuming apps
once they adopt, not invented here; compile coverage for the iOS surface comes from the
`PASKitHealth` entry in the `ios-simulator-build` CI matrix.

## Future work

- [ ] `HKWorkoutBuilder` wrapper — when a second app needs to write workouts.
- [ ] Observer queries / background delivery — when the first app needs live updates without
  polling.
- [ ] Statistics queries — when the first app needs aggregation rather than raw samples.
