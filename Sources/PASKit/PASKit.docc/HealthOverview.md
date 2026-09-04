# Health Overview

PASKit's HealthKit facade — single store, descriptor-driven authorization, honest write status,
ungated reads. Not part of the `PASKit` umbrella; link the product explicitly.

## Overview

`PASKitHealth` is a thin concrete facade over `HKHealthStore`, extracted from two apps that
independently wrote the same plumbing and independently documented the same trap: HealthKit never
tells you whether a *read* grant was denied, so a read must never be gated on authorization. PASKit
owns the mechanism; each app owns its vocabulary — which types it reads/writes, labels, icons,
units, and any user-facing copy.

**Not re-exported by the `PASKit` umbrella.** Linking HealthKit's authorization API makes App Store
upload validation demand `NSHealthShareUsageDescription` from any binary that references it, even
one with no Health feature — so apps that use Health add the `PASKitHealth` product explicitly:

```swift
.product(name: "PASKitHealth", package: "PASKit")
```

## Configure once at launch

```swift
import PASKitHealth

PASHealth.shared.configure(permissions: [
    .quantity(.bodyMass),
    .quantity(.height, access: .read),
    .characteristic(.dateOfBirth),
    .workouts(),
])
```

`PASHealthPermission` conveniences (`.quantity`, `.characteristic`, `.workouts`) take a HealthKit
identifier; `permissionID` defaults to the identifier's `rawValue`. Labels and icons are your
vocabulary — key your own enum by `id`.

## Authorization — no read status, on purpose

```swift
await PASHealth.shared.requestAuthorization()   // never throws — a failure here is a developer error, logged

switch PASHealth.shared.writeAuthorization {    // observable; write-only, always
case .granted: showConnected()
case .denied: showReconnectPrompt()
case .notDetermined: showConnectButton()
}
```

There is no `isAuthorized`, no `authorizationStatus`, no read counterpart to `writeAuthorization` —
HealthKit gives no honest signal for a denied read, so none is invented. `authorizationRequestStatus()`
tells you whether the system sheet still needs to be shown at all (covers read-only types too).

## Reads — never gated, never throw

```swift
if let weightKg = await PASHealth.shared.latestQuantity(HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo)) {
    show(weightKg)
} else {
    showManualEntryPrompt()   // unavailable, denied, or genuinely no data — rendered identically, by design
}

let sex = PASHealth.shared.biologicalSex()             // nil = unavailable, denied, or unset
let workouts = await PASHealth.shared.samples(.workout(myPredicate), limit: 50)   // generic — no activity vocabulary in PASKit
```

## Writes — the honest, throwing half

```swift
do {
    try await PASHealth.shared.saveQuantity(HKQuantityType(.bodyMass), value: 72.4, unit: .gramUnit(with: .kilo), date: .now)
} catch {
    log.error("save failed: \(error.localizedDescription, privacy: .public)")
}
```

## Escape hatch

```swift
let builder = HKWorkoutBuilder(healthStore: PASHealth.shared.store, configuration: .init(), device: nil)
```

`PASHealth.shared.store` is the app's one `HKHealthStore` — pass it to any HealthKit API this
facade doesn't wrap. Never construct a second store.
