# WorkoutApp — what can be deleted and replaced by PASKit

**Date:** 2026-09-04 · **PASKit audited:** working tree at `95cef5a` (`v0.3.0-16-g95cef5a`, the v0.3.1 line; the app's SPM pin is `upToNextMinorVersion` from `0.3.0`, so 0.3.1 resolves without a manifest edit) · **App:** `WorkoutApp` branch `develop` @ `b53dfd9`

---

## Summary

WorkoutApp is already a heavy PASKit consumer — analytics, purchases, notification plumbing, the whole release-notes stack (`WhatsNewGate` / `WhatsNewView` / `ChangelogView`), Liquid Glass, and `AppInfo` are all on the package, and the release-notes migration left nothing behind. What remains is concentrated in three places. The largest is the **share/export pipeline**: `WorkoutShareSheet` and `StoryCardRenderer` between them hand-roll `ImageRenderer`, the Instagram Stories pasteboard payload, the `UIActivityViewController` window-walk, the scaled card preview and the transparency checkerboard — five types PASKitSharing already ships, two of them byte-for-byte. The second is **`AppSettings`**: 361 lines of `access(keyPath:)` / `withMutation` / `UserDefaults` triads that `PASSettingsStore` + `@PASDefault` collapse to roughly 25 declarations, with every key preserved verbatim — except four properties that encode "unset" as a stored `0`, which must keep their hand-rolled readers or they will silently resurrect cleared rest-timer overrides and fat-loss goals for installed users. The third is a scatter of small exact duplicates: `RestEndHaptics` is literally `PASHapticSequence.triplePulse` (whose PASKit doc comment already reads "workout-app timing"), `ScaleButtonStyle` is `PASPressableButtonStyle`, the onboarding draft box is `PASDraft`, and eleven `reduceMotion ? nil : …` ternaries are `Animation.respectingReducedMotion`. Two findings are blocked on PASKit, not on the app: the local `AppRatingModifier` cannot move until PASKit's Rating module accepts a persisted-key override (the app already shipped `isRatingInteractionComplete`), and `RestEndNotifier` cannot move until `PASNotificationRequest` can carry a custom sound file name — its `rest_complete.wav` is load-bearing for the app's single-ding design. The app is English-only today (`knownRegions = en`, a 742-key `Localizable.xcstrings` with one locale), so PASKit's verbatim-string policy costs nothing right now, but every PASKit view adopted is a surface whose copy can never enter that catalog.

| # | Finding | PASKit equivalent | Fit | Effort | Recommendation |
|---|---------|-------------------|-----|--------|----------------|
| 1 | `WorkoutShareSheet` render / Instagram / activity-sheet / preview / checkerboard pipeline | `PASShareCard`, `PASInstagramStories`, `PASActivitySheet`, `PASScaledCardPreview`, `PASTransparencyCheckerboard` (PASKitSharing) | close | M | Adopt now |
| 2 | `AppSettings` observable-UserDefaults boilerplate | `PASSettingsStore` + `@PASDefault` (PASKitCore) | close | M | Adopt now — keep the four 0-sentinel readers hand-rolled |
| 3 | `StoryCardRenderer` | `PASShareCard.render` + `PASActivitySheet.present` | exact | S | Adopt now |
| 4 | `AppRatingModifier` (local copy shadowing PASKit's) | `View.presentAppRating` (PASKitLifecycle) | close | S | Adopt once PASKit's Rating takes key + copy overrides |
| 5 | `RestEndHaptics` | `Haptics.play(.triplePulse)` (PASKitCore) | exact | S | Adopt now |
| 6 | `RestEndNotifier` | `PASNotifications` + `PASNotificationRequest` | partial | S | Adopt once `PASNotificationRequest` carries a custom sound name |
| 7 | `UnitConvert.clockDuration` + 4 inline `min:sec` copies | `PASDurationFormat.clock` | partial | S | Adopt for the timer shapes; leave `labeledDuration` |
| 8 | `ScaleButtonStyle` | `.buttonStyle(.pasPressable())` | exact | S | Adopt now |
| 9 | Onboarding draft save/load/clear | `PASDraft<Draft>` (PASKitCore) | exact | S | Adopt now |
| 10 | 11 × `reduceMotion ? nil : AppTheme.Motion.x` | `Animation.respectingReducedMotion(_:)` / `View.pasAnimation` | exact | S | Adopt now |
| 11 | `CircularProgress` | `PASProgressRing` (PASKitLifecycle) | partial | M | Leave |
| 12 | `OnboardingViewModel` step machine | `PASOnboardingFlow` | partial | L | Leave |

---

## Findings

### 1. `WorkoutShareSheet`'s render / share / preview pipeline

**App code**
- `WorkoutApp/Features/ActiveWorkout/Views/ViewComponents/WorkoutShareSheet.swift:289-339` — `renderImage(for:)`, three `ImageRenderer` blocks (scale 3.0, `proposedSize`, `isOpaque`, `.environment(\.colorScheme, .dark)` injection).
- `:246-268` — `openStoryInInstagram(image:fallbackStyle:)`: `pngData()`, the `com.instagram.sharedSticker.backgroundImage` pasteboard item, the 300-second `.expirationDate`, `instagram-stories://share?source_application=studio.pocketapps.WorkoutApp`, and the not-installed fallback.
- `:270-287` + `:341-349` — `shareViaActivity(style:)` and `presentActivityVC(_:)`: `UIActivityViewController` plus the `connectedScenes` → `rootViewController` → `presentedViewController` walk.
- `:461-487` — `private struct ScaledCardPreview`.
- `:491-513` — `private struct TransparencyCheckerboard`.
- `:238-239` — `UIPasteboard.general.image = image` + `UINotificationFeedbackGenerator().notificationOccurred(.success)` for the sticker-copy flow.

**PASKit equivalent** — `PASShareCard.render(_:size:scale:opaque:colorScheme:)`, `PASInstagramStories.share(background:sticker:sourceApplication:)` and `.copySticker(_:)`, `PASActivitySheet.present(items:onComplete:)`, `PASScaledCardPreview`, `PASTransparencyCheckerboard`, `Haptics.play(.success)` — all `PASKitSharing` / `PASKitCore`. The file already does `import PASKit`.

**Fit — close.** `PASTransparencyCheckerboard` (`Sources/PASKitSharing/PASTransparencyCheckerboard.swift:28-49`) is byte-identical to the app's copy including the `0.06` / `0.12` white opacities and the `Color.black.opacity(0.5)` backing. `PASScaledCardPreview` (`:58-70`) is identical except the app adds `.shadow(color: .black.opacity(0.5), radius: 24, y: 12)` to the clipped card — recoverable by putting `.shadow(...)` on the `PASScaledCardPreview` call (the container is transparent, so the shadow still traces the card's alpha). Three real differences to handle:
1. `PASShareCard.render` wraps the card in `.frame(width:height:)` *in addition to* `proposedSize`; the app sets `proposedSize` only. For the two 1080×1920 story cards this is a no-op, but `WorkoutStickerCard` is rendered at its own `canonicalSize` and must be eyeballed once after the swap.
2. `PASInstagramStories.share` defaults `source_application` to `AppInfo.bundleIdentifier`. That resolves to `studio.pocketapps.WorkoutApp` — the same literal hard-coded at `:249` — so pass nothing.
3. `PASInstagramStories.copySticker` writes a `UTType.png` pasteboard item with a 5-minute expiry; the app's `UIPasteboard.general.image = image` writes a non-expiring image item. Behaviourally equivalent for the paste-into-Instagram flow, but it *is* a different pasteboard representation.

**Risk** — No persisted keys. User-visible surface: the story/weekly/sticker images themselves and the share sheet. The `.environment(\.colorScheme, .dark)` injection at `:314` is load-bearing (`VolumeStatus` band colours and `MuscleBodyMap.mmDefaultFill` resolve light without it) — it maps to `colorScheme: .dark` on `render`, do not drop it. The app is dark-only (`preferredColorScheme(.dark)` at `WorkoutAppApp.swift:60`), so a missed injection would show up as a washed-out card, not a crash. No localization impact: all five PASKit types are chrome-free.

**Effort — M.** ~130 lines deleted across one file. Mechanical, but three card shapes × three share routes means a real visual pass (story, weekly, sticker; Instagram-installed, Instagram-missing, activity sheet) before merging.

**Recommendation — adopt now.** This is the single largest duplication left, and the app already links the module.

---

### 2. `AppSettings` — 361 lines of observable-UserDefaults boilerplate

**App code** — `WorkoutApp/Core/Model/AppSettings.swift:1-361`. Twenty stored settings, each an `access(keyPath:)` / `withMutation(keyPath:)` / `UserDefaults.standard` triad, plus five derived computed properties (`guidanceMode:204`, `isGuided:209`, `guidancePreference:215`, `effectiveTrainingYears:277`, `customRest(for:)`/`setCustomRest`/`resetCustomRestDurations`:340-360).

**PASKit equivalent** — `PASSettingsStore` + `@PASDefault` + `UserDefaultsStorable` (`Sources/PASKitCore/Settings/`). Subclass `PASSettingsStore`, one `@PASDefault("key") var x = default` line per setting, empty `UserDefaultsStorable` conformances on `WeightUnit`, `LengthUnit`, `WeekStart`, `TrainingGoal`, `WarmupScheme`, `Difficulty`, `GuidanceMode`. The five derived properties stay as ordinary computed properties on the subclass and need no change.

**Fit — close, per property.**

*Exact — 16 of 20:*
- Bools defaulting to `false` (`advancedMuscles:5`, `effortLoggingEnabled:19`, `hasCompletedOnboarding:67`, `gettingStartedDismissed:223`, `gettingStartedManuallyRequested:238`) → `@PASDefault("advancedMuscles") var advancedMuscles = false`. `Bool.readValue` uses `object(forKey:) as? Bool`, so absent-key → declared default, matching `UserDefaults.bool(forKey:)`'s implicit `false`.
- Bools defaulting to `true` that today hand-write the `object(forKey:) != nil` guard (`weeklyRecapNotificationsEnabled:35`, `includeHealthWorkouts:54`) → `@PASDefault(...) var x = true`. The guard *is* what `@PASDefault` does; these two are the cleanest wins in the file.
- Raw-enum settings (`weightUnit:79`, `lengthUnit:96`, `weekStart:112`, `trainingGoal:128`, `warmupScheme:141`, `fitnessLevel:154`) → `@PASDefault` with the same default expression. An unparseable stored raw falls back to the declared default in both implementations.
- `guidanceModeOverride: GuidanceMode?` (`:182`) → `@PASDefault("guidanceModeOverride") var guidanceModeOverride: GuidanceMode?`. `Optional: UserDefaultsStorable` writes `nil` as `removeObject`, exactly the branch at `:193`.
- `trainingYears: Int?` (`:257`) → `@PASDefault("trainingYears") var trainingYears: Int?`. It already uses `object(forKey:) as? Int` + `removeObject`, which is `@PASDefault`'s optional semantics verbatim — and the doc comment at `:250-256` explains why it deliberately avoids the 0-sentinel. This one is a genuine exact match.

*Close with one caveat — 1:* `weeklyFrequency` (`:167`) reads `integer(forKey:)` then `val > 0 ? val : 4`. `@PASDefault("weeklyFrequency") var weeklyFrequency = 4` differs only if the key exists holding `0`; the only writer is a `Stepper(in: 1...7)` (`SettingsView.swift:84`) and onboarding, so `0` is unreachable.

*Must NOT move — 4:* `targetBodyFatPercent` (`:283`), `customRestSmall` (`:301`), `customRestMedium` (`:314`), `customRestLarge` (`:327`). All four encode "unset" by **writing `0`**, not by removing the key (`UserDefaults.standard.set(newValue ?? 0, forKey:)`). Every installed user who ever set and then cleared a rest-timer override or a fat-loss goal has the key present holding `0`. `@PASDefault Int?` would read that as `.some(0)` and return `0` instead of `nil` — resurrecting a 0-second rest timer and a 0 % body-fat goal. Keep these four as hand-rolled computed properties on the `PASSettingsStore` subclass (they can still live in the same class), or migrate the stored values first in a separate, deliberate change.

**Risk — persisted keys are the whole story here.** Every key must be passed to `@PASDefault` **verbatim**: `advancedMuscles`, `effortLoggingEnabled`, `weeklyRecapNotificationsEnabled`, `includeHealthWorkouts`, `hasCompletedOnboarding`, `weightUnit`, `lengthUnit`, `weekStart`, `trainingGoal`, `warmupScheme`, `fitnessLevel`, `weeklyFrequency`, `guidanceModeOverride`, `gettingStartedDismissed`, `gettingStartedManuallyRequested`, `trainingYears` (plus the four sentinel keys left in place: `targetBodyFatPercent`, `customRestSmall`, `customRestMedium`, `customRestLarge`). No `paskit.` prefixing — these are the app's shipped vocabulary.

Two further behaviour notes. (a) **Observation granularity coarsens.** Today each property has its own `access(keyPath:)`, so a view reading only `weightUnit` does not invalidate when `advancedMuscles` flips. `PASSettingsStore` registers per-store, so any settings write invalidates every observer — including `ActiveWorkoutView`, which reads `settings.weightUnit` and is the app's heaviest view; `effortLoggingEnabled` is toggleable mid-workout from the gear button (`WorkoutSettingsSheet`). PASKit's own README calls per-store granularity "imperceptible at settings scale", and it almost certainly is here, but it is a real change and worth one profiling pass on the active-workout screen. (b) **Locale-derived defaults freeze at init.** `weightUnit` / `lengthUnit` / `weekStart` currently re-evaluate `Locale.current` / `Calendar.current` on every read while the key is absent; `@PASDefault` captures the declared default once per store instance. Since `AppSettings` is constructed once in `WorkoutAppApp.init` (`:28`) and onboarding writes a real value early, this is theoretical — but it is not identical.

**Effort — M.** ~361 lines → ~60 (25 declarations + 4 retained sentinel properties + 5 derived). Call sites do not change at all: `SettingsViewModel`, `SettingsView`'s `@Bindable`, `ActiveWorkoutManager.configure(settings:)` and the `.environment(settings)` injection all keep working, because the subclass keeps the same property names. `SettingsViewModelTests` / `WorkoutDefaultsPersistenceTests` gain a free win — `PASSettingsStore(defaults:)` lets them inject a suite instead of touching `.standard`.

**Recommendation — adopt now**, in one commit, with the four 0-sentinel properties explicitly left hand-rolled and a comment saying why.

---

### 3. `StoryCardRenderer`

**App code** — `WorkoutApp/ViewComponents/StoryCardRenderer.swift:11-43`. `canonicalSize` (`:13`), `image(size:scale:content:)` (`:19-25`), `presentShareSheet(image:onComplete:)` (`:29-42`). Callers: `WorkoutApp/Features/Home/Views/WrappedView.swift:60-61, 65, 94, 97`.

**PASKit equivalent** — `PASShareCard.render(_:size:scale:opaque:colorScheme:)` and `PASActivitySheet.present(items:onComplete:)` (PASKitSharing).

**Fit — exact.** The file's own header (`:5-10`) documents it as a copy: *"`WorkoutShareSheet` … already has this exact pipeline … the two pipelines are byte-identical by construction, not by shared code."* `image(...)` is `render(..., colorScheme: .dark)`; `presentShareSheet` is `PASActivitySheet.present`, and PASKit's version is strictly better — it prefers the `foregroundActive` scene over `connectedScenes.first` and configures the iPad popover anchor, both of which the app's copy omits. `canonicalSize` becomes a local `CGSize(width: 1080, height: 1920)` constant in `WrappedView` (or reuse the same literal the share sheet uses).

**Risk** — No persisted keys, no strings. The scene-selection improvement is a behaviour *change*: on a multi-scene iPad the sheet would now present over the active window rather than `connectedScenes.first`. That is a fix, not a regression.

**Effort — S.** Delete one 43-line file, edit five lines in `WrappedView`.

**Recommendation — adopt now**, ideally in the same commit as finding 1 so the app ends with exactly one share pipeline.

---

### 4. `AppRatingModifier` — a local copy that shadows PASKit's

**App code** — `WorkoutApp/ViewComponents/ViewModifiers/AppRatingModifier.swift:1-67`. Declares `extension View { func presentAppRating(initialCondition:askLaterCondition:) }` (`:5-17`) with the **same signature** as PASKit's, in a file that already does `import PASKit` (`:3`). Same-module extensions win overload resolution, so `ContentView.swift:56-63`'s `.presentAppRating(...)` is silently binding to the local copy, not the package's.

**PASKit equivalent** — `View.presentAppRating(initialCondition:askLaterCondition:)`, `Sources/PASKitLifecycle/Rating/View+PresentAppRating.swift:12-77`. Structurally the same modifier: same `.task` gate, same three-button first alert, same two-button follow-up, same `@Environment(\.requestReview)`.

**Fit — close, but blocked on two hard-coded values in PASKit.**
1. **Persisted keys.** App: `@AppStorage("isRatingInteractionComplete")` and `@AppStorage("isInitialPromptComplete")` (`:24-25`). PASKit: `@AppStorage("paskit.appRating.isComplete")` and `"paskit.appRating.isInitialPromptShown"` (`Rating/View+PresentAppRating.swift:42-43`), with **no init parameter to override them**. Adopting as-is re-prompts every installed user who already tapped "Never Ask Again", and re-prompts everyone parked in the "Ask Later" state.
2. **Copy.** App: title `"Enjoying \(AppInfo.displayName)?"`, buttons `"Yes, Rate It!"` / `"Ask Later"` / `"Never Ask Again"` / `"No Thanks"`, plus a `message:` body (`:41-65`). PASKit: fixed `"Would you like to rate the app?"`, `"Yes, Continue!"` / `"Nope"`, and no message. Not parameterised.

**Risk** — This is the highest-risk item in the audit and the one with the clearest user-visible cost. Persisted keys: `isRatingInteractionComplete`, `isInitialPromptComplete` — both already shipped. Behaviour: swapping today loses the app-name-personalised prompt and the explanatory message, and resets the one-shot state for the entire installed base. Localization: the app's copy currently sits in Swift source and could be moved into `Localizable.xcstrings`; PASKit's cannot.

**Effort — S** on the app side (delete 67 lines), **S–M** on the PASKit side (add `lastSeenKeys`/copy parameters). The precedent already exists in the same module: `WhatsNewGate` takes `lastSeenBuildKey:` and `legacyVersionKey:` for exactly this reason, and `ContentView.swift:12-15` uses both.

**Recommendation — adopt once PASKit changes X.** Extend `presentAppRating` with (a) overridable `@AppStorage` keys and (b) a title / message / button-title configuration, mirroring `WhatsNewGate`'s key-override precedent and `WhatsNewView`'s slot precedent. Until then the local copy is correct and should stay — but rename it (`presentWorkoutAppRating`) so the shadowing is deliberate rather than accidental, because today a reader of `ContentView` cannot tell which implementation runs.

---

### 5. `RestEndHaptics`

**App code** — `WorkoutApp/Core/Services/RestEndHaptics.swift:9-18`. `UIImpactFeedbackGenerator(style: .heavy)`, `prepare()`, then a `Task` firing three impacts with `Task.sleep(for: .milliseconds(350))` between them.

**PASKit equivalent** — `Haptics.play(.triplePulse)`, `Sources/PASKitCore/Haptics/PASHapticSequence.swift:65-70`.

**Fit — exact.** PASKit's preset is `[Step(.heavy, delay: 0), Step(.heavy, delay: 0.35), Step(.heavy, delay: 0.35)]`, documented at `:65` as *"Timer finished: three heavy pulses 350 ms apart. (workout-app timing)"* — it was extracted from this exact code and the local original was never deleted. `Haptics.play(_ sequence:isEnabled:)` is also fire-and-forget on a `@MainActor Task`, matching the current shape.

**Risk** — None. No persisted keys, no strings, no visual surface. The app has no user-facing haptics toggle, so `isEnabled` takes its `true` default; if one is ever added, `Haptics.play(.triplePulse, isEnabled: settings.hapticsEnabled)` is the one-line upgrade.

**Effort — S.** Delete a 19-line file; replace the single call site in `ActiveWorkoutManager` with `Haptics.play(.triplePulse)`.

**Recommendation — adopt now.** This is the clearest "PASKit already owns this" case in the app.

---

### 6. `RestEndNotifier`

**App code** — `WorkoutApp/Core/Services/RestEndNotifier.swift:14-54`. Raw `UNUserNotificationCenter`: `UNMutableNotificationContent`, `UNTimeIntervalNotificationTrigger`, `UNNotificationRequest`, the opportunistic `notDetermined` → `requestAuthorization` at `:44-45`, and `removePendingNotificationRequests` at `:53`. It is the last raw `UserNotifications` usage in the app — its sibling `WeeklyRecapNotifier.swift` is already fully on `PASNotifications`.

**PASKit equivalent** — `PASNotifications.shared.schedule(PASNotificationRequest(id:title:body:trigger:))` with `.interval(_, repeats: false)`, `.cancel(ids:)`, `.authorizationStatus` / `.requestAuthorization()`.

**Fit — partial, blocked on one field.** Identifier (`"workout-rest-timer-end"`), title/body, the interval trigger, `max(1, …)` clamping (PASKit clamps too) and cancel-by-id all map one-for-one. The blocker is line `:36`: `content.sound = UNNotificationSound(named: UNNotificationSoundName("rest_complete.wav"))`. `PASNotificationRequest.sound` is a **`Bool`** (`Sources/PASKitNotifications/PASNotificationRequest.swift:25-26, 44`) — default sound or silence, no custom file name. The custom clip is not cosmetic here: the file's own doc comment (`:22-26`) explains it is deliberately the same bundled clip as the in-app `RestEndSound` cue, so the alert sounds identical whether the notification or the foreground cue plays. Routing this through PASKit today would change the sound users hear at the end of every rest period.

**Risk** — No persisted keys. User-visible (audible) behaviour is the whole risk, and it interacts with a documented double-ding fix spanning `RestEndSound`, `RestEndNotifier` and `WorkoutAppApp.swift:105`'s `foregroundPresentation: [.banner]`. Do not touch this triangle piecemeal.

**Effort — S** on the app side once unblocked; **S** on the PASKit side (widen `sound` to an enum: `.none` / `.default` / `.named(String)`).

**Recommendation — adopt once PASKit changes X.** Add a custom-sound case to `PASNotificationRequest`, then migrate — at which point the app has zero raw `UserNotifications` code and every notification flows through one facade, which is the point of the module.

---

### 7. Duration formatting

**App code**
- `WorkoutApp/Core/Enums/UnitSystem.swift:186-189` — `UnitConvert.clockDuration(_:)`, `String(format: "%d:%02d", seconds / 60, seconds % 60)`.
- `WorkoutApp/Core/Enums/UnitSystem.swift:177-184` — `UnitConvert.labeledDuration(_:)`, `"45 sec"` / `"2 min"` / `"2:30 min"`.
- Four inline re-implementations of the same `min`/`sec` split: `ActiveWorkoutManager.swift:463-466` (`restTimerText`), `ActiveWorkoutManager.swift:477-479` (`durationText`), `ActiveWorkoutView.swift:604-608` (`restTimerFormatted`), `TrainingGoalView.swift:125-130` (`formatRestTime`).
- Two thin pass-throughs that already delegate: `RestTimerSettingsView.swift:164-166`, `ExerciseEditorRow.swift:273-276`, `ValuePickerType.swift:160-162`.

**PASKit equivalent** — `PASDurationFormat.clock(seconds:)` and `.compact(seconds:)` (`Sources/PASKitCore/Time/PASDurationFormat.swift`).

**Fit — partial, and the difference is user-visible.** `PASDurationFormat.clock` rolls over into hours: 3852 s → `"1:04:12"`. `UnitConvert.clockDuration` never does: 3852 s → `"64:12"`. For rest timers (capped at 600 s by `RestTimerSettingsView.swift:160`) the two are identical and the swap is free. For `ActiveWorkoutManager.durationText` — the running workout clock — they diverge for any session over an hour, which is common: a 90-minute workout currently reads `"90:00"` and would read `"1:30:00"`. That is arguably the better rendering, but it is a change to the most-looked-at number on the active-workout screen and should be a deliberate decision, not a refactoring side effect. `labeledDuration`'s `"2:30 min"` shape has no PASKit equivalent (`compact` produces `"2m 30s"`) — leave it.

**Risk** — No persisted keys. User-visible: the workout clock and the Live Activity, which reads the same manager. No localization impact (both are digit-only formats).

**Effort — S.** Replace `clockDuration`'s body with `PASDurationFormat.clock(seconds:)` and point the four inline copies at it. The `min > 0 ? … : "\(sec)s"` variants (`ActiveWorkoutManager.swift:466`, `ActiveWorkoutView.swift:607`) keep their sub-minute branch and call PASKit only for the ≥ 60 s case.

**Recommendation — adopt now for the rest-timer sites** (`restTimerText`, `restTimerFormatted`, `formatRestTime`, `clockDuration`); **decide separately** on `durationText`, where the hour rollover is a product call. Leave `labeledDuration`.

---

### 8. `ScaleButtonStyle`

**App code** — `WorkoutApp/ViewComponents/ThemedButton.swift:69-75`. Applied at `:43` (inside `ThemedButton`); no other call site.

**PASKit equivalent** — `PASPressableButtonStyle` / `.buttonStyle(.pasPressable())`, `Sources/PASKitCore/Styling/PASPressableButtonStyle.swift:35-43`.

**Fit — exact.** Both do `scaleEffect(isPressed ? 0.96 : 1)` with `.animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)`. The constants match to the digit. PASKit adds an optional press-down haptic, which the app can ignore or opt into later.

**Risk** — None. No keys, no strings, pixel-identical.

**Effort — S.** Delete 7 lines, change `:43` to `.buttonStyle(.pasPressable())`. Note `ScaleButtonStyle` is `internal`, not `private`, so grep the test target before deleting (currently zero hits outside this file).

**Recommendation — adopt now.**

---

### 9. Onboarding draft persistence

**App code** — `WorkoutApp/Features/Onboarding/OnboardingViewModel.swift:396` (`draftKey = "onboarding.draft"`), `:449-451` (`JSONEncoder().encode(draft)` → `UserDefaults.standard.set(_:forKey:)`), `:454-457` (`data(forKey:)` → `try? JSONDecoder().decode`), `:502-504` (`removeObject(forKey:)`).

**PASKit equivalent** — `PASDraft<Draft>(key: "onboarding.draft")` with `.save(_:)` / `.load()` / `.clear()`, `Sources/PASKitCore/Settings/PASDraft.swift:22-43`.

**Fit — exact.** PASDraft is the same `JSONEncoder` / `JSONDecoder` / `try?` best-effort box, byte-compatible with what is already on disk, and PASKit's own documentation cites `"onboarding.draft"` as the example key. The app's careful ordering — hydrate answers first, then resolve the step (`:481` comment, `loadDraft`'s "Hydrate fields first so visibleSteps computes correctly") — is unaffected; only the three storage calls change.

**Risk** — Persisted key `onboarding.draft` must be passed verbatim to `PASDraft(key:)`. An installed user mid-onboarding whose key moved would lose their draft. Encoding is unchanged, so existing blobs (including the `weightUnitRaw` / `lengthUnitRaw` optional-for-back-compat fields at `:418-420`) decode as before. No user-visible change, no strings.

**Effort — S.** ~10 lines. The `Draft` struct itself stays exactly where it is.

**Recommendation — adopt now.**

---

### 10. Reduce-Motion ternaries

**App code** — eleven `reduceMotion ? nil : AppTheme.Motion.…` sites:
`HomeView.swift:44, 64, 69, 85, 100, 459`; `WeeklyVerdictCard.swift:113, 139`; `OnboardingBirthdateStep.swift:19, 20`; `EquipmentSelectionList.swift:119`.

**PASKit equivalent** — `Animation.respectingReducedMotion(_:)` (`Sources/PASKitCore/Styling/Animation+ReducedMotion.swift:18-20`, literally `reduceMotion ? nil : self`) and `View.pasAnimation(_:reducedMotion:value:)`.

**Fit — exact**, for the call sites that already read `@Environment(\.accessibilityReduceMotion)` — which all eleven do. `withAnimation(reduceMotion ? nil : AppTheme.Motion.spring)` becomes `withAnimation(AppTheme.Motion.spring.respectingReducedMotion(reduceMotion))`. The two `.animation(_:value:)` sites in `OnboardingBirthdateStep` and the one in `HomeView:459` can go further and use `.pasAnimation(AppTheme.Motion.gentle, value:)`, dropping the `@Environment` declaration entirely.

**Risk** — None. Identical semantics; the app's own motion tokens (`AppTheme.Motion`) stay put, which is exactly PASKit's mechanism-not-vocabulary split.

**Effort — S.** Eleven one-line edits, `import PASKit` added to three files.

**Recommendation — adopt now.** Low value per site, but it removes the pattern's re-derivation and puts the next new animation on the shared mechanism by default.

---

### 11. `CircularProgress` — leave

**App code** — `WorkoutApp/ViewComponents/CircularProgress.swift:1-45`. Four call sites: `ActiveExerciseView.swift:186`, `ActiveWorkoutView.swift:358` and `:541`, `OnboardingPotentialStep.swift:247`.

**PASKit equivalent** — `PASProgressRing` (`Sources/PASKitLifecycle/Indicators/PASProgressRing.swift`).

**Fit — partial.** Shared: clamped 0…1, `-90°` rotation, `.round` line cap, optional `@ViewBuilder` centre label, spring on change. Three differences, one of which is structural:
1. **`animatable` is a separate parameter.** Every app call site drives the animation off a *different* value than `progress` — `Double(completedSets)` at `:186` and `:358`, `Double(restTimerSeconds)` at `:541`. `PASProgressRing` animates on `progress` itself and exposes no equivalent seam. The rest-timer ring in particular is deliberately animated per whole second, not per fraction.
2. **Colours.** `CircularProgress` takes `progressColor` and defaults `trackColor` to `.surfaceElevated`; `PASProgressRing` reads the fill from `.tint` and defaults the track to `Color.secondary.opacity(0.25)`. Recoverable (`.tint(.brandPrimary)` + explicit `trackColor:`), but every call site grows.
3. **Springs differ** — `AppTheme.Motion.spring` is `response: 0.4`, PASKit's is `response: 0.35`.

**Risk** — No keys. `PASProgressRing` attaches its own `accessibilityLabel("Progress")` / `accessibilityValue("N percent")`. Three of the four call sites override accessibility anyway (`:196-198` label/value, `:547` `accessibilityHidden`), but `OnboardingPotentialStep.swift:247` does not — it would gain an English-only "Progress / 76 percent" announcement that cannot enter the app's `Localizable.xcstrings`. Small, but it is exactly the verbatim-string trap.

**Effort — M**, mostly because of the `animatable` seam.

**Recommendation — leave.** The `animatable` decoupling is a real design decision this app made and PASKit does not offer. Revisit only if `PASProgressRing` gains an `animationTrigger:` parameter; even then the win is ~45 lines against four widened call sites.

---

### 12. `OnboardingViewModel` step machine — leave

**App code** — `WorkoutApp/Features/Onboarding/OnboardingViewModel.swift:36-102` (`currentStepIndex`, `navigationDirection`, `visibleSteps`, `currentStep`, `totalSteps`, `isLastStep`), `:275-288` (`next()` / `previous()`); `OnboardingView.swift:27-33` (the transition) and `:139-150` (the progress bar).

**PASKit equivalent** — `PASOnboardingFlow`, `View.pasOnboardingTransition(step:direction:)`, `PASOnboardingProgressBar`.

**Fit — partial, three ways.**
1. `previous()` (`:281-288`) walks *backward past* the two timed interstitials (`.buildingPlan`, `.calculatingPotential`) because arriving on one backward is a one-way trap — the comment at `:30-33` documents the bug this fixes. `PASOnboardingFlow.back()` is a plain bounded decrement with no skip predicate; the app would have to keep its own loop and drive `flow.go(to:)`, which is most of what it already does.
2. The transition (`OnboardingView.swift:28-33`) is asymmetric **insert-slide / remove-opacity**. `pasOnboardingTransition` is a direction-flipped slide on *both* edges. Different on-screen motion.
3. The progress bar (`:139-150`) is a fixed-width 160 pt capsule filled with `LinearGradient.brandGradient` over `Color.surfaceElevated`. `PASOnboardingProgressBar` is full-width, `.quaternary` track, `.tint` fill — a solid colour. PASKit ships no design layer, and `.tint` cannot take a gradient, so adopting it costs the brand ramp on the app's most-seen first-run surface.

**Risk** — No persisted keys beyond `onboarding.draft` (covered by finding 9). User-visible: the step transition and the progress bar are both distinctive first-run chrome.

**Effort — L.** The engine is entangled with 17 step cases, a live `visibleSteps` closure, skip logic, `isSkippable` / `isContinueDisabled` gating, and draft round-tripping.

**Recommendation — leave.** Adopt finding 9 (`PASDraft`) from this file and nothing else. The step engine is the one place where the app's version genuinely does more than PASKit's, and the visual chrome would regress.

---

## Looks like a match but isn't

**`WorkoutStreak` vs `PASStreakEngine`.** `WorkoutApp/Core/Utilities/WorkoutStreak.swift:24-111` counts *consecutive calendar weeks containing at least one session*, by walking backward over history with a caller-supplied `hasSession(weekStart:weekEnd:)` closure, plus a `longestRun(in:)` forward walk for Year in Review (`YearInReview.swift:101`). `PASStreakEngine` is a **daily** rollover state machine over a persisted `PASStreakState` (`lastActiveDay`, `freezeBalance`, `lastFreezeGrantAt`) with freeze credits. Different unit (weeks vs days), different data source (derived from history on every read vs persisted counter), different feature set (grace week vs freezes). Not the same thing; the app's version is correct for a training app where a rest day is normal. Rejected.

**The undo toast vs `View.pasToast`.** `ActiveWorkoutView.swift:89-92, 497-535` plus `ActiveWorkoutManager.swift:219-226, 644-651` looks like a textbook `pasToast(item:)` case — "Set N logged · Undo", auto-dismiss, cancel-and-replace timer. Three reasons not to. (a) It is **in-flow**, not an overlay: `undoToast(...)` is a sibling of `exerciseStrip` inside the scroll content, so it pushes layout down. `pasToast` places a floating overlay; adopting it moves the toast off the content flow — a visible layout change on the primary workout screen. (b) The dismiss timer lives in the manager as `undoDismissTask` with an `undoDismissDelay` test seam (`:226`) that `ActiveWorkoutManagerTests.swift:154` sets to 0.3 s; `pasToast`'s `.task(id:)` dismissal is view-owned and untestable from the manager's suite. (c) The toast is coupled to `lastCompletedSetInfo` and to a VoiceOver announcement fired from `.onChange(of: manager.showUndoToast)` (`:180-185`). The *mechanism* PASKit ships is the part the app already got right. Rejected.

**`ChartPreferences` vs `PASDraft`.** `WorkoutApp/Core/Services/ChartPreferences.swift:89-113` is a Codable value in a `UserDefaults` key under `activeChartMetrics` — superficially `PASDraft`. But it carries three behaviours `PASDraft` does not and must not: the `LenientMetric` per-element salvage decode (`:77-83`, with a documented non-obvious reason involving `unkeyedContainer` cursor advancement), the deliberate `didSet` re-save that prunes dropped elements from storage (`:102-107`), and the "no blob" vs "stored empty array" distinction (`:92-95`) that separates a first launch from a user who removed every chart. Wrapping this in `PASDraft` would hide the salvage path behind a `try?` that returns `nil` and re-seed the defaults over a deliberately-emptied list. Rejected.

**`sendContactEmail()` vs `MailComposerView` / `FeedbackSheet`.** `SettingsViewModel.swift:64-67` opens a `mailto:` URL. `MailComposerView` presents `MFMailComposeViewController` in-app, and `FeedbackSheet` is a full structured form with a caller-owned transport. Both are *upgrades*, not equivalents: `mailto:` leaves the app and uses whatever mail client the user has; `MailComposerView` requires Apple Mail to be configured (`canSendMail`) and needs a fallback path anyway. `FeedbackSheet` would additionally need a transport the app does not have (it has no backend) and would introduce English-only form labels into a screen whose every other string is catalog-backed. Not a duplication — a product decision. Rejected as a *deletion* candidate; worth considering on its own merits later.

**`requestAppReview()` vs the Rating module.** `SettingsViewModel.swift:69-73` hand-rolls a `foregroundActive` scene lookup for `AppStore.requestReview(in:)`. PASKit's Rating module ships only the *two-stage gated prompt*, not a bare "ask now" — and this is the explicit Settings row, which must never be gated. The right cleanup is SwiftUI's own `@Environment(\.requestReview)`, which is not PASKit. Rejected.

**`AppTypography` vs `Font.pasScaled`.** `WorkoutApp/Core/Theme/AppTypography.swift:7-29` defines thirteen fixed-point `Font.system(size:)` tokens that do **not** track Dynamic Type. `Font.pasScaled(_:relativeTo:weight:design:)` is exactly the mechanism that would fix that. But this is a missing capability, not a duplicate — there is no local reimplementation of `UIFontMetrics` to delete, and switching all thirteen tokens would reflow every screen in the app. Out of scope for a replace-with-PASKit audit; worth its own accessibility ticket.

**`AppColors` vs `Color(light:dark:)`.** `WorkoutApp/Core/Theme/AppColors.swift` resolves surfaces and brand colours through the **asset catalog** (`Color("CardBackground")`, `Color("AccentColor")`) with a few literal `Color(red:green:blue:)` constants. `Color(light:dark:)` exists for apps *without* an asset catalog. Nothing to delete. (The app is also `preferredColorScheme(.dark)`-locked at `WorkoutAppApp.swift:60`, so light-variant plumbing would be dead code.) Rejected.

**`MuscleBodyMap.renderAndCache` vs `PASShareCard.render`.** `WorkoutApp/ViewComponents/MuscleBodyMap.swift:212-238` also drives an `ImageRenderer` with an explicit `colorScheme` injection, so it pattern-matches finding 1. It is not a share card: it renders at `displayScale` (not 3×) into an `NSCache` keyed by `BodyMapSnapshotKey`, produces a SwiftUI `Image` (not `UIImage`), and is deliberately bypassed under Increase Contrast (`isSnapshotFaithful:210`). `PASShareCard.render` returns a fixed-scale `UIImage` for export. Different job. Rejected.

**`CardStyle` vs `pasGlass`.** `WorkoutApp/ViewComponents/ViewModifiers/CardStyle.swift` is an opaque `Color.surfaceCard` fill with a 1.5 pt `"CardBorder"` stroke — a brand token, not a material. `pasGlass` renders `glassEffect` / `.regularMaterial`. The app already uses `pasGlass` where glass is wanted (9 sites). Not a duplicate. Rejected.

**Release-notes stack — clean.** `WorkoutApp/Core/Model/ReleaseNotes.swift` is data only, `ContentView.swift:12-15, 124-137` drives `WhatsNewGate` with both key overrides, `SettingsView.swift:256-266` uses `ChangelogView` with an `entryContainer` slot, and `ReleaseNotesTests.swift` pins only the app-owned authoring invariants. Grep for `WhatsNewVersion` / `lastWhatsNewVersion` returns only the two intentional key-override lines and their comment. **Nothing left behind.**

**Categories with nothing to report.** Searched and clean — the app contains no local implementation of any of these, so there is nothing to delete: networking (`URLSession` appears nowhere in `WorkoutApp/`), keychain / credentials (no `Keychain`, no `SecItem`), reachability (no `NWPathMonitor`), App Group storage (no `group.` identifier, no `containerURL`; the Live Activity extension shares no store), logging (no raw `os.Logger` — `PASLogger` is already used), app/device metadata (`AppInfo` already adopted at 11 sites; no raw `Bundle.main.infoDictionary`), analytics (`PASAnalytics` at `WorkoutAppApp.swift:43`), purchases (`PASPurchases` at `:100`), notification delegate/config (`PASNotifications.configure` at `:105`), shared error domain (`DataStoreError` / `DataExportError` are app-vocabulary `LocalizedError`s, not a `PASError` re-roll), version/update check (the app ships none), settings app-info footer (the app shows `AppInfo.versionWithBuild` inline on the What's New row rather than a footer — nothing duplicated), dev menu (8 `#if DEBUG` blocks, no in-app menu to replace), loading overlay (no dimmed-backdrop overlay exists; `OnboardingLoadingStep` is a full-screen branded step, not an overlay). The Live Activity target (`WorkoutAppLiveActivity/`) contains no PASKit-replaceable code.
