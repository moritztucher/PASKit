# Action plan — PASKit consolidation

Derived from the six audits in this folder (2026-09-04, PASKit v0.3.1). Each item cites the audit
it came from.

> **Status — 2026-09-05.** Sections 0 (P1–P9), 1, 2 and 3 are **done and pushed**. PASKit shipped
> the nine blocking items across v0.3.1–v0.4.0, and all three apps then adopted the shared APIs:
> WorkoutApp `27eb99d` (−388 lines), CoupleCalorieTracker `aea8b27`, XueTangV2 `5604b5f54`. All
> three build green and the collision detector reports zero errors, zero warnings and zero stale
> allowlist entries in each.
>
> **Two items were deliberately not done, and should not be revived without re-reading why:**
> - **XueTang #4, `FeedbackService` → `PASAnalytics`** — superseded. `XueTangV2/docs/PRIVACY-OPEN-ITEMS.md`
>   §2 establishes that the PostHog SDK *drops* `capture` while opted out, so a migrated feedback
>   path would silently discard submissions from opted-out users while the sheet says "sent". The
>   hand-rolled POST is correct.
> - **WorkoutApp #7, `WorkoutAppLiveActivity.elapsedText`** — that extension target does not link
>   PASKit, so its inline `min:sec` copy stays until the target gains the dependency.
>
> What remains from these audits is the **"Contribute to PASKit"** column in each app section —
> extraction work, gated on *build on real need*. The strongest candidates, both with two-app
> evidence, are the **audio-session lifecycle** (WorkoutApp's `RestEndSound` lacks the interruption
> observer XueTang already has, so extracting fixes a bug) and the **permission tri-state**
> (three apps, three incompatible spellings).

**The headline from all six audits: the adoption gap is larger than the extraction opportunity.**
Every app runs parallel copies of PASKit APIs it already links. Fix that before growing PASKit.

---

## 0. PASKit — do these first

Five app items are blocked on PASKit defects. Until these land, adopting the shared version would
be a *regression* for the app doing the adopting.

| # | Task | Why it blocks | Effort |
|---|------|---------------|--------|
| P1 | **`pasPressable` must honour Reduce Motion.** `PASPressableButtonStyle.makeBody` applies `.animation(.spring(…))` unconditionally, with no `accessibilityReduceMotion` check — while PASKit ships `pasAnimation` *specifically* to respect it. | Blocks CCT #5 and WorkoutApp #8. XueTang's local copy already guards, so adopting today would regress it. | S |
| P2 | **`presentAppRating` needs key + copy overrides.** It hard-codes `paskit.appRating.*` with no injection point. | Blocks WorkoutApp #4, which shipped `isRatingInteractionComplete` / `isInitialPromptComplete`. Precedent: `WhatsNewGate(lastSeenBuildKey:)`. | S |
| P3 | **`PASNotificationRequest.sound` is a `Bool`.** No custom sound name. | Blocks WorkoutApp #6 — `rest_complete.wav` is load-bearing for its single-ding design. | S |
| P4 | **Promote `PASOnboardingProgressBar` → `PASProgressBar`** in `Indicators/`, deprecated alias behind it. It is already the generic mechanism; only its name and folder say "onboarding". | Six hand-rolled linear bars exist across three apps *because of where it sits*. | S |
| P5 | **Extend `PASStreakRolloverOutcome`** with `streakLost` (lapse length) and `gapDays`. | Blocks XueTang migrating back onto the engine it donated. | S |
| P6 | **`PASError.errorDescription` is hardcoded English**, outside any app's string catalog. — **implemented** | Soft-blocks every localized app from adopting the error domain. Lower priority — no current adopter is waiting. Shipped in v0.4.0 as `PASError.localizer` (injectable, read per call) + `developerDescription` (English fallback, developer tone) — see [ADR-0003](../adr/ADR-0003-error-copy-is-app-vocabulary.md). XueTang still needs to install the localizer + add 3 keys × 7 languages before its Release-build feedback alert is actually localized. | M |

### P7 — New `PASKitHealth` module (L) — **implemented**

The strongest extraction signal in the whole audit, and the only one both extract agents reached
independently. WorkoutApp (`Core/Services/HealthManager.swift` + `HealthManager+Reading.swift` +
`HealthKitPermissionDescriptor.swift`, 463 lines) and CCT (`Health/HealthProfileReader.swift:26`)
wrote the same plumbing separately — same availability check, same descriptor-driven
`requestAuthorization(toShare:read:)`, same latest-sample query.

Both files *independently document the same iOS trap*: a denied read grant is indistinguishable
from no data, so reads must never be gated on `isAuthorized`. Two authors writing the same
non-obvious contract in their own words is exactly the fingerprint that identified the
release-notes duplication.

Its own module, not `PASKitCore` — HealthKit drags usage-description and entitlement expectations
into every consumer. No vendor SDK, so CCT can link it without breaking its RevenueCat/PostHog
abstinence.

Shipped in v0.4.0 as `PASKitHealth` (`PASHealth.shared`) — single `HKHealthStore`,
descriptor-driven `configure`/`requestAuthorization`, honest write-only `writeAuthorization`
(never a read status — reads are ungated by design), `latestQuantity`/`samples`/`biologicalSex`/
`dateOfBirthComponents` reads, `save`/`saveQuantity` writes. **Deliberately not in the `PASKit`
umbrella** — see [ADR-0004](../adr/ADR-0004-paskithealth-umbrella-exclusion.md); apps that use
Health add the `PASKitHealth` product explicitly. Adoption (WorkoutApp, CCT) is separate work.

### P8 — Symbol-collision detector (M) — **implemented**

Documentation has now failed three times at stopping duplication. Every instance is a **name
collision with a shipped PASKit symbol**:

- `WorkoutApp/ViewComponents/ViewModifiers/AppRatingModifier.swift` declares
  `View.presentAppRating(initialCondition:askLaterCondition:)` — PASKit's exact signature, in a
  file that imports PASKit. Same-module declarations win overload resolution, so the app has been
  silently running its own copy.
- XueTang's local `WhatsNewView` (resolved, but only because that file didn't import the module).
- XueTang's local `AppInfo` shadows PASKitCore's — `FeedbackService.swift:37-39` uses the app's
  `AppInfo` and PASKit's `DeviceInfo` on three consecutive lines.
- `CLLDesign/PressScaleButtonStyle.swift:4` duplicates `pasPressable`.

Mechanically detectable: dump PASKit's public symbols, grep each app for local declarations of the
same names, fail CI on a hit. Implemented as `Scripts/check-collisions.py` (see
[ADR-0002](../adr/ADR-0002-symbol-collision-detector.md)) — a dependency-free Python parser over
`Sources/`, run per-app via a reusable `ios-ci` workflow. **Correction to the original claim above:**
it catches the three genuine *name* collisions (`View.presentAppRating`, `AppInfo`, and an unlisted
fourth — `Animation.respectingReducedMotion` in XueTangV2's `Theme.swift:357`, byte-identical to
PASKit's, found by the tool's dry run and missed by this audit). It does **not** catch
`CLLDesign/PressScaleButtonStyle` — that is a *semantic* duplicate under a different name
(`PressScaleButtonStyle` vs. `PASPressableButtonStyle`), invisible to a name-based detector by
construction. That class of duplication still needs a reading pass, not a mechanical check.

### P9 — Repo hygiene

`develop` is behind `main` again — `6b9f01e Release v0.3.1 (#9)` is on `main` only, so
`git describe` on `develop` reports `v0.3.0-16-g…` and cannot see the v0.3.1 tag. This is the third
occurrence. Squash-merging release PRs rewrites history, so every merge-back conflicts across every
file both branches touched. **Fix:** merge `origin/main` into `develop` now; **prevent:** use a
merge commit rather than squash for release PRs.

---

## 1. WorkoutApp

Branch `develop`. Already the heaviest PASKit consumer — analytics, purchases, notification config,
release notes, Liquid Glass and `AppInfo` are all on the package.

### Adopt now

| # | Task | Notes | Effort |
|---|------|-------|--------|
| 1 | **Share pipeline → `PASKitSharing`** (`WorkoutShareSheet` + `StoryCardRenderer`) | The pipeline exists *three times* in the app. `TransparencyCheckerboard` is byte-identical to PASKit's, down to the `0.06`/`0.12` opacities; `StoryCardRenderer`'s own header admits the duplication. ~130 lines. | M |
| 2 | **`AppSettings` → `PASSettingsStore` + `@PASDefault`** | 361 lines → ~25. 16 of 20 properties map exactly with keys verbatim. **Do not move four:** `targetBodyFatPercent`, `customRestSmall/Medium/Large` write `0` to mean "unset" — `@PASDefault Int?` would read `.some(0)` and resurrect cleared rest-timer overrides and fat-loss goals for every installed user. Also coarsens observation from per-key to per-store; `ActiveWorkoutView` is a reader. | M |
| 3 | `RestEndHaptics` → `Haptics.play(.triplePulse)` | PASKit's doc comment already reads *"three heavy pulses 350 ms apart. (workout-app timing)"* — extracted from here, never deleted. | S |
| 4 | Onboarding draft save/load/clear → `PASDraft<Draft>` | Exact fit. | S |
| 5 | 11 × `reduceMotion ? nil : AppTheme.Motion.x` → `View.pasAnimation` | Exact fit. | S |
| 6 | `UnitConvert.clockDuration` + 4 inline `min:sec` copies → `PASDurationFormat.clock` | Timer shapes only; leave `labeledDuration`. | S |
| 7 | `ScaleButtonStyle` → `.pasPressable()` | **After P1.** | S |

### Blocked on PASKit

- `AppRatingModifier` → `presentAppRating` — **after P2**. Also loses app-name-personalised copy;
  decide whether that matters before adopting.
- `RestEndNotifier` → `PASNotifications` — **after P3**.

### Contribute to PASKit

| Task | Home | Evidence | Effort |
|------|------|----------|--------|
| HealthKit facade | new `PASKitHealth` | CCT twin — see P7 | L |
| Decimal-pad pair (`Double(userInput:)` + `keyboardDoneButton()`) | `PASKitCore/Input` | CCT has the comma→dot normalization duplicated inline at `LogEntryViewModel.swift:326`, and **five `.decimalPad` fields with no dismiss affordance** — adopting fixes a live CCT bug | S |
| Wrapping flow layout | `PASKitCore/Layout` | XueTang `PillFlow.swift` — independent `Layout` conformance. Take XueTang's as the base: it has the row cache, `lineSpacing` and correct intrinsic width | S |
| Bundled-image loader (off-main decode + `NSCache`) | `PASKitCore/Images` | XueTang `Core/Artwork/Artwork.swift` | M |
| `ValueWheel` | `PASKitLifecycle/Pickers` | Single-app, but it works around a `Picker(.wheel)` accessibility-bridge crash; sharing the workaround is the point | M |
| `ReorderDropDelegate` | `PASKitCore/DragDrop` | Its own doc says it was ported from `dk-physio-sports-ios` — already copy-pasted across a project boundary once | S |

### Leave

`CircularProgress` (PASProgressRing is a partial fit), `OnboardingViewModel` step machine (L, and
PASKit's flow doesn't cover its validation), `WorkoutStreak` (weekly-from-history vs PASKit's
daily-with-persisted-state — genuinely different), the undo toast, `ChartPreferences`,
`MuscleBodyMap.renderAndCache`.

---

## 2. CoupleCalorieTracker

Branch `main`. Links **only `PASKitLifecycle`**, deliberately, to avoid RevenueCat and PostHog.

**Product note:** items 3–6 below need the `PASKitCore` product added. That pulls **no vendor SDK** —
its only external dependency is `KeychainAccess`, already resolved and linked transitively via
`PASKitLifecycle → PASKitCore`. `Package.resolved` does not change; the abstinence holds.

### Fix now — these are live bugs, independent of consolidation

| # | Task | Effort |
|---|------|--------|
| 1 | **`heroNumeralStyle(size:)` uses `Font.system(size:)`** — the app's eight biggest numbers do not track Dynamic Type. `Font.pasScaled` fixes it in one function body, all 8 call sites unchanged. | S |
| 2 | **Ten `.animation(…)` sites ignore Reduce Motion**, including two `repeatForever` on the live scanner (`ScanScreen.swift:305-306`). Nothing in the app reads `accessibilityReduceMotion`. `View.pasAnimation` is a mechanical swap. | S |

### Adopt

| # | Task | Notes | Effort |
|---|------|-------|--------|
| 3 | **Onboarding step engine → `PASOnboardingFlow`** | The only finding that deletes real state-machine code (`OnboardingViewModel.swift:11-83` + `OnboardingFlow.swift:32-63`), and it needs **no new product**. Per-step validation guards must move to call sites; the six progress dots stay app-owned (`PASOnboardingProgressBar` is a bar). | M |
| 4 | `#if DEBUG debugCard` → `pasDevelopmentOverlay` | Lifts debug code out of the 573-line `ProfileScreen`. Zero shipped behaviour change. | S |
| 5 | The single `print` in `PersistenceController.swift:34` → `PASLogger` | The app's only logging. | S |
| 6 | `NeonPressedButtonStyle` → `.pasPressable(pressedScale: 0.97)` | **After P1.** Costs a motion decision: PASKit's spring is snappier than `DS.spring`, on the app's main CTA. | S |

### Contribute to PASKit

| Task | Home | Evidence | Effort |
|------|------|----------|--------|
| HealthKit facade | new `PASKitHealth` | WorkoutApp twin — see P7 | M |
| Permission tri-state + Open-Settings deep link | `PASKitCore/Permissions` | **Three apps, three incompatible spellings** of `{notDetermined, granted, denied}` — WorkoutApp `OnboardingViewModel.swift:292-330`, XueTang `ReminderService.swift:77` | S |
| `Scripts/sync-strings.sh` | Not a Swift module — `CLAUDE-INTEGRATION.md` or the shared CI repo | Inverted evidence and the cheapest win: WorkoutApp (742 keys) and XueTang (760 keys) have **no `xcstringstool` sync at all** and rely on Xcode-on-build, which CLI-driven sessions bypass | S |
| `FlexibleDouble` + `AnyCodingKey` | `PASKitCore/Networking` | WorkoutApp `Double+UserInput.swift:8`, `ChartPreferences.swift:70` | S |

### Leave

`OpenFoodFactsClient` (its typed `throws(OFFError)`, per-barcode 404 caching and five
`String(localized:)` messages are all richer than `PASError` — see P6), `DefaultsKey` /
`CoreDataProfileStore` keys (identity pointers into Core Data rows; a migration risks orphaning
every install's profile for no gain), Monday-first week start (`pasStartOfWeek` honours locale
`firstWeekday`; this app hard-codes Monday in data *and* labels), `.ultraThinMaterial` on the
scanner, the barcode/camera stack (most library-shaped code in the repo, but neither other app has
a single line of `AVCaptureDevice` — *build on real need*).

---

## 3. XueTangV2

Branch `develop-xt2-revamp`. Links the `PASKit` umbrella; already routes RevenueCat through
`PASKitPurchases` and notifications through `PASKitNotifications`.

### Fix now

| # | Task | Notes | Effort |
|---|------|-------|--------|
| 1 | **11 What's New call sites omit `bundle: XTLocalization.bundle`** — all of `ReleaseHighlights.swift` plus `MainView.swift:104`, where the rest of the app passes it 177 times. | Introduced by yesterday's migration. Nothing is missing — every key and all 6 translations resolve — but a mid-session learning-language switch leaves that one sheet in the old language. | S |
| 2 | **Correct `CLAUDE.md`: `PASKitAnalytics` is not a stub.** | v0.3.1 ships a complete 152-line PostHog facade. The stale line is *why* finding 3 below exists — a wrong doc caused code to be written. | S |
| 3 | **`settings.analyticsEnabled` is written and displayed in Privacy settings but read by nothing.** | A false statement to users today. Must be wired to `optIn()`/`optOut()` as part of finding 4 — not after. | S |

### Adopt

| # | Task | Notes | Effort |
|---|------|-------|--------|
| 4 | **`FeedbackService` → `PASAnalytics`** | Drops a hand-rolled HTTP `/capture` POST, a private `CaptureEvent` struct and a per-install distinct ID — for a single event. **Trap:** the shipped `xt.feedback.distinctID` means existing users re-key to PostHog's anonymous ID, so historical feedback events will not join. Decide whether that matters before migrating. | M |
| 5 | `SettingsStore` (379 lines, 26 keys) → `PASSettingsStore` + `@PASDefault` | Keys verbatim. | M |
| 6 | `PaywallViewModel` → `PASPaywallFlow` + `pasSavingsPercent` / `pasHasFreeTrial` | PASKit's default error copy is byte-identical to the app's — it was extracted from here. | S–M |
| 7 | `Animation.respectingReducedMotion` (`Theme.swift:354`) → PASKit's | Identical body. | S |
| 8 | `HapticManager` → `PASHaptic` + `Haptics.play(_:isEnabled:)` | Keep a thin gate shim. | S |
| 9 | `registerBundledFonts()` (`XueTangApp.swift:163`) → `PASFontRegistration` | Exact. | S |
| 10 | Local `AppInfo` — drop `version`/`build`/`versionLabel`/`name`, rename the type | Keeps its four genuinely app-owned values (support/feedback emails, terms/privacy URLs). Ends the shadowing hazard at `FeedbackService.swift:37-39`. **Bonus bug:** `versionLabel` bakes an unlocalized English `"Version "` prefix shown across all 7 languages. | S |
| 11 | `xtConcentricClip` → `pasConcentricClip`; `String(format: "%d:%02d")` → `PASDurationFormat.clock` | Exact copies. | S |
| 12 | `ProgressStore` day/week arithmetic → `Date.pas…` helpers | Helpers only — **keep the engine**, it does four things `PASStreakEngine` doesn't and uses calendar-month rather than fixed-interval freeze grants. | S–M |

### Contribute to PASKit

| Task | Home | Evidence | Effort |
|------|------|----------|--------|
| **Streak lapse-length outcome, then migrate back** | `PASKitCore/Streak` (extend) | `ProgressStore.rollover()` is order-for-order PASKit's engine — whose header names this app as the donor — and has **forked forward** with a lapse length and 7-day gap signal PASKit never received. A distinct failure mode: not "didn't check PASKit", but "contributed, then diverged". **After P5.** | S |
| Audio-session lifecycle | `PASKitCore/Audio` (new) | **The one real two-app twin.** `WorkoutApp/Core/Services/RestEndSound.swift:26-49` does the same activate/deactivate dance with **no interruption observer** — it carries a bug XueTang already fixed. Extracting fixes WorkoutApp as a side effect. | S |
| Home Screen quick-action bridge | `PASKitLifecycle/QuickActions` (new) | Single-app, but pure SwiftUI-gap boilerplate with zero vocabulary — cold-start shortcuts only arrive via `UIScene.ConnectionOptions` | S |
| In-app language override | `PASKitCore/Localization` (new) | Single-app, but encodes four real traps: process- vs environment-locale, the `AppleLanguages`/iOS-Settings conflict, `en` not being `.main`, and Swift 6 concurrency | M |
| `Color(hex:)` (from `CLLDesign`) | `PASKitCore/Styling` | `CLLDesign` + MandarinToneTrainer | XS |

### Defer — but write down the plan

**Firebase auth facade** (`FirebaseAuthService` + `FirebaseBootstrap` + `FreshInstallGuard`): the
most expensive and most dangerous code here to re-derive — Apple nonce, anonymous linking,
`credentialAlreadyInUse` recovery, 5.1.1(v) token revocation, Keychain-survives-reinstall guard.
No second app has accounts, so *build on real need* says wait. Needs its own module when it
happens; Firebase and GoogleSignIn must not land in `PASKitCore`.

### Leave

`XTFont.scaled` (different `TextStyle` currency from `Font.pasScaled`), the development overlay
(design cost, no runtime gain), `UpdateRequiredSheet` (adopt `VersionCheckManager` only if the gate
is ever armed), Readiness (HSK 3.0 / GF0025-2021 domain), FSRS / chests / leagues / XP,
`SpeechClipLibrary` (its index format is co-designed with the Python pipeline — extracting the
reader ships half a contract), `VocabImportParser`, the Python content pipeline.

### Sibling packages

`CLLDesign`, `FSRS` and `ToneTrainerKit` are rightly separate: the split is coherent as
**PASKit = studio service layer, `CLL*` = one product family's domain and design**. Two caveats:
`CLLDesign` is not used by XueTangV2 at all (only MandarinToneTrainer), and its
`PressScaleButtonStyle.swift:4` already duplicates `pasPressable`. The fix is `CLLDesign` depending
on `PASKitCore` — not moving it in.

---

## Suggested order

1. **P9** (repo hygiene) — one merge, unblocks the next release.
2. **P1–P5** (PASKit defects) — all S, and five app items are waiting on them.
3. **CCT #1–#2** and **XueTang #1–#3** — live bugs, mostly S, no dependencies.
4. **P8** (collision detector) — stops the bleeding before more adoption work lands.
5. **Adoption**, app by app, largest first: WorkoutApp share pipeline + `AppSettings`, XueTang
   `PASAnalytics` + `SettingsStore`, CCT onboarding.
6. **P7** (`PASKitHealth`) — the one extraction with two-app evidence.
7. Everything else marked *extract when a second app needs it* stays on the shelf until it does.
