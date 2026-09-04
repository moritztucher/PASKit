# CoupleCalorieTracker → PASKit extraction audit

**Date:** 2026-09-04 · **PASKit:** v0.3.1 (`develop` @ `95cef5a`) · **App:** CoupleCalorieTracker, branch `main` @ `b50fd6a` · **Cross-checked against:** WorkoutApp (`develop`), XueTang V2 (`develop-xt2-revamp`)

## Summary

CoupleCalorieTracker is a young, tightly-scoped app and most of what it owns is genuinely its own vocabulary — nutrition maths, Open Food Facts plumbing, and a Core Data stack chosen for a constraint (CloudKit *shared* database) the other two studio apps do not have. The extraction candidates that survive a second-app test are small and infrastructural rather than headline features: a HealthKit facade that WorkoutApp independently rebuilt at four times the size, a normalised permission-state + settings-deep-link helper that all three apps hand-roll differently, a lenient numeric decode/parse kit, and a string-catalog sync script that only this app has but all three need. The most library-shaped code in the repo — the barcode scanner and camera plumbing — is honestly single-app: neither WorkoutApp nor XueTang contains a single line of `AVCaptureDevice` or `VisionKit`, so per *build on real need* it stays put. The larger finding sits outside the extraction question: this app (and WorkoutApp, and XueTang) hand-rolls several things PASKit v0.3.1 already ships — the onboarding engine, the progress ring, the pressable button style, the dev menu, and `PASLogger`. That section is below the candidates, because adopting what exists is worth more to the studio than any single extraction on this list.

| # | Candidate | Proposed PASKit module | Second-app evidence | Effort | Recommendation |
|---|-----------|------------------------|---------------------|--------|----------------|
| 1 | HealthKit facade (availability, descriptor-driven auth, latest-sample read) | new `PASKitHealth` | **Strong** — WorkoutApp `Core/Services/HealthManager.swift` + `HealthManager+Reading.swift` + `HealthKitPermissionDescriptor.swift` (463 lines, independent) | M | **Extract now** |
| 2 | Permission tri-state + "Open Settings" deep link | `PASKitCore/Permissions` | **Strong** — WorkoutApp `OnboardingViewModel.swift:292-330`; XueTang `ReminderService.swift:77` | S | **Extract now** |
| 3 | Linear capsule progress bar (`MacroBar`) | `PASKitLifecycle/Indicators` — promote the existing `PASOnboardingProgressBar` | **Strong** — 6 hand-rolled copies across 3 apps | S | **Extract now** (rename/promote, not new code) |
| 4 | Lenient numeric decoding + user-input parsing (`FlexibleDouble`, `AnyCodingKey`) | `PASKitCore/Networking` | **Medium** — WorkoutApp `Double+UserInput.swift:8`, `ChartPreferences.swift:70` | S | **Extract now** (scoped) |
| 5 | String-catalog sync script (`Scripts/sync-strings.sh`) | *not a module* — `CLAUDE-INTEGRATION.md` snippet / `moritztucher/ios-ci` | **Strong need, zero supply** — WorkoutApp (742 keys) and XueTang (760 keys) have no sync tooling at all | S | **Extract now** (as tooling, not Swift) |
| 6 | `Color(hex:)` initializer | `PASKitCore/Styling` | **None** — no hex init in either other app | S | Extract when a second app needs it |
| 7 | Initial-letter avatar (`AvatarChip`) | `PASKitCore/Styling` (the string helper only) | **Weak** — XueTang has two divergent copies needing CJK glyph fallback; WorkoutApp has none | S | Extract when a second app needs it |
| 8 | Trailing-aligned form rows (`LabeledNumberRow` / `LabeledTextRow`) | `PASKitLifecycle/Settings` | **None** — no `LabeledContent` twin in either app | S | Extract when a second app needs it |
| 9 | Barcode + camera plumbing (`CameraAccess`, `BarcodeScannerView`) | would be `PASKitScanning` | **None** — zero `AVCaptureDevice` / `VisionKit` in either app | M | Extract when a second app needs it |

---

## Candidates

### 1. HealthKit facade

**What it is.** `CoupleCalorieTracker/Health/HealthProfileReader.swift` — `HealthProfileData` (:4), `ProfileHealthReading` (:16), `HealthProfileReader` (:26) with `isAvailable` (:36), `readProfile()` (:40), `readSex()` (:53), `readBirthDate()` (:62), `readLatestQuantity(type:unit:)` (:67). One shared `HKHealthStore` (:27), a static read-type set (:29-34), a single `requestAuthorization(toShare:read:)` (:43), and per-read silent degradation because — as the header comment at :21-24 states — a denied HealthKit *read* grant is indistinguishable from "no data".

**Why it is mechanism, not vocabulary.** Everything in that file except the four type identifiers is plumbing every HealthKit-touching app must rewrite: the single-store rule, `isHealthDataAvailable()`, the authorization call built from a declared type set, and `HKSampleQueryDescriptor` + `SortDescriptor(\.endDate, .reverse)` + `limit: 1` to get "the latest value". The app-specific part is *which* types, *which* units, and what a `Sex` maps to. This is the same shape PASKit already accepted for `UNUserNotificationCenter` in `PASKitNotifications`: one system framework, one thin concrete facade, app owns the identifiers and the policy.

**Proposed home.** A new `PASKitHealth` module (`Sources/PASKitHealth/`), not a folder in `PASKitCore` — HealthKit is a linked framework with entitlement and usage-string requirements, and `PASKitCore` is imported by every module including ones that must never pull it in. Same reasoning that gave `PASKitNotifications` its own target. Scope it tightly to the intersection the two apps actually share: `PASHealth.shared.isAvailable`, `requestAuthorization(descriptors:)`, an `@Observable` authorization summary, `latestQuantity(_:unit:)`, `save(_:unit:date:)`, and a `PASHealthPermissionDescriptor` (`id` / `readType` / `writeType`) — plus the "read grants are unqueryable on iOS" caveat encoded once, in documentation, instead of rediscovered per app. Do **not** hoist workout building or body-composition maths.

**What the app would inject.** The `HKObjectType` / `HKQuantityType` set, the units (`.meterUnit(with: .centi)`, `.gramUnit(with: .kilo)`), the `Sex` mapping, and the "onboarding pre-fill only where the field is still empty" policy currently at `ViewModels/OnboardingViewModel.swift:95-117` — all of which are this app's vocabulary and stay put.

**Second-app evidence.** WorkoutApp built the same facade independently and much further:
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Services/HealthManager.swift:7` — `@Observable @MainActor final class HealthManager`, one shared `HKHealthStore` (:19), `isAvailable` (:25), `refreshConnectionState()` (:35-71), `requestAuthorization()` (:141), writes at :156-284.
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Services/HealthKitPermissionDescriptor.swift:6` — `id` / `displayName` / `icon` / `writeType` / `readType`; the descriptor table at `HealthManager.swift:87-130` drives both the authorization request and the per-type status screen.
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Services/HealthManager+Reading.swift:105` — `latestSample(_:)`, the same descriptor-limit-1 read CCT wrote at `HealthProfileReader.swift:67`.
- Both files independently document the same iOS trap: CCT at `HealthProfileReader.swift:21-24`, WorkoutApp at `HealthManager.swift:33-34`.

XueTang has no HealthKit at all (zero hits for `HKHealthStore` across the repo), so this is two of three apps, not three.

**Effort.** M — a new target, product, DocC entry, spec doc and README, but roughly 150 lines of actual mechanism.

**Recommendation. Extract now.** Two shipped apps wrote it twice, and the duplicated part includes a platform gotcha that costs a debugging session each time it is rediscovered.

**Linkage consequence.** CoupleCalorieTracker deliberately links only the `PASKitLifecycle` product to avoid RevenueCat and PostHog (`CLAUDE.md`, "Currently linked"). `PASKitHealth` would depend on `PASKitCore` and HealthKit only — no vendor SDK — so adding it as a second `XCSwiftPackageProductDependency` keeps that guarantee intact. It must be added as a per-module product, never by switching to the `PASKit` umbrella.

---

### 2. Permission tri-state + system-settings deep link

**What it is.** `CoupleCalorieTracker/Scanner/CameraAccess.swift:3` — `enum CameraAccess` with a normalised `Status { granted, denied, notDetermined }` (:4-8) that folds `.restricted` into `.denied` (:16-17), `status` (:10), `request()` (:23). Its consumer at `ViewModels/ScanViewModel.swift:51-63` switches on that tri-state to decide between scanning, requesting, and showing an unavailable screen; the screen's escape hatch is `Views/ScanScreen.swift:263-266` (`UIApplication.openSettingsURLString`).

**Why it is mechanism, not vocabulary.** Every iOS permission API reports a different enum with a different set of edge cases (`.restricted`, `.provisional`, `.ephemeral`) and every app immediately flattens it to the same three states, because three is what a UI can render. The flattening rule and the "denied → send them to Settings" escape hatch are identical everywhere; only the *copy* and the *card design* differ. There is no app vocabulary in `Status`, in the `.restricted → .denied` fold, or in the deep link.

**Proposed home.** `PASKitCore/Permissions/` — `PASPermissionState` (`.notDetermined` / `.granted` / `.denied`) plus `PASSystemSettings.openAppSettings()`. It belongs in Core rather than Lifecycle because it is a value type plus one URL open, with no UI and no framework linkage: the app maps its own `AVCaptureDevice` / `HKAuthorizationStatus` / `UNAuthorizationStatus` into it. `PASKitNotifications` should adopt the same type so `authorizationStatus` has a rendered form. Deliberately **not** included: the permission card view — that is brand UI in all three apps and belongs at the call site.

**What the app would inject.** The mapping closure from `AVAuthorizationStatus`, the copy for each state (`ScanViewModel.swift:13-20`), and the button that calls `openAppSettings()`.

**Second-app evidence.**
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Features/Onboarding/OnboardingViewModel.swift:292-330` — `enum PermissionState { notDetermined, granted, denied }`, plus `healthPermissionState` and `notificationPermissionState` mapping *two different* system enums into it, and `refreshPermissionStatuses()`.
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Features/Onboarding/Steps/OnboardingPermissionsStep.swift:70-130` — the tri-state renderer, deep-linking to `x-apple-health://` (:33) or `UIApplication.openSettingsURLString` (:51), re-checking on `scenePhase == .active` (:62-67).
- `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Services/ReminderService.swift:77-79` — `requestAuthorizationIfNeeded()`, the "only ask when `.notDetermined`" guard, expressed as a third shape again.

Three apps, three incompatible spellings of the same three states.

**Effort.** S — one enum, one function, one doc paragraph.

**Recommendation. Extract now.** Cheap, and it is the kind of type that stops being written per-app the moment it exists.

**Linkage consequence.** `PASKitCore` is already inside this app's binary transitively (via `PASKitLifecycle` → `PASKitCore` → `KeychainAccess`, `Package.swift:63`). Adding the `PASKitCore` *product* dependency links no new third-party code — it only makes the module importable.

---

### 3. Linear capsule progress bar

**What it is.** `CoupleCalorieTracker/Views/DesignSystem.swift:94` — `struct MacroBar`: a `GeometryReader` over two `Capsule()`s, fraction clamped at :100, minimum-width floor at :108 so a near-zero value still reads as a bar.

**Why it is mechanism, not vocabulary.** The colours and the height are the app's; the geometry, the clamp, the floor and the animation are not. PASKit already owns this exact view — `Sources/PASKitLifecycle/Onboarding/PASOnboardingProgressBar.swift:19` is byte-for-byte the same mechanism (clamp at :27, `GeometryReader` + two capsules at :32-40, percentage accessibility at :43-44). It is simply filed and named as onboarding chrome, so nobody looking for a progress bar finds it.

**Proposed home.** Move it to `Sources/PASKitLifecycle/Indicators/` as `PASProgressBar`, the linear sibling of `PASProgressRing` (which already lives there and is documented as "the circular sibling of `PASOnboardingProgressBar`" — the pairing is already asserted, just not reflected in the file tree). Keep `PASOnboardingProgressBar` as a deprecated typealias so the onboarding docs and any adopter keep compiling. Add a `value:total:` convenience init, which is the form five of the six hand-rolled copies actually want.

**What the app would inject.** `.tint(kind.color)`, `height`, and the `value`/`target` pair.

**Second-app evidence.** Six hand-rolled copies across three apps, none of which found the existing type:
- WorkoutApp — `Features/Onboarding/OnboardingView.swift:139-151`, `Features/Profile/Views/MuscleRecoveryView.swift:101-111`, `Features/ActiveWorkout/Views/ActiveWorkoutView.swift:72-83`.
- XueTang — `Features/Lesson/View/ViewComponents/ExerciseNavBar.swift:41-56`, `Features/Readiness/View/ViewComponents/ReadinessDimensionRow.swift:83-95`.
- CoupleCalorieTracker — `Views/DesignSystem.swift:94`.

**Effort.** S — a file move, a typealias, one convenience init, and doc updates in `CLAUDE-INTEGRATION.md` + `docs/PASKitLifecycle.md`.

**Recommendation. Extract now** — though "extract" here means *promote and rename what PASKit already has*. Six independent reimplementations of a shipped type is a discoverability bug, and the fix is naming.

---

### 4. Lenient numeric decoding and user-input parsing

**What it is.** `CoupleCalorieTracker/Networking/FlexibleDouble.swift` — `AnyCodingKey` (:3), a `CodingKey` that accepts any string, and `FlexibleDouble` (:13), a `Decodable` that resolves a number, an int, a numeric string with a comma decimal separator (:28), or null into `Double?` without ever throwing. Used together at `Networking/OFFResponse.swift:69-71` to read hyphenated keys (`"energy-kcal_100g"`) that Swift cannot express as enum cases.

**Why it is mechanism, not vocabulary.** Neither type mentions food, Open Food Facts, or nutrition. `AnyCodingKey` is a general answer to "this JSON has keys my `CodingKeys` enum cannot spell"; `FlexibleDouble` is a general answer to "this producer is loose about number types and decimal separators". The OFF field names at `OFFResponse.swift:74-94` are the vocabulary, and they stay in the app.

**Proposed home.** `PASKitCore/Networking/` alongside `NetworkService` — `PASAnyCodingKey`, `PASFlexibleDouble`, and `Double(pasUserInput:)` for the keyboard-input twin. Consider a `PASFailable<T>` element wrapper to cover WorkoutApp's failable-array case, but only if it can be written without the infinite-loop trap that file documents.

**What the app would inject.** The key strings and the field mapping — i.e. all of `OFFResponse.swift`.

**Second-app evidence.** WorkoutApp solves adjacent halves of the same problem, independently:
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Extensions/Double+UserInput.swift:8-14` — `init?(userInput:)`, the same comma-vs-dot normalisation as `FlexibleDouble.swift:28`, at the keyboard boundary instead of the decode boundary. Both were written because German-locale input produces commas.
- `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Services/ChartPreferences.swift:70-83` — `LenientMetric`, a never-throwing `init(from:)` so one bad array element does not discard the array; its doc comment at :73-76 records the naive version's infinite loop.

XueTang's leniency is file-level rather than value-level (`Core/Content/ContentService.swift:757-768`, `decodeOptional`) — a different problem, and not evidence for this candidate.

**Effort.** S.

**Recommendation. Extract now**, scoped to `PASAnyCodingKey` + `PASFlexibleDouble` + `Double(pasUserInput:)`. Leave `LenientMetric`-style failable arrays out until a second app asks for that specific shape.

---

### 5. String-catalog sync script

**What it is.** `CoupleCalorieTracker/Scripts/sync-strings.sh` (12 lines) — builds the scheme into a throwaway derived-data path, then runs `xcrun xcstringstool sync` over every `*.stringsdata` the build emitted, and prints the resulting key count. Its header states the reason: Xcode's IDE syncs the catalog on every build, CLI builds do not.

**Why it is mechanism, not vocabulary.** The only app-specific tokens are the project path and the scheme name, both derivable or passable as arguments. The problem it solves is structural to how this studio works — sessions build from the command line, so without this step `Localizable.xcstrings` silently drifts from the source and new keys never reach translators.

**Proposed home.** Not a Swift module — PASKit ships no `Scripts/` directory and adding one for a per-project shell script would be the wrong shape. Two honest options: (a) a documented snippet in `CLAUDE-INTEGRATION.md` under a "Localization" heading, so every consuming app's session is told to add it; or (b) a job in the shared CI repo `moritztucher/ios-ci`, which WorkoutApp already calls from `/Users/moritztucher/Private/WorkoutApp/.github/workflows/testflight.yml`. (a) is the cheaper first step and matches how `CLAUDE-INTEGRATION.md` already carries conventions rather than code.

**What the app would inject.** Project path and scheme name.

**Second-app evidence.** Inverted, and stronger for it — the *need* is universal and the *supply* is one app:
- WorkoutApp — `Resources/Localizable.xcstrings`, 742 keys, `isCommentAutoGenerated: true`; no `xcstringstool` invocation, no `Makefile`, no shell script anywhere in the repo.
- XueTang — `XueTang/XueTang/Resources/Localizable.xcstrings`, 760 keys across `de, en, es, fr, ja, ko, ru`; `scripts/` holds only Python content-pipeline tools; no `xcstringstool` anywhere.

Both rely entirely on "Xcode extracts on build", which is exactly the assumption CLI-driven sessions violate — and XueTang's own `CLAUDE.md:106` documents that a byte-mismatched key silently stops resolving all seven translations.

**Effort.** S.

**Recommendation. Extract now**, as tooling. This is the cheapest studio-wide win on the list and the only candidate whose absence is currently causing silent damage in two apps.

---

### 6. `Color(hex:)` initializer

**What it is.** `CoupleCalorieTracker/Views/DesignSystem.swift:28-36` — a `private extension Color` taking a `UInt32`, used for eleven token values (`:8`, `:9`, `:13`, `:14`, `:69-71`).

**Why it is mechanism, not vocabulary.** The eleven hex values are the brand; the shift-and-divide is not. PASKit already owns the neighbouring mechanism — `Sources/PASKitCore/Styling/Color+LightDark.swift:17` — and its doc comment explicitly frames it as "apps build their semantic color tokens on top", which is precisely what a hex init supports.

**Proposed home.** `PASKitCore/Styling/Color+Hex.swift`, next to `Color+LightDark.swift`.

**What the app would inject.** The literals.

**Second-app evidence.** None. Grepping `init(hex` across both other repos returns nothing — WorkoutApp uses asset-catalog colours plus `Color(red:green:blue:)` (`Core/Theme/AppColors.swift:3-27`), XueTang uses `Color(red:green:blue:)` with the hex in a trailing comment (`ViewComponents/DesignSystem/Theme.swift:22-63`).

**Effort.** S — about eight lines.

**Recommendation. Extract when a second app needs it.** It is a mechanism and it is nearly free, but *build on real need* is the rule and today exactly one app has the need. Worth revisiting the moment either other app converts a token file, since both write hex in comments and would obviously use it.

---

### 7. Initial-letter avatar

**What it is.** `CoupleCalorieTracker/Views/DesignSystem.swift:188-202` — `AvatarChip`: first grapheme of a name, uppercased, on a filled circle with a tinted ring. A duplicate initial-derivation sits at `Views/DayScreen.swift:445` (`avatarInitial(for:)`).

**Why it is partly mechanism.** "Turn a display name into a single presentable initial" is real, non-obvious logic — empty names, emoji, combining marks and non-Latin scripts all break the naive `prefix(1)`. The circle, the ring and the colours are decoration.

**Proposed home.** If anything moves, only the string half: a `PASDisplayInitial(of:)` helper in `PASKitCore/Styling`. The view itself is brand.

**What the app would inject.** Colours, size, ring state.

**Second-app evidence.** Present but divergent. XueTang has two hand-rolled instances — `Features/System/View/AccountSettingsView.swift:23-26` and `:159-167` (falls back to `"学"` when there is no name) and `Features/League/View/ViewComponents/LeagueMemberRow.swift:61-71` (renders a model-supplied `avatarCharacter`, `Features/League/Models/LeagueModels.swift:83`) — and a dedicated helper, `Core/Utilities/DisplayName.swift`, that folds names to unaccented Latin so its brush typeface has a glyph, paired with `Theme.swift:160-172`'s `brushScript(covering:)` coverage check. WorkoutApp has none: it has no user-identity concept at all. So the two implementations that exist disagree about the hardest part — what to do when the initial has no glyph.

**Effort.** S.

**Recommendation. Extract when a second app needs it.** Generalising today would mean either adopting XueTang's font-coverage fallback (which drags typeface concerns into `PASKitCore`) or shipping a helper XueTang cannot use. Neither is better than the two local versions.

---

### 8. Trailing-aligned form rows

**What it is.** `CoupleCalorieTracker/Views/FormRows.swift:10` (`LabeledNumberRow`) and `:35` (`LabeledTextRow`) — `LabeledContent` wrapping a trailing-aligned `TextField`, with the label bound as an explicit `accessibilityLabel` rather than a placeholder. The header comment at :3-9 records the wart being fixed: a bare `TextField` in a `Form` left-aligns while `Picker` and `DatePicker` trail, so numeric rows read down the wrong edge.

**Why it is mechanism, not vocabulary.** No brand, no domain — pure SwiftUI system styling plus an accessibility correction. It is the sort of thing `PASKitLifecycle/Settings` exists for.

**Proposed home.** `PASKitLifecycle/Settings/`, next to `AppInfoFooter`. Natural pairing with `Double(pasUserInput:)` from candidate 4.

**What the app would inject.** Title, binding, unit suffix.

**Second-app evidence.** None. WorkoutApp's numeric entry is a stepper/wheel idiom instead — `ViewComponents/StepperCell.swift:3`, `ViewComponents/ValueWheel.swift`, with display-boundary rounding in `Features/Profile/Models/MeasurementFieldConverter.swift:15-52`. XueTang's nearest neighbour is `ViewComponents/Layout/XTNavRow.swift`, a navigation row, not an editable field. Neither uses `LabeledContent` for input.

**Effort.** S.

**Recommendation. Extract when a second app needs it.** Correct and reusable, but one app uses it and the other two chose different input idioms on purpose.

---

### 9. Barcode scanning and camera plumbing

**What it is.** `CoupleCalorieTracker/Scanner/CameraAccess.swift:3` (authorization + `setTorch(on:)` at :30, with the comment at :27-29 explaining that torch is a device property `DataScannerViewController` does not expose) and `Scanner/BarcodeScannerView.swift:5` — a `UIViewControllerRepresentable` over `DataScannerViewController` with start/stop driven by an `isActive` binding (:22-29) and a delegate coordinator (:35-50). Availability gating lives at `ViewModels/ScanViewModel.swift:45-72`, which correctly distinguishes `isSupported` (hardware/OS) from `isAvailable` (this moment).

**Why it is mechanism, not vocabulary.** This is the most obviously library-shaped code in the repo. Nothing in either file mentions food or Open Food Facts; the symbologies (`.ean13`, `.ean8`, `BarcodeScannerView.swift:12`) are the one app-supplied parameter, and the `isSupported`-vs-`isAvailable` distinction plus torch-outside-the-scanner are exactly the kind of platform knowledge PASKit exists to record once.

**Proposed home.** Would be a `PASKitScanning` module (VisionKit + AVFoundation, iOS-only, no vendor SDK) — a representable parameterised by symbologies with a scan callback, plus the camera-authorization and torch helpers.

**What the app would inject.** Symbologies, the payload-validation rule (`ScanViewModel.swift:75-77` — 6-14 digits, all numeric), the viewfinder overlay (`ScanScreen.swift:334` `ScannerBrackets`), and every string.

**Second-app evidence.** **None — single app today.** WorkoutApp contains no `AVCaptureDevice`, `AVCaptureSession`, `VisionKit`, `Vision`, `PhotosUI` or `PHPhotoLibrary`; its only AVFoundation use is `AVAudioPlayer` for the rest-timer chime (`Core/Services/RestEndSound.swift`). XueTang has no camera code either and no `NSCameraUsageDescription` in its `Info.plist`; its AVFoundation use is audio playback (`Core/Services/AudioService.swift`).

**Effort.** M — a new module, target, product, spec and README for roughly 90 lines.

**Recommendation. Extract when a second app needs it.** This is the candidate most likely to be extracted on instinct, and the rule says no: *"a module or feature is built when the first real app needs that capability — never speculatively."* One app needs it, the code is already app-agnostic where it sits, and moving it now would buy a module boundary with no second consumer to justify it. Revisit the moment any app adds a scanner — the code is already in the right shape to lift unchanged.

---

## Already in PASKit — adopt, don't extract

These are not extraction candidates. They are capabilities PASKit v0.3.1 already ships that CoupleCalorieTracker reimplemented locally, which matters more to the studio than most of the list above. The app imports PASKit in exactly three files (`App/RootView.swift:2`, `Views/ProfileScreen.swift:2`, `Domain/ReleaseNotes.swift:10`) and uses only the release-notes stack.

| Local code | PASKit equivalent | Note |
|------------|-------------------|------|
| `ViewModels/OnboardingViewModel.swift:11` step enum + `:61-83` `advance()`/`goBack()`; `Views/Onboarding/OnboardingFlow.swift:35-63` progress dots | `PASOnboardingFlow` + `View.pasOnboardingTransition` + `PASOnboardingProgressBar` | The local flow has no transition choreography and no draft resume. WorkoutApp (`Features/Onboarding/OnboardingViewModel.swift:11-505`) and XueTang (`Features/Onboarding/View/TranslationLanguageStepView.swift:3-14`, a stub awaiting a coordinator) have not adopted it either — three apps, zero adopters of a shipped engine. |
| `Views/DesignSystem.swift:147` `RingGauge` | `PASProgressRing` | Same geometry; the local version adds `glow` and a `value`/`target` pair. WorkoutApp carries the same duplicate at `ViewComponents/CircularProgress.swift:3`, and XueTang carries three (`MemoryRing.swift:5`, `DailyGoalRing.swift:14`, `ProfileStatRing.swift:3`). |
| `Views/DesignSystem.swift:230` `NeonPressedButtonStyle` | `.buttonStyle(.pasPressable())` in `PASKitCore` | Scale + spring, identical intent. |
| `Views/ProfileScreen.swift:546-568` `debugCard` | `View.pasDevelopmentOverlay` + `PASDevelopmentMenu` | The local card is `#if DEBUG`-wrapped inside a production settings screen; PASKit's compiles to a no-op in release. |
| `Persistence/PersistenceController.swift:34` `print(...)` on store-load failure | `PASLogger.make(category:)` | The app's only logging statement, and it is a `print` in a release path. |
| `Persistence/ProfileStore.swift:4-8` `DefaultsKey` + raw `UserDefaults` reads/writes; `ViewModels/OnboardingViewModel.swift:123` | `PASSettingsStore` + `@PASDefault` | Three keys, hand-rolled string constants and manual `set`/`string(forKey:)`. |
| `Domain/PersonProfile.swift:112-122` `clockLabel` / `compactLabel` | `PASDurationFormat.clock` / `.compact` | Partial overlap only — PASKit emits `"1:04:12"` and `"4m 12s"`, the app wants `"12:42"` and `"3H 18M"`. Either the app accepts PASKit's forms or PASKit gains an hours-minutes variant; do not leave both. |
| `Networking/OpenFoodFactsClient.swift:41` raw `URLSession.data(for:)` | `NetworkService` / `URLSessionNetworkService` | The OFF-specific error mapping and result cache stay local; the transport need not. |

Adopting these would remove roughly 200 lines from the app and, in the onboarding case, close a gap that exists identically in all three apps.

---

## Should stay local

**Nutrition domain — `Domain/TargetCalculator.swift`, `Domain/MacroTheme.swift`, `Domain/DailyTargets.swift`, `Domain/FoodEntry.swift`, `Domain/Product.swift`, `Domain/MealTemplate.swift`, `ViewModels/RemainingNeed.swift`.** This is the app, not a mechanism. Mifflin-St Jeor at `TargetCalculator.swift:21-27`, the Atwater 4/4/9 values at `DailyTargets.swift:12`, the six macro themes at `MacroTheme.swift:46-61` — all pure vocabulary, and the file comments at `TargetCalculator.swift:3-11` and `MacroTheme.swift:13-15` explicitly mark most constants as tunable defaults awaiting calibration, i.e. still moving. There is no `PASKitNutrition` and there should not be: WorkoutApp, the only other app with a body model, has no calorie or macro concept anywhere (its `Features/Profile/Models/BodyMetrics.swift:113` `BodyCalculators` does BMI and FFMI, which is a different domain).

**Open Food Facts client and DTOs — `Networking/OpenFoodFactsClient.swift`, `Networking/OFFResponse.swift`, `Networking/OFFError.swift`.** Vendor-specific from the first line: the staging/production host switch (`:11-15`), the mandatory `User-Agent` (`:90-93`, an IP-ban risk per the app's own memory file), the field list (`:17`), the kJ-vs-kcal derivation (`:126-131`), the sodium→salt fallback (`:136-138`), and the ml/g unit sniffing with its German-package-word guard (`:187-221`). `OFFError.userMessage` (`OFFError.swift:10`) names Open Food Facts in a user-facing string. The generalisable pieces are already extracted above as candidate 4.

**`Domain/MeasurementUnit.swift`.** A two-case enum (g/ml) whose entire content is display suffixes and a "per 100 g" label. It is not unit *conversion* — the file comment at :3-6 says so explicitly, the maths is identical for both cases. WorkoutApp's real conversion layer (`Core/Enums/UnitSystem.swift:88-128`, kg↔lb, cm↔in, feet-inches rendering) is a genuinely different thing and also stays local: storage-is-metric-convert-at-the-boundary is a policy, and PASKit ships no measurement module for one app's policy.

**`Domain/SplitCalculator.swift` and `Domain/SplitMode.swift`.** Four lines of arithmetic (`:12-14`) clamping one person's share of a shared meal between 25% and 75% by remaining calories. Generalising it to "proportional share with bounds" would produce an API longer than the formula, and `SplitMode.displayName` (`:9-11`) returns `"50/50"` and `"Calculate"` — this app's words.

**Core Data stack — `Persistence/PersistenceController.swift`, `Persistence/ProfileStore.swift`, `Persistence/FoodEntryStore.swift`, `Persistence/FavoriteStore.swift`, `Persistence/MealTemplateStore.swift`.** The engine choice is a constraint the other apps do not share: `NSPersistentCloudKitContainer` was chosen because SwiftData cannot use CloudKit's *shared* database, and two-account sharing is this app's core feature. WorkoutApp (`Core/Services/DataStore.swift:92-158`) and XueTang (`Core/State/ProgressStore.swift:97-116`) are both SwiftData. A shared bootstrap would be a lowest-common-denominator wrapper over two incompatible frameworks, and PASKit deliberately ships no persistence dependency — `PASAppGroupContainer` is engine-agnostic for exactly this reason. Two adjacent *patterns* do recur and are worth watching, but not extracting yet: an in-memory/preview container helper (CCT `PersistenceController.swift:25-27`, WorkoutApp `DataStore.swift:126-139`, XueTang repeated verbatim in fourteen test files) and a "store failed → degrade and tell the UI" health signal (XueTang `ProgressStore.swift:14-22` `StorageHealth`, versus CCT's `fatalError`/`print` at `PersistenceController.swift:31-36`). Both are engine-typed, so neither has a shared shape today.

**Design tokens and branded primitives — `Views/DesignSystem.swift` `DS` (:4-26), `NeonCard` (:239), `neonCard()` (:250), `PrimaryCTAButton` (:205), `neonGlow` (:55), `heroNumeralStyle` (:40), `sectionLabelStyle` (:47), `MacroKind` colours (:64-91), `SlotIcon` (:295).** Tempting because all three apps have a token enum — CCT's `DS`, WorkoutApp's `AppTheme` (`Core/Theme/AppTheme.swift:5-37`), XueTang's `XTSpacing`/`XTRadius`/`XTMotion` (`ViewComponents/DesignSystem/Theme.swift:109-152`) — but that is the point: the *values* are the brand and the *shape* is twenty lines of `static let`. `PASKitLifecycle`'s spec states it plainly: "PASKit has no design module — theme stays per-app", and the branding-slot pattern (`.cardContainer { NeonCard { $0.content } }`, already used at `App/RootView.swift:33-35`) is how an app's card reaches a PASKit view without PASKit owning cards. The same reasoning rejects the card containers that are triplicated inside WorkoutApp alone (`ViewComponents/ThemedCard.swift:3`, `ViewComponents/ViewModifiers/CardStyle.swift:3`) — that is a WorkoutApp dedup, not a PASKit extraction.

**`Views/DesignSystem.swift:260` `SharedSplitPill`.** A two-segment capsule with optional percentage labels. Structurally generic, but it exists to render one concept — how a shared meal divided between two people — and no other app has a two-party split. Single app, single use site.

**`Views/DesignSystem.swift:117` `MacroColumn` and the "consumed / target" value line (:133-143).** All three apps render a value-over-target row — WorkoutApp `Features/Home/Views/ViewComponents/WeeklyVerdictCard.swift:163-196`, XueTang six inline `x / y` sites including `ExerciseNavBar.swift:59` and `XTStatBand.swift:6` — and every one is styled differently, in a different font, with different colour semantics. Once the styling is removed what remains is `.monospacedDigit()`, which is a system API. Nothing to extract.

**`ViewModels/ScanViewModel.swift:8-31` `ScanState` — and a generic `Loadable`/`AsyncState` in general.** A generic load-state enum is the classic false positive. `ScanState` carries `.unavailable(UnavailableReason)`, `.loading(barcode:)`, `.incomplete(Product)` and `.notFound(barcode:)` — four cases with no generic analogue, because "found but the data is unusable" (documented in the app's memory as 15-25% of German scans) is a domain state, not a loading state. WorkoutApp's two ad-hoc enums (`Features/Settings/ViewModels/DataExportViewModel.swift:10-15` with a progress payload, `Features/Profile/Views/ViewComponents/MeasurementEditorSheet.swift:38-44` with a non-error `.empty`) and XueTang's `Features/Commerce/Models/PriceLoadState.swift:9-13` diverge the same way. A shared `Loadable<T>` would be a strictly worse API than any of the five local versions, and every call site would immediately wrap it.

**Day navigator — `ViewModels/DayViewModel.swift:109-130` and `Views/DayScreen.swift:50-111`.** Previous/next/today with a forward cap at today (`:42-44`, `:127`), a graphical date-picker sheet, and a horizontal swipe gesture (`DayScreen.swift:152-161`). Genuinely generic in shape, but no other app browses a day at a time — neither WorkoutApp's History/Charts nor XueTang has an equivalent. PASKit already ships the arithmetic underneath it (`Date.pasAdding(days:)`, `pasIsSameDay(as:)`, `pasStartOfDay()`), which is the right altitude for a package with one consumer.

**`Views/ScanScreen.swift:334` `ScannerBrackets` and `:276` `ScannerContentView`.** The corner-bracket viewfinder shape and its pulse/sweep animation are craft, and good craft — but they are this app's scanner aesthetic, tied to `DS.volt`. If candidate 9 is ever extracted, these stay behind as the app-supplied overlay.

**`Health/HealthProfileReader.swift:95-117` onboarding merge policy** (fill only empty fields, count found values, choose one of three messages). The reader's plumbing is candidate 1; this policy is not. It encodes a product decision about how aggressively to overwrite what the user already typed, and WorkoutApp's equivalent import flow makes a different one.
