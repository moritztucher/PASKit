# WorkoutApp → PASKit extraction audit

**Date:** 2026-09-04 · **PASKit:** v0.3.1 (`Package.swift`, swift-tools 6.2) · **App:** `/Users/moritztucher/Private/WorkoutApp`, branch `develop`, `b53dfd9`
**Cross-checked against:** `/Users/moritztucher/Private/CoupleCalorieTracker` (`main`) and `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2` (`develop-xt2-revamp`, app at `XueTang/XueTang/`). Read-only on all three repos.

## Summary

WorkoutApp is 239 Swift files and imports PASKit in 23 of them, but only for logging, notifications, purchases, analytics, `AppInfo`, the release-note stack and `pasGlass` — the rest of the surface (settings store, streaks, haptics, sharing, onboarding, rate prompt) is hand-rolled locally, and some of it is a byte-for-byte reimplementation of what PASKit already ships. Separating that adoption debt from genuine extraction candidates leaves a short list. The strongest candidate by a wide margin is **HealthKit plumbing**: two of the three studio apps independently wrote the same `HKHealthStore` lifecycle, availability check, authorization request and latest-sample read, and neither can reuse the other's. Below it sit four small mechanisms where a second app has already written the twin — a wrapping flow layout, a bundled-image loader with off-main decode, comma-tolerant decimal input, and a keyboard "Done" toolbar — each cheap to lift and each currently duplicated. Two more (the accessibility-safe wheel picker, the reorder drop delegate) are single-app today but exist to encode a *defect workaround* rather than a feature, which is exactly the knowledge a shared package should hold so app #2 never rediscovers the crash. Everything else — the export pipeline, the weekly streak walker, the Live Activity controller — is well-built and genuinely generic but has no second consumer, so per "build on real need" it stays put with a note on what the lift would cost later.

| Candidate | Proposed PASKit module | Second-app evidence | Effort | Recommendation |
|---|---|---|---|---|
| HealthKit facade (store, availability, descriptor-driven auth, latest-sample reads) | **new `PASKitHealth`** | CCT `Health/HealthProfileReader.swift` | L | **Extract now** |
| Decimal-pad input pair (`Double(userInput:)` + `keyboardDoneButton()`) | `PASKitCore/Input` | CCT `LogEntryViewModel.swift:326`, `ManualMacrosView.swift:29-35` | S | **Extract now** |
| Wrapping flow layout | `PASKitCore/Layout` | XueTang `PillFlow.swift` (independent `FlowLayout`) | S | **Extract now** |
| Bundled-image loader (off-main decode + `NSCache`) | `PASKitCore/Images` | XueTang `Core/Artwork/Artwork.swift` | M | **Extract now** |
| Accessibility-safe wheel picker (`ValueWheel`) | `PASKitLifecycle/Pickers` | none — single app, but works around an Apple crash | M | **Extract now** |
| `ReorderDropDelegate` | `PASKitCore/DragDrop` | none in these two — already copy-pasted from `dk-physio-sports-ios` | S | **Extract now** |
| Streaming export pipeline (`ExportFormatting` + `ExportFileWriter`) | `PASKitCore/Export` | none — single app today | M | Extract when a second app needs it |
| History-derived weekly streak walker | `PASKitCore/Streak` | none — single app today | S | Extract when a second app needs it |
| Live Activity controller | `PASKitLifecycle/LiveActivity` | none — single app today | S | Extract when a second app needs it |
| One-shot audio cue player (`RestEndSound`) | — | XueTang `AudioService` shares only session teardown | S | Leave local |

A separate section at the end — **Already in PASKit** — lists six places where WorkoutApp ships a parallel local copy of an existing PASKit API. That is deletion work, not extraction work, and it is worth more to the studio than half this table.

---

## Candidates

### 1. HealthKit facade → new `PASKitHealth` module

**What it is.**
`WorkoutApp/WorkoutApp/Core/Services/HealthManager.swift` — `HealthManager`, `@Observable @MainActor`: the single `HKHealthStore` instance (`:19`), `isAvailable` (`:25-27`), `refreshConnectionState()` (`:35-70`) which derives a three-state `ConnectionState` from write-authorization across the core sample types, the `permissionDescriptors` table (`:87-131`), `writeStatus(for:)` (`:134-138`) and `requestAuthorization()` (`:141-152`).
`WorkoutApp/WorkoutApp/Core/Services/HealthKitPermissionDescriptor.swift:6-25` — `HealthKitPermissionDescriptor` (id / displayName / SF Symbol / `writeType` / `readType`), which drives both the auth request and the per-type status listing.
`WorkoutApp/WorkoutApp/Core/Services/HealthManager+Reading.swift` — the read half: `foreignSourcePredicate` (`:38-42`, excludes samples this app wrote), `readWorkouts(since:strengthOnly:)` (`:46-76`), `readLatestBodyMetrics()` (`:80-101`) and the `latestSample(_:)` helper it calls (`:105-118`). Its file-level doc (`:5-14`) states the contract that makes the whole read half correct: iOS reports read authorization as `.notDetermined` even when granted, so a read path may never gate on `isAuthorized` and must return an empty value on every failure mode.

**Why it is mechanism, not vocabulary.** Every line above is HealthKit protocol, not fitness domain. "One `HKHealthStore` per app", "read grants are unqueryable so never gate reads on them", "derive connection state from write status", "exclude your own source or your own data comes back as an import", "a sample query descriptor sorted `endDate` descending, limit 1" — none of that mentions a workout. The vocabulary is the *contents* of `permissionDescriptors` (`bodyMass`, `leanBodyMass`, `figure.strengthtraining.traditional`), the `strengthActivityTypes` list (`HealthManager+Reading.swift:22-25`), and the domain structs `ImportedWorkout` / `ImportedBodyMetrics`.

**Proposed home.** A **new module**, `Sources/PASKitHealth/`, with its own library product — not `PASKitCore`. HealthKit is a system framework, so there is no vendor dependency to worry about, but linking it drags `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` expectations and an entitlement into every consumer; the studio's next non-health app must not inherit that. This mirrors exactly why `PASKitNotifications` is its own module rather than a `PASKitCore/Notifications` folder. Surface: `PASHealth.shared.configure(_ permissions: [PASHealthPermission])`, observable `authorizationStatus` / `isAvailable`, `requestAuthorization()`, `writeStatus(for:)`, `latestQuantity(_:unit:excludingOwnSource:)`, `samples(of:since:predicate:limit:)`, `save(_ quantity:...)`, `saveWorkout(activityType:start:end:)`.

**What the app injects.** The `[PASHealthPermission]` table (ids, display names, SF Symbols, `HKSampleType`/`HKObjectType`), the activity-type filter for workout reads, the unit conversions (HealthKit stores body fat as a 0–1 fraction; WorkoutApp stores whole percent — `HealthManager+Reading.swift:90`), and every domain struct the raw samples map into. PASKit returns `HKQuantitySample` / `HKWorkout` unwrapped, exactly as `PASKitPurchases` passes RevenueCat types through.

**Second-app evidence.** `CoupleCalorieTracker/CoupleCalorieTracker/Health/HealthProfileReader.swift` reimplements the same plumbing at a smaller scale: its own `HKHealthStore` (`:27`), its own `readTypes` set (`:29-34`), the same `isAvailable` check (`:36-38`), the same `try? await store.requestAuthorization(toShare: [], read:)` (`:43`), and `readLatestQuantity(type:unit:)` (`:67-75`) which is character-for-character the same `HKSampleQueryDescriptor` shape as WorkoutApp's `latestSample`. It even independently rediscovered the read-opacity contract and wrote it in its own words at `:21-24` ("a denied read looks identical to no data"). Two apps, two authors of the same paragraph, zero shared code.

**Effort.** L — the largest item here. Roughly 250 lines of extractable mechanism spread across three files, plus a new target, product, DocC page, README and module spec.

**Recommendation.** **Extract now.** This is the single highest-value item in the audit: two of three studio apps use HealthKit today, and CCT's version is missing the connection-state model and the own-source exclusion that WorkoutApp had to learn.

---

### 2. Decimal-pad input pair → `PASKitCore/Input`

**What it is.**
`WorkoutApp/WorkoutApp/Core/Extensions/Double+UserInput.swift:8-14` — `Double.init?(userInput: String)`: trims whitespace, maps `,` → `.`, then parses. Exists because German-locale keyboards produce a comma that `Double.init(_:)` rejects.
`WorkoutApp/WorkoutApp/ViewComponents/ViewModifiers/KeyboardDoneButton.swift:7-19` — `View.keyboardDoneButton()`: a `ToolbarItemGroup(placement: .keyboard)` with a Done button that sends `resignFirstResponder`. Exists because `.decimalPad` has no return key, so on a screen where every row is a field the keyboard cannot be dismissed at all.

**Why it is mechanism, not vocabulary.** Both are platform facts with no domain content: iOS decimal keyboards emit a locale separator Foundation's non-localized parser won't take, and iOS decimal keyboards have no dismiss affordance. Nothing about weights, reps or grams appears in either.

**Proposed home.** `Sources/PASKitCore/Input/` — `Double+PASUserInput.swift` and `View+PASKeyboardDoneButton.swift`. PASKitCore is right: no vendor dependency, and `Styling`/`Haptics` already establish that Core may ship SwiftUI/UIKit-gated view extensions. Name them `Double(pasUserInput:)` and `.pasKeyboardDoneButton(title:)` to match the `pas` prefix convention (`pasGlass`, `pasToast`, `pasPressable`). The Done title must be a caller-supplied parameter, not the literal `"Done"` — PASKit ships no string catalog and renders strings verbatim.

**What the app injects.** The already-localized button title. Nothing else.

**Second-app evidence.** CCT wrote the identical comma normalization inline: `CoupleCalorieTracker/CoupleCalorieTracker/ViewModels/LogEntryViewModel.swift:326-327` (`trimmed[range].replacingOccurrences(of: ",", with: ".")` then `Double(numberString)`) — same fix, same reason, embedded in a serving-size regex parser instead of an initializer. And CCT has the un-dismissable-keyboard bug WorkoutApp already fixed: five `.decimalPad` fields at `Views/ManualMacrosView.swift:29-35` plus `Views/FormRows.swift:19`, and a repo-wide grep for `placement: .keyboard` in CCT returns nothing.

**Effort.** S — under 40 lines total.

**Recommendation.** **Extract now.** The cheapest item in the audit with real second-app evidence, and adopting it fixes a live CCT bug rather than merely deduplicating.

---

### 3. Wrapping flow layout → `PASKitCore/Layout`

**What it is.** `WorkoutApp/WorkoutApp/ViewComponents/FlowLayout.swift` — a `FlowLayout` view over `RandomAccessCollection` (`:7-25`) backed by a private greedy row-wrapping `Layout` conformance, `_WrapLayout` (`:28-73`). Used for muscle tags and filter chips.

**Why it is mechanism, not vocabulary.** It is `sizeThatFits` / `placeSubviews` arithmetic. There is no app concept anywhere in the file; the content closure is entirely the caller's.

**Proposed home.** `Sources/PASKitCore/Layout/PASFlowLayout.swift`. Ship the bare `Layout` conformance (`PASFlowLayout`), not the `ForEach`-wrapping view — the `Layout` composes with anything, and the wrapper view constrains callers to `Identifiable` for no benefit. **Take XueTang's implementation as the base, not WorkoutApp's**: it is strictly better on three points that matter — a `Cache` so the row solve is not repeated between `sizeThatFits` and `placeSubviews` (`PillFlow.swift:73-89`), a separate `lineSpacing` axis, and a correct intrinsic width when no proposal is offered, e.g. inside a `ScrollView` (`:36-48`). WorkoutApp's `_WrapLayout.layout` (`FlowLayout.swift:53-72`) returns an unused empty rows array and re-walks the subviews on every pass.

**What the app injects.** `spacing`, `lineSpacing`, and the subviews. Nothing else.

**Second-app evidence.** `ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Features/Lesson/View/ViewComponents/Exercises/PillFlow.swift:23-113` — an independently written `FlowLayout: Layout` solving the identical problem (pills of varying width wrapping to rows) with no knowledge of WorkoutApp's. Two apps, two implementations, same 90 lines of arithmetic.

**Effort.** S.

**Recommendation.** **Extract now.**

---

### 4. Bundled-image loader with off-main decode and cache → `PASKitCore/Images`

**What it is.** `WorkoutApp/WorkoutApp/ViewComponents/ExerciseThumbnail.swift` — `ExerciseThumbnail` (`:11-33`), a SwiftUI view with a placeholder slot that resolves its image in `.task(id:)`, over `ExerciseThumbnailCache` (`:37-55`): an `actor` around an `NSCache<NSString, UIImage>` that resolves a bundle path (jpg, then png fallback), decodes off the main thread and calls `byPreparingForDisplay()` so rendering is a straight blit. Its doc records the bug it fixed: `UIImage(contentsOfFile:)` called inside a view `body` made the whole app sluggish (`:5-7`).

**Why it is mechanism, not vocabulary.** "Load a loose image file from the bundle, decode it off the main actor, memoize it, and swap a placeholder for it" contains no domain. The only app-specific parts are the key (an exercise id) and the extension search order.

**Proposed home.** `Sources/PASKitCore/Images/` — `PASBundleImage` (the actor-backed loader) plus `PASBundleImageView` (the placeholder-swapping view). Take **both** apps' improvements: XueTang's decode-time downsampling via `CGImageSourceCreateThumbnailAtIndex` with an explicit `maxPixelSize` and a cost-based `totalCostLimit`, and WorkoutApp's `byPreparingForDisplay()` and extension-fallback resolution. Key the cache on `name + maxPixelSize`, as XueTang already does (`Artwork.swift:72-74`).

**What the app injects.** The resource name, the extension search order, the target pixel size, and the placeholder view.

**Second-app evidence.** `ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Artwork/Artwork.swift:13-86` — the same mechanism, written for the same reason. Its doc comment (`:8-12`) even makes the same argument WorkoutApp's does: an asset catalog stores decoded bitmaps, so loose files plus an in-memory cache and decode-time downsampling is the cheaper trade. XueTang measured its cost at up to 29 ms on a cold main-thread read against an 8.3 ms budget (`:56-60`). Two apps hit the same wall a year apart.

**Effort.** M — merging the two implementations needs care around the cost accounting and the `@unchecked Sendable` box, and the API has to work both async (WorkoutApp's `.task`) and synchronously-on-hit (XueTang deliberately returns a cache hit synchronously so a recycled cell does not flash its placeholder — `Artwork.swift:17-21`).

**Recommendation.** **Extract now.**

---

### 5. Accessibility-safe wheel picker (`ValueWheel`) → `PASKitLifecycle/Pickers`

**What it is.** `WorkoutApp/WorkoutApp/ViewComponents/ValueWheel.swift:13-118` — a pure-SwiftUI vertical snapping wheel over `ScrollView` + `.scrollTargetBehavior(.viewAligned)` + `.scrollPosition(id:)`, generic over `Value: Hashable`, with a synthesized accessibility element (`:67-81`), an `accessibilityAdjustableAction`, `sensoryFeedback(.selection)`, and reduce-motion-aware scroll transitions.

**Why it is mechanism, not vocabulary.** The type is `ValueWheel<Value: Hashable>` taking `values`, a `selection` binding, a `title`, and `display` / `spoken` closures — every piece of content is injected. More importantly, this file's reason to exist is a **platform defect**, documented at `:5-12`: `Picker(...).pickerStyle(.wheel)` emits a malformed accessibility subtree (a child slot holding a raw `NSString` instead of an accessibility element) that crashes anything walking the tree through the accessibility translation bridge — VoiceOver and UI-testing tooling included. It reproduces with zero accessibility modifiers and survives `.accessibilityElement(children: .ignore)`, so it cannot be patched from the SwiftUI side. A defect workaround with a written repro is the highest-value thing a shared package can hold, because the alternative is app #2 spending the same day finding it.

**Proposed home.** `Sources/PASKitLifecycle/Pickers/PASValueWheel.swift`. Lifecycle, not Core: it is a UI primitive, and Lifecycle already carries the brand-free primitives (`PASProgressRing`, `PASToast`). Three theme references must be stripped — `AppTheme.Radius.small` and `Color.surfaceElevated` on the selection band (`:59-61`), and `.font(.bodyLarge)` / `Color.textPrimary` on the rows (`:91-92`) — replaced by a `.thinMaterial` (or `.tint`-derived) band, the default `.body` font and `.primary`, per the "PASKit owns no design layer" rule. Row height and visible-row count (`:17-19`) become init parameters with the current values as defaults.

**What the app injects.** `values`, the `selection` binding, `title`, and the `display` / `spoken` closures — already the exact call-site shape at `Features/Home/Views/ViewComponents/ValuePickerSheet.swift`. After generalising, also the row metrics and any tint.

**Second-app evidence.** None — single app today. Neither CCT nor XueTang has a wheel picker (a repo-wide grep for `pickerStyle(.wheel)` and `scrollPosition(id:` across both returns nothing). The argument for extraction here is not duplication but that the *next* app that reaches for a wheel picker will reach for `Picker(.wheel)` and ship the crash.

**Effort.** M — the component is 120 lines and already generic; the work is de-theming and writing the DocC note that carries the "do NOT swap this back for a wheel `Picker`" warning across the module boundary.

**Recommendation.** **Extract now.** This is the one place I would override "build on real need," because what is being shared is a bug report as much as a component. If that is too loose a reading of the rule, the fallback is to extract the doc comment as an ADR now and the code when app #2 needs a wheel — but that is strictly worse.

---

### 6. `ReorderDropDelegate` → `PASKitCore/DragDrop`

**What it is.** `WorkoutApp/WorkoutApp/Core/Delegates/ReorderDropDelegate.swift:8-51` — a `DropDelegate` generic over `Item: Hashable & Identifiable` that live-reorders a bound array during a drag (`dropEntered`, `:26-40`), declares `.move` intent (`:42-44`), and fires a `dropAction` closure on drop so the caller can persist (`:46-50`).

**Why it is mechanism, not vocabulary.** The type has four inputs — the item, the array binding, the current-drag binding and a closure — and no knowledge of what it moves. The whole file is `DropDelegate` protocol satisfaction.

**Proposed home.** `Sources/PASKitCore/DragDrop/PASReorderDropDelegate.swift`.

**What the app injects.** The item, the `[Item]` binding, the in-flight-drag binding, and the persist closure. Unchanged from today's call site.

**Second-app evidence.** None in CCT or XueTang — but the file's own doc comment is the evidence: line 4 reads *"Ported from the dk-physio-sports-ios project (`ReorderDropDelegate`) — same behaviour"*. This code has already been copy-pasted across a project boundary once. That is precisely the pattern PASKit exists to end, and it means the "second app" test was passed before this repo existed.

**Effort.** S — 50 lines, no theme references, no generalisation needed.

**Recommendation.** **Extract now**, bundled with the flow-layout PR.

---

### 7. Streaming export pipeline → `PASKitCore/Export` (later)

**What it is.**
`WorkoutApp/WorkoutApp/Core/Services/DataExportFormatting.swift:8-100` — `ExportFormatting`: locale-independent decimal/integer/bool rendering with non-finite handling (`:16-39`), UTC and colon-separated local ISO-8601 styles (`:45-60`), a `fileDateStamp` built from `Calendar(identifier: .gregorian)` components rather than `DateFormatter` so a Buddhist calendar or non-Latin numeral locale can't land in a filename (`:65-73`), and RFC 4180 CSV escaping applied unconditionally to every field (`:84-100`).
`WorkoutApp/WorkoutApp/Core/Services/DataExportService.swift:81-112` — `ExportFileWriter`, an `actor` over a `FileHandle` that keeps every disk write off the main actor and accumulates its own byte count.
`DataExportService.export(_:progress:)` (`:145-194`) — the staging-file protocol: write to `<uuid>.part` with `FileProtectionType.completeUnlessOpen`, chunk at 50 records with a `progress` callback and `Task.yield()`, close the handle on both paths, then `promote` (`:211-222`) which sweeps the directory and moves the staging file into place so exactly one export exists and a truncated file can never be shared.

**Why it is mechanism, not vocabulary.** `ExportFormatting` is a pure function library with no app types at all — its doc calls itself "the entire correctness surface for the export feature," and the correctness rules it encodes (spreadsheets read POSIX decimals; naive CSV parsers need every field quoted; filenames must not be locale-rendered) belong to CSV and to iOS, not to workouts. `ExportFileWriter` and the staging/promote protocol are equally domain-free. The vocabulary is `DataExportFormat`'s three cases and its `WorkoutApp-…` filename stems (`:6-35`), the snapshot types, and the three serializers.

**Proposed home.** `Sources/PASKitCore/Export/` — `PASCSV` (field/list/row escaping), `PASExportFormatting` (numbers + ISO styles + file date stamp), `PASExportWriter` (the actor plus staging/promote/chunk-progress loop, taking a caller-supplied `(PASExportWriter) async throws -> Int` body). PASKitCore is right: no vendor dependency, no persistence dependency — the store stays entirely on the app side, exactly as `PASAppGroupContainer` is store-engine agnostic.

**What the app injects.** The format enum, the filename stem, the serializers, and the record sequence. PASKit would own the file lifecycle, the escaping and the progress cadence.

**Second-app evidence.** **None — single app today.** CCT holds a year of food and body data and offers no export at all; XueTang has an *import* parser (`Core/Utilities/VocabImportParser.swift`) but no export. A "download my data" control is a plausible near-term ask for both, but neither has it.

**Effort.** M.

**Recommendation.** **Extract when a second app needs it.** The mechanism is genuinely generic and unusually well-tested (`WorkoutAppTests/ExportFormattingTests.swift`, `DataExportAdversarialTests.swift`), and the file split is already clean along the exact seam an extraction would cut — so the lift stays M rather than growing. Building it into PASKit before CCT or XueTang has an export screen would be speculative by the letter of the rule. Revisit the moment either app files that feature.

---

### 8. History-derived weekly streak walker → `PASKitCore/Streak` (later)

**What it is.** `WorkoutApp/WorkoutApp/Core/Utilities/WorkoutStreak.swift:24-111` — `weeks(now:firstWeekday:maxLookback:hasSession:)`, a backward walk counting consecutive calendar weeks with at least one session, with a grace week for an in-progress current week (`:45-52`); and `longestRun(in:firstWeekday:maxWeeks:hasSession:)`, the forward retrospective walk over a closed interval with no grace week (`:78-111`).

**Why it is mechanism, not vocabulary.** Both are pure functions taking a `hasSession` closure — the type has no store dependency by design (`:4-6`), and the word "workout" appears only in its name. The two grace-week policies are the interesting part and are calendar reasoning, not fitness reasoning.

**Proposed home.** `Sources/PASKitCore/Streak/PASStreakScan.swift`, alongside `PASStreakEngine`. It is a genuinely different mechanism, not a duplicate: `PASStreakEngine` is *daily* and *stateful* (the app persists `PASStreakState` and calls `rolledOver` / `recordingActivity`), whereas this *derives* a streak from history with no persisted state and at *week* granularity. The two compose rather than compete, and Core already owns `Date.pasStartOfWeek()` / `pasIsSameWeek(as:)` — this would build on them instead of the local `Calendar(identifier: .gregorian)` construction at `:30-32`.

**What the app injects.** `firstWeekday` (WorkoutApp passes its own week-start setting), the reference date or interval, and the `hasSession` predicate.

**Second-app evidence.** **None — single app today.** XueTang tracks streaks (`Core/State/ProgressStore.swift`, `Core/Utilities/StreakFreezeCopy.swift`) but daily and stateful — the case `PASStreakEngine` already serves. CCT tracks no streak.

**Effort.** S — ~60 lines of extractable logic plus tests.

**Recommendation.** **Extract when a second app needs it.** Small and clean, and it fills a real gap next to `PASStreakEngine`, but a weekly history-derived streak has exactly one consumer. Adding it now would be building a second streak API for an audience of one.

---

### 9. Live Activity controller → `PASKitLifecycle/LiveActivity` (later)

**What it is.** `WorkoutApp/WorkoutApp/Core/Services/WorkoutLiveActivityController.swift:8-90` — owns the `Activity` object and all ActivityKit lifecycle: `endStale()` sweeping activities orphaned by a force-quit (`:21-27`), `start` gated on `ActivityAuthorizationInfo().areActivitiesEnabled` with a rolling stale date (`:29-44`), a soft `update` (`:47-53`), an end-and-restart that first ends *all* activities to prevent orphans (`:57-82`), and `end()`. The `nonisolated deinit` at `:16` carries a real workaround note (the MainActor isolated-deinit back-deploy shim double-frees under the iOS 26.0 simulator runtime).

**Why it is mechanism, not vocabulary.** The only app-specific thing in the file is the concrete `WorkoutActivityAttributes` type parameter; every method body is ActivityKit protocol. Making it `PASLiveActivityController<Attributes: ActivityAttributes>` is a mechanical change — the vocabulary (`Core/Model/WorkoutActivityAttributes.swift:4-21`, the `ContentState` fields and the widget UI in `WorkoutAppLiveActivity/`) stays entirely in the app.

**Proposed home.** `Sources/PASKitLifecycle/LiveActivity/PASLiveActivityController.swift`. Lifecycle is the right module — it already owns app-lifecycle presentation surfaces — and ActivityKit is a system framework, so no new dependency. One fix on the way in: the two `print(...)` calls at `:41` and `:78` become `PASLogger.make(category:)`.

**What the app injects.** The `ActivityAttributes` type, the attributes and `ContentState` values, the relevance score, and the stale interval (currently hard-coded to four hours at `:11`).

**Second-app evidence.** **None — single app today.** A repo-wide grep for `ActivityKit` / `ActivityAttributes` across CCT and XueTang returns nothing.

**Effort.** S — one generic parameter and a logger swap.

**Recommendation.** **Extract when a second app needs it.** The generalisation is nearly free, which is exactly why there is no cost to waiting: the day XueTang wants a lesson-timer Live Activity, this lifts in an afternoon. Note it in `docs/PASKitLifecycle.md` as a known candidate so it is not rewritten from scratch.

---

### 10. One-shot audio cue player (`RestEndSound`) → leave local

**What it is.** `WorkoutApp/WorkoutApp/Core/Services/RestEndSound.swift:13-51` — configures `AVAudioSession` as `.playback` with `[.mixWithOthers]` (no ducking, so Spotify neither pauses nor dips), plays a bundled wav, holds the player strongly so it cannot dealloc mid-play (`:15-16`), and deactivates the session with `.notifyOthersOnDeactivation` from the player delegate when the clip finishes (`:41-44`).

**Why it is (partly) mechanism.** The session activate → play → deactivate scope is protocol; the file's real value, though, is the *policy decision* — `.mixWithOthers` rather than `.duckOthers`, plus the foreground-only gate documented at `:6-11` that keeps this from double-dinging with `RestEndNotifier`'s notification sound. Policy is vocabulary.

**Second-app evidence.** XueTang's `Core/Services/AudioService.swift` runs the same session lifecycle at `:231` and `:246` — `setCategory` → `setActive(true)` → … → `setActive(false, options: [.notifyOthersOnDeactivation])` — but with the *opposite* policy (`.playback, mode: .spokenAudio, options: [.duckOthers]`, because there the audio *is* the exercise) and a completely different payload (a clip library plus `AVSpeechSynthesizer` fallback, per-syllable scheduling, interruption observation). The shared surface is about six lines.

**Effort.** S.

**Recommendation.** **Leave local.** A `PASAudioSession.playCue(url:policy:)` would be six lines of body wrapping a policy enum whose two members are each used by exactly one app. That is a worse API than either local version and it would tempt the next app to pick a policy from a menu instead of reasoning about ducking. Revisit only if a third app needs a one-shot cue.

---

## Should stay local

- **Theme layer — `ViewComponents/ViewModifiers/CardStyle.swift:3-22`, `WarmSurfaceListModifier.swift:6-20`, `TrackedLabel.swift:3-16`, `SegmentedCapsulePicker.swift:9-44`, `ThemedButton.swift`, `PillButton.swift`, `ThemedCard.swift`, `Core/Theme/AppColors.swift`, `AppTheme.swift`, `AppTypography.swift`, `HeatmapScales.swift`.** These are token consumers — `Color.surfaceCard`, `AppTheme.Radius.medium`, `Color.brandPrimary`, a hard-coded `Color("CardBorder")`. PASKit deliberately owns no design layer; the brand-free mechanisms underneath these (`Color(light:dark:)`, `Font.pasScaled`, `Animation.respectingReducedMotion`, `.pasPressable()`) already ship, and `SegmentedCapsulePicker` in particular is a look, not a behaviour — a generic version would be `Picker` with extra steps.

- **`Core/Services/ExerciseSearch.swift` (`ExerciseSearchNormalizer`).** Tempting: the tokenizer at `:172-186` (diacritic-fold → lowercase → strip apostrophes → split on non-alphanumerics → synonym-expand → stopword-filter) is genuinely generic, and `stripPlural` at `:204-216` is pure English morphology. But the file is 216 lines of which the synonym table (`:18-110`) and its commentary are the substance — gym slang, German gym vocabulary, corpus-spelling decisions, and the asymmetric index/query token rule at `:149-161` that exists because of how *this* corpus spells "pulldown". English plural stripping is itself a vocabulary choice, not a mechanism: XueTang searches hanzi and pinyin, CCT searches food names server-side via OpenFoodFacts. No second app has a bundled-corpus search, and a `PASSearchTokenizer(synonyms:stopWords:)` extracted today would serve exactly one caller while making its subtle index/query asymmetry someone else's problem to rediscover.

- **`Features/Home/Models/GettingStartedChecklist.swift:6-30`.** Reads like a generic activation checklist, but every field is a domain fact (`hasActivePlan`, `hasBodyMeasurement`), and the whole value of `shouldShow(mode:dismissed:requested:)` is its precedence order, which encodes a product decision about this app's guided mode. Pure vocabulary.

- **`Core/Services/Milestones.swift`.** Only `highestCrossed(before:after:landmarks:)` is mechanism, and it is about six lines. Everything else — the landmark arrays at `:36-40`, the `Kind.priority` ordering at `:19-25` and its justification, the SF Symbols and copy — is product judgement. A public `PASThresholdCrossing` helper would be a smaller API than the doc comment explaining when to use it.

- **`Core/Services/DataStore.swift` revision-token caching (`:33-56`).** The "bump a counter on write, cache the expensive full-table decode against it, keep the cache `@ObservationIgnored` so writing it during a view body doesn't re-enter the SwiftUI update" pattern is real and reusable in principle. In practice it is about fifteen lines that only make sense fused to a specific store's fetch methods; a generic `PASRevisionCache` would need the store injected, which is more ceremony than the fifteen lines it replaces. Leave it, and note the pattern in the app's `ARCHITECTURE.md` instead.

- **`Core/Services/BodyMapSnapshotCache.swift:16-97`.** A cost-bounded FIFO image cache with memory-warning eviction — but it exists *only* to work around the vendored `MuscleMap` package re-parsing 111 SVG paths on every draw (`:8-14`), it is keyed on an app-specific `BodyMapSnapshotKey`, and the generic half of it overlaps candidate 4. Extract the bundled-image loader; leave this one welded to the package defect it patches.

- **`Core/Services/RestEndHaptics.swift:9-18`.** Not a candidate at all — three heavy impacts 350 ms apart, hand-rolled with a `Task.sleep` chain, is `Haptics.play(.triplePulse)` in `PASKitCore` today (`Sources/PASKitCore/Haptics/PASHapticSequence.swift:66`). This is adoption debt, not extraction; see below.

- **`Core/Model/Persistence/PersistedMuscleAttributionMigration.swift`.** A one-time idempotent backfill, which sounds like a reusable migration mechanism — but it is a hard-coded list of ~60 corrupted corpus record ids with 200 lines of per-id justification. There is no mechanism here to lift.

- **`Core/Services/ChartPreferences.swift:12-60`.** An ordered, id-deduped, UserDefaults-persisted list of user-pinned items — arguably generic. But once WorkoutApp adopts `PASSettingsStore` + `@PASDefault` (below), what remains is `add` / `remove` / `move` / `contains` over an array, about twenty lines with an app-specific `id` rule (`:37-42` explains why identity is by `id` and not `==`, which is a `ChartMetricType` fact). Generalising would produce a worse API than the local version.

---

## Already in PASKit — adopt, don't extract

Not extraction candidates, but the largest single finding of this audit: WorkoutApp imports PASKit in 23 files yet ships parallel local copies of six APIs it already has. Each is deletion work.

| Local code | Already in PASKit |
|---|---|
| `ViewComponents/ViewModifiers/AppRatingModifier.swift:5-17` — declares `View.presentAppRating(initialCondition:askLaterCondition:)`, in a file that *imports PASKit* | `Sources/PASKitLifecycle/Rating/View+PresentAppRating.swift:24` — the same function name and signature |
| `ViewComponents/StoryCardRenderer.swift:12-42` (whose own doc at `:5-10` admits it is a duplicate of a private pipeline in `WorkoutShareSheet`) and `Features/ActiveWorkout/Views/ViewComponents/WorkoutShareSheet.swift:230-341` — hand-rolled `ImageRenderer`, `instagram-stories://` pasteboard hand-off, `UIActivityViewController` scene-walking | `PASKitSharing` — `PASShareCard.render`, `PASInstagramStories.share` / `.copySticker`, `PASShareItems` + `PASActivitySheet`. Three byte-identical-by-construction copies of the same pipeline exist in the app today |
| `Core/Model/AppSettings.swift` — 361 lines of `access(keyPath:)` / `withMutation` / `UserDefaults.standard` boilerplate, roughly 25 lines per setting, including the hand-written "absent key must default to true" dance at `:35-45` and `:54-64` | `PASSettingsStore` + `@PASDefault` — one line per setting, with the declared value as the default and optionals for absent keys |
| `Features/Onboarding/OnboardingViewModel.swift:33-56` (`currentStepIndex`, `NavigationDirection`, `visibleSteps`) and `Features/Onboarding/OnboardingView.swift:26-38` (hand-built asymmetric move/opacity transition) plus its own draft-save on `scenePhase` | `PASOnboardingFlow` (including the conditional-steps closure form), `View.pasOnboardingTransition(step:direction:)`, `PASOnboardingProgressBar`, and `PASDraft` for resume-after-kill |
| `Core/Services/RestEndHaptics.swift:9-18` — three heavy impacts via a `Task.sleep` chain | `Haptics.play(.triplePulse)` — the integration guide explicitly names "multi-step patterns — presets or custom sequences, not `Task.sleep` chains" |
| `App/WorkoutAppApp.swift` — no dev overlay; `Core/Services/DataStoreMockData.swift` is reached through ad-hoc `#if DEBUG` | `View.pasDevelopmentOverlay { PASDevelopmentMenu { … } }` |

Clearing this list would delete several hundred lines from the app, and it matters beyond line count: `presentAppRating` is currently declared twice in the same compilation unit's namespace, and the sharing pipeline is duplicated three ways inside one app — the exact drift the integration contract's rule 7 ("don't reinvent what PASKit owns") is written to prevent.
