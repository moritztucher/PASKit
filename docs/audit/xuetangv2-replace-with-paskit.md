# XueTang V2 — what can be deleted and replaced by PASKit

Date 2026-09-04 · PASKit v0.3.1 (`Package.resolved` pins `6b9f01e`, `upToNextMinorVersion` from `0.3.0`, umbrella `PASKit` product) · App `XueTangV2` @ `develop-xt2-revamp` `0d5d743b9`

All app paths below are relative to `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2`. All PASKit paths are relative to `/Users/moritztucher/Private/PASKit`.

## Summary

The app is genuinely routed through PASKit where its `CLAUDE.md` says it is — RevenueCat, notifications, logging and the What's New sheet all go through the package, and 20 files import it. What is left is a layer of *pre-adoption* code: utilities written before the matching PASKit surface existed, plus one module the app's own docs still describe as a stub when it has in fact shipped. The single highest-value finding is `PASKitAnalytics`: it is a complete 115-line PostHog facade in v0.3.1, while the app still hand-rolls an HTTP capture call, its own distinct-ID, and its own event payload struct for exactly one event — and ships a Privacy toggle that nothing reads. After that the value is concentrated in `SettingsStore` (379 lines of `didSet` write-through that `PASSettingsStore` + `@PASDefault` collapses to about 60), the paywall purchase/restore state machine (PASKit's `PASPaywallFlow` carries byte-identical default error copy — it was clearly extracted from this app), and a handful of true copy-paste duplicates: `Animation.respectingReducedMotion`, the bundled-font registration loop, `xtConcentricClip`, and the version/build half of the local `AppInfo`. The streak engine, the settings footer, the dev menu, the ring components and the feedback form are all near-misses that should stay local, for reasons given below.

| # | Finding | PASKit equivalent | Fit | Effort | Recommendation |
|---|---------|-------------------|-----|--------|----------------|
| 1 | Hand-rolled PostHog HTTP capture + distinct-ID | `PASAnalytics` (PASKitAnalytics) | close | M | Adopt now — module shipped, app docs are stale |
| 2 | `SettingsStore` — 26 keys, manual `didSet` write-through | `PASSettingsStore` + `@PASDefault` | close | M | Adopt now, keys verbatim |
| 3 | `PaywallViewModel` purchase/restore/savings/trial | `PASPaywallFlow`, `pasSavingsPercent`, `pasHasFreeTrial` | close | S–M | Adopt now |
| 4 | `Animation.respectingReducedMotion` in `Theme.swift` | `Animation.respectingReducedMotion` (PASKitCore) | exact | S | Adopt now — identical body |
| 5 | `HapticManager` (4 intents + gate) | `PASHaptic` + `Haptics.play(_:isEnabled:)` | exact | S | Adopt now, keep a thin gate shim |
| 6 | `XueTangApp.registerBundledFonts()` | `PASFontRegistration.registerBundledFonts(named:)` | exact | S | Adopt now |
| 7 | Local `AppInfo.version` / `.build` / `.versionLabel` / `.name` | `AppInfo` (PASKitCore) | close | S | Adopt + rename the local type |
| 8 | `xtConcentricClip(fallbackRadius:)` | `pasConcentricClip(fallbackRadius:)` | exact | S | Adopt now |
| 9 | `ProgressStore` day/week arithmetic | `Date.pas…` helpers (PASKitCore Time) | partial | S–M | Adopt the helpers; keep the engine |
| 10 | `String(format: "%d:%02d", …)` | `PASDurationFormat.clock(seconds:)` | exact | S | Adopt now |
| 11 | `ReleaseHighlights` / `MainView` strings miss `XTLocalization.bundle` | n/a — migration leftover | bug | S | Fix now |
| 12 | `XTFont.scaled(_:relativeTo:weight:)` | `Font.pasScaled(_:relativeTo:weight:design:)` | partial | M | Leave — different `TextStyle` currency |
| 13 | `DevelopmentOverlay` + `DevelopmentMenuView` shell | `pasDevelopmentOverlay` + `PASDevelopmentMenu` | partial | M | Leave — design cost, no runtime gain |
| 14 | `UpdateRequiredSheet` | `VersionCheckManager` + `AppUpdateView` | partial | M | Leave the sheet; adopt `VersionCheckManager` if the gate is ever armed |

---

## Findings

### 1. PostHog is called by hand; `PASKitAnalytics` has shipped

**App code**
- `XueTang/XueTang/Core/Services/FeedbackService.swift:18-81` — `PostHogFeedbackService`, `CaptureEvent` (a private `Encodable` mirroring PostHog's `/capture` body), `distinctID()`.
- `XueTang/XueTang/Core/Configuration/APIKeys.swift:13,17` — `postHog`, `postHogHost`.
- `XueTang/XueTang/Core/Configuration/DefaultsKeys.swift:42` — `feedbackDistinctID = "xt.feedback.distinctID"`.
- `XueTang/XueTang/Core/State/SettingsStore.swift:61-63` — `analyticsEnabled`, surfaced at `XueTang/XueTang/Features/System/View/PrivacySettingsView.swift:19` and read by nothing else in the app.

**PASKit equivalent** `PASAnalytics.shared` — `setup(_:)` / `capture(_:properties:)` / `screen` / `identify` / `register` / `reset` / `optIn` / `optOut` / `flush` / `isFeatureEnabled`, plus `PASAnalyticsConfig` (`Sources/PASKitAnalytics/PASAnalytics.swift:36-114`, `PASAnalyticsConfig.swift`). PostHog is pinned in `Package.swift:30` at `posthog-ios` 3.48.3 and linked into the module at line 69. **This is not a stub.**

**Fit** Close. `capture("feedback_submitted", properties:)` replaces the whole `CaptureEvent` + `URLRequest` + `network.send` path; PostHog's SDK owns the distinct ID, so `distinctID()` and its UserDefaults key go with it. The one thing PASKit does not carry is the app's DEBUG "log and skip the network" behaviour — reproduce it by not calling `setup` in DEBUG, or by calling `optOut()`.

**Risk**
- **Persisted key.** `xt.feedback.distinctID` is live installed-user state. Switching to the SDK re-keys those users to PostHog's own anonymous ID, so feedback events submitted before and after the switch will not join on one person in the PostHog project. Either accept the seam or `identify(userId:)` with the stored value once before deleting the key. Do not delete the key without deciding which.
- **Consent.** `settings.analyticsEnabled` is written and displayed today but drives nothing. The moment the SDK is in, that toggle is a real consent control and must call `optIn()` / `optOut()` — shipping the SDK while the toggle stays inert would make the Privacy screen a false statement.
- **Identity join.** The contract asks for the same user ID in `PASAnalytics.identify` and `PASPurchases.logIn`. Neither is called today; if analytics lands first, wire both from `FirebaseAuthService` at once.
- Localization: none — no user-visible strings.
- Design: none.

**Effort** M.

**Recommendation** Adopt now. `setup` at launch in `XueTangApp.init` alongside the existing `PASPurchases.shared.configure`, rewrite `PostHogFeedbackService.send` to one `capture` call, delete `CaptureEvent`, `distinctID()`, `DefaultsKeys.feedbackDistinctID` and `APIKeys.postHogHost`. Keep `FeedbackSending` as the seam — the tests and the DEBUG stub both hang off it.

---

### 2. `SettingsStore` re-implements `PASSettingsStore` + `@PASDefault`

**App code** `XueTang/XueTang/Core/State/SettingsStore.swift:12-233` — a private `Key` enum of 26 string constants (lines 15-42), one stored property per setting each with a `didSet { defaults.set(…) }` (lines 47-185), a `register(defaults:)` block (189-203) and a 30-line hydration run in `init` (204-232). Domain logic below line 235 (textbook, learning language, leech snooze, XP boost) is genuinely app-owned.

**PASKit equivalent** `PASSettingsStore` (`Sources/PASKitCore/Settings/PASSettingsStore.swift`) + `@PASDefault` (`PASDefault.swift`) + `UserDefaultsStorable` (`UserDefaultsStorable.swift:118-127` covers `RawRepresentable` enums with an empty extension).

**Fit** Close. Every one of the 26 settings maps to a single `@PASDefault("settings.…") var x = default` line: `Bool`, `Date`, `Int`, `String?`, `Date?`, `TimeInterval?` and the two `Int`-raw enums (`QuickReviewLengthCap`, `DailyGoal`) are all storable out of the box. The `Key` enum, the `register(defaults:)` block and the whole `init` hydration disappear. What differs:
- `PASSettingsStore.defaults` is `public let`, so `setLearningLanguage`'s `defaults.set([code], forKey: "AppleLanguages")` (line 274) still works.
- `resolvedLearningLanguage(defaults:)` (line 293) is `nonisolated static` and reads the key string directly — keep it; it must not go through the instance.
- `private(set)` settings (`learningLanguage`, `textbookSeries`, `textbookVolume`) cannot be expressed by the wrapper's `_enclosingInstance` subscript, which needs a `ReferenceWritableKeyPath`. Make them `public` on the store and keep the mutation discipline in `setTextbook` / `setLearningLanguage`, or keep those three hand-rolled.

**Risk**
- **Persisted keys — all 26 are installed-user state and must be passed to `@PASDefault` byte-identically:** `settings.dailyReminderEnabled`, `.reminderTime`, `.streakAlertsEnabled`, `.newContentAlertsEnabled`, `.analyticsEnabled`, `.personalizedReviewEnabled`, `.soundEffectsEnabled`, `.hapticsEnabled`, `.showPinyinByDefault`, `.toneColorsEnabled`, `.autoplayAudio`, `.speakingExercisesEnabled`, `.quickReviewLengthCap`, `.dailyGoal`, `.leechSnoozedUntil`, `.welcomeBackDismissedForLapse`, `.welcomeBackStreakLost`, `.learningLanguage`, `.xpBoostArmedOnDay`, `.xpBoostArmedSeconds`, `.xpBoostActiveUntil`, `.xpBoostWindowSeconds`, `.xpBoostNowGrantedOnDay`, `.textbookSeries`, `.textbookVolume`, `.textbookLesson`.
- **Registration domain disappears.** `@PASDefault` keeps the fallback in the wrapper, not in `UserDefaults`' registration domain. One reader depends on the current arrangement: `XueTang/XueTang/Core/Services/HapticManager.swift:40-44` reads `"settings.hapticsEnabled"` off `UserDefaults.standard` with its own `object(forKey:) == nil ? true` fallback. That fallback happens to produce the same answer once registration goes away, so behaviour is preserved — but it is the only place in the app that reads a `settings.*` key outside the store, and it is exactly the kind of thing that silently flips. Verify it, or fold it into finding 5.
- **Observation granularity drops from per-property to per-store.** `settings` is injected app-wide (`XueTangApp.swift:97`) and read from `MainView`, `SettingsView`, `AppRouter.beginSession`, `ReminderService.sync`. Any write invalidates every observer. At settings-write frequency (toggles, an XP-boost arm once per session) this is imperceptible, but the XP-boost fields are the hottest writers — if that ever becomes a problem, split them into a second store.
- User-visible behaviour: none if keys are preserved.
- Localization: none — no strings.
- Design: none.

**Effort** M. Roughly a 300-line deletion; `XueTangTests/` has no test that reads a `settings.*` key literal, so the suite should be unaffected.

**Recommendation** Adopt now. This is the largest clean win in the app and the exact shape `@PASDefault` was built for.

---

### 3. `PaywallViewModel` re-implements `PASPaywallFlow` and the pricing helpers

**App code** `XueTang/XueTang/Features/Commerce/ViewModel/PaywallViewModel.swift`
- `:18-24` `errorMessage` + `isShowingError` binding — character-for-character `PASPaywallFlow`'s.
- `:26` `isPurchasing`.
- `:59-68` savings-percent math.
- `:71-73` `yearlyHasTrial`.
- `:121-160` `subscribe` / `restore`.

**PASKit equivalent** `PASPaywallFlow` (`Sources/PASKitPurchases/PASPaywallFlow.swift`), `StoreProduct.pasSavingsPercent(comparedToMonthly:)` and `Package.pasHasFreeTrial` (`Package+PASPricing.swift:19-53`).

**Fit** Close, and the provenance is obvious: `PASPaywallFlow`'s default `unreachableMessage` and `nothingToRestoreMessage` are the app's own strings verbatim ("The App Store is unreachable right now. Please try again." / "No previous purchase was found for this Apple Account."), and `PASPricingMath.savingsPercent` is line-for-line the app's line 65 computation including the `> 0` guards. Two things the flow does not do:
- The app retries `loadOffering()` once when the selected package is `nil` before erroring (`:124-126`). `PASPaywallFlow.purchase(nil, …)` errors immediately — keep the retry in the view model and hand the flow a non-nil package.
- `applyEntitlement` (`:162-173`) writes `appState.isPremium` and calls `refreshDay()`. `PASPaywallFlow` writes no app state by design; that stays in the view model, keyed off the flow's `Bool` return.

**Risk**
- **Localization — first-class here.** The two error strings are looked up with `String(localized:…, bundle: XTLocalization.bundle)` (`:128`, `:152`) and exist in all 7 languages. `PASPaywallFlow` takes them at `init`, so pass the localized values in and nothing regresses. Taking PASKit's defaults instead would silently ship English to de/es/fr/ja/ko/ru.
- Persisted keys: none.
- User-visible behaviour: unchanged if the load-retry is preserved. `PaywallViewModelTests.swift` exercises `loadOffering` through an injected `offeringProvider` — that seam is untouched.
- Design: none; `PaywallSheet` renders the labels.

**Effort** S–M.

**Recommendation** Adopt now. Replace `isPurchasing`/`errorMessage`/`isShowingError`/the two do-catch blocks with a `PASPaywallFlow` initialised with the app's localized copy, and swap lines 59-68 and 71-73 for `pasSavingsPercent` / `pasHasFreeTrial`.

---

### 4. `Animation.respectingReducedMotion` is declared twice

**App code** `XueTang/XueTang/ViewComponents/DesignSystem/Theme.swift:354-360` — `extension Animation { func respectingReducedMotion(_ reduceMotion: Bool) -> Animation? { reduceMotion ? nil : self } }`.

**PASKit equivalent** `Sources/PASKitCore/Styling/Animation+ReducedMotion.swift:11-21` — same name, same signature, same body.

**Fit** Exact. The bodies are identical. Nothing shadows anything today because `PASKitLifecycle` does not re-export `PASKitCore` (only the umbrella `Sources/PASKit/PASKit.swift:10` does), so the 22 files using it resolve to the app's copy; even if a file imported both, Swift prefers the same-module declaration. The duplicate is invisible and harmless — and precisely the "parallel local copy" the integration contract's rule 7 forbids.

**Risk** None functionally. The only cost is 22 files needing `import PASKitCore` added (51 call sites across `ViewComponents/`, `Features/`, `Core/`).

**Effort** S — one deletion plus mechanical imports.

**Recommendation** Adopt now. Consider `pasAnimation(_:value:)` at the same time for the call sites that only wrap a single `.animation(_:value:)`.

---

### 5. `HapticManager` re-implements `Haptics.play`

**App code** `XueTang/XueTang/Core/Services/HapticManager.swift:7-45` — `HapticType` (`.success` / `.error` / `.warning` / `.selection`), `play(_:)` mapping to `UINotificationFeedbackGenerator` / `UISelectionFeedbackGenerator`, and a static `isEnabled` reading `"settings.hapticsEnabled"` directly.

**PASKit equivalent** `PASHaptic` (`Sources/PASKitCore/Haptics/PASHaptic.swift:18-30` — `.light/.medium/.heavy/.rigid/.soft/.success/.warning/.error/.selection`) + `Haptics.play(_:isEnabled:)`.

**Fit** Exact on the four cases the app uses; PASKit's enum is a superset. The one real difference is the gate: PASKit requires the caller to pass `isEnabled`, deliberately, so the preference stays app vocabulary. The app reads the preference statically so that its four call sites (`LessonSession.swift:295,298,371`, `ExerciseChoiceButton.swift:117`) do not need the settings environment — a reasonable choice inside a `@MainActor` view model.

**Risk**
- Persisted key: `settings.hapticsEnabled` — the same key finding 2 touches. If both changes land, read the gate through the store once rather than from two places.
- `HapticEngine` (`Core/Services/HapticEngine.swift:77,92,125`) calls `HapticManager.isEnabled` three times. Keep that entry point alive.
- User-visible behaviour: unchanged — the generators are the same.
- Localization / design: none.

**Effort** S.

**Recommendation** Adopt now, but keep a one-line shim: `enum HapticManager { static func play(_ h: PASHaptic) { Haptics.play(h, isEnabled: isEnabled) } }`. That deletes the type-and-switch duplication and keeps `HapticEngine` and the four call sites untouched. `HapticEngine` itself is CoreHaptics (ramps, parameter curves, engine restart) and has no PASKit equivalent — it stays.

---

### 6. Bundled-font registration is hand-rolled

**App code** `XueTang/XueTang/XueTangApp.swift:163-178` — `registerBundledFonts()`, a loop over three font names calling `Bundle.main.url(forResource:withExtension:"ttf")` then `CTFontManagerRegisterFontsForURL`, discarding the error.

**PASKit equivalent** `PASFontRegistration.registerBundledFonts(named:bundle:)` (`Sources/PASKitCore/Styling/PASFontRegistration.swift:215-233`) — same `CTFontManagerRegisterFontsForURL(.process)`, but it logs missing files and failures through `PASLogger`.

**Fit** Exact, down to the workaround's motivation (both headers name `GENERATE_INFOPLIST_FILE` dropping `UIAppFonts`). PASKit takes file names *with* extension; the app passes bare names.

**Risk**
- Behaviour improves rather than changes: a font that silently failed to register now logs. `XueTangTests/FontRegistrationTests.swift` asserts the registered faces resolve via `UIFont(name:)` and does not touch the private method, so it stays green.
- Design: none — the same faces register, `XTFont.songTi`'s cascade is unaffected.

**Effort** S — one call, and `import PASKitCore` in `XueTangApp.swift`.

**Recommendation** Adopt now: `PASFontRegistration.registerBundledFonts(named: ["MaShanZheng-Regular.ttf", "NotoSerifSC-VariableFont_wght.ttf", "NotoSerifKR-Hangul-VariableFont_wght.ttf"])`.

---

### 7. Local `AppInfo` shadows PASKitCore's — and mixes with it in the same file

**App code** `XueTang/XueTang/Core/Configuration/AppInfo.swift:9-26` — `name` (a literal `"XueTang"`), `version` (`CFBundleShortVersionString`), `build` (`CFBundleVersion`), `versionLabel` (`"Version \(version) (\(build))"`), plus `supportEmail`, `feedbackEmail`, `termsURL`, `privacyURL`.

**PASKit equivalent** `AppInfo` (`Sources/PASKitCore/AppMetadata/AppInfo.swift`) — `version`, `build`, `versionWithBuild`, `displayName`, `bundleIdentifier`.

**Fit** Close for the metadata half, and there is a live hazard. `Core/Services/FeedbackService.swift` imports `PASKitCore` and on adjacent lines uses `AppInfo.version` / `AppInfo.build` (`:37-38`, resolving to the *app's* type by same-module preference) and `DeviceInfo.modelIdentifier` (`:39`, resolving to *PASKit's*). Both `AppInfo`s happen to read the same Info.plist keys so the values agree, but the name is ambiguous to every reader and the disagreement is one refactor away. Fallbacks differ (`"1.0"`/`"1"` locally vs `"—"` in PASKit) — never reached in a real bundle.

The support/legal URLs and emails are genuinely app vocabulary and have no PASKit equivalent, correctly. `AppInfo.name` is a hardcoded literal where PASKit's `displayName` reads `CFBundleDisplayName` → `CFBundleName`.

**Risk**
- **Localization.** `versionLabel` bakes an English `"Version "` prefix (`:20`) and is shown at `SettingsView.swift:171` and passed as `footerMessage` to the What's New sheet (`MainView.swift:105`) — untranslated in all 7 languages today. Moving to `AppInfo.versionWithBuild` plus an app-side `String(localized: "Version \(…)", bundle: XTLocalization.bundle)` fixes a real gap rather than creating one.
- Persisted keys: none.
- Design: none — the footer's layout is untouched.

**Effort** S.

**Recommendation** Adopt PASKitCore's `AppInfo` for `version` / `build`, and **rename the local type** (`XTLinks`, or move the four URLs onto an existing config enum) so `AppInfo` unambiguously means PASKit's inside this module. Keep the URLs and emails local; drop `name` in favour of `displayName` or keep it if the literal is deliberate.

---

### 8. `xtConcentricClip` duplicates `pasConcentricClip`

**App code** `XueTang/XueTang/ViewComponents/DesignSystem/Theme.swift:290-305` — `xtConcentricClip(fallbackRadius:)` + `XTConcentricClip`, `#available(iOS 26.0)` → `ConcentricRectangle()`, else `RoundedRectangle(cornerRadius: fallbackRadius, style: .continuous)`.

**PASKit equivalent** `View.pasConcentricClip(fallbackRadius:)` (`Sources/PASKitLifecycle/LiquidGlass/View+PasConcentricClip.swift:25`).

**Fit** Exact — same availability gate, same fallback shape, same parameter.

**Risk** None. Pure mechanism, no colours, no strings. Call sites already import SwiftUI; files using it need `import PASKitLifecycle`.

**Effort** S.

**Recommendation** Adopt now. This is a shim, not a design token — it does not belong in `Theme.swift`.

---

### 9. `ProgressStore` day/week arithmetic duplicates `Date.pas…`; the streak *engine* does not

**App code** `XueTang/XueTang/Core/State/ProgressStore.swift`
- `:439-447` `missedExactlyOneDay` — `dateComponents([.day], from: startOfDay(last), to: startOfDay(today)) == 2`.
- `:453-461` `dayGap` — the same expression, `max(0,·)`.
- `:465-473` `rolledStreak` — survives if last-active is today or yesterday.
- `:475-477` `weekStart(of:)` — `dateInterval(of: .weekOfYear)?.start`.
- `:396-398`, `:407-409` — `isDate(_:inSameDayAs:)` and `isDate(_:equalTo:toGranularity:.weekOfYear)`.
- `XueTang/XueTang/Core/State/AppState.swift:175-178` `isFirstActivityToday`.

**PASKit equivalent** `Date.pasDaysSince(_:)`, `.pasIsSameDay(as:)`, `.pasIsSameWeek(as:)`, `.pasStartOfWeek()`, `.pasStartOfDay()`, `.pasAdding(days:)` (`Sources/PASKitCore/Time/Date+PASCalendar.swift`); `PASStreakEngine.survivingStreak` / `.rolledOver` / `.recordingActivity` (`Sources/PASKitCore/Streak/PASStreakEngine.swift`).

**Fit** Split.
- The **date helpers are exact**: `dayGap` ≡ `today.pasDaysSince(last)` clamped, `missedExactlyOneDay` ≡ `pasDaysSince == 2`, `rolledStreak` ≡ `PASStreakEngine.survivingStreak`, `isFirstActivityToday` ≡ `!last.pasIsSameDay(as: .now)`, the granularity week compare ≡ `pasIsSameWeek`.
- The **engine is partial and should not be swapped**. `ProgressStore.rollover` (`:349-436`) does four things PASKit's does not: resets `dailyXP`/`dailyXPDay` (`:396-402`), resets `weeklyXP` on week change (`:404-413`), tops premium users **back up to the cap** rather than granting +1 (`:421-425`), and reports `streakLost` for a 7+ day lapse to drive the welcome-back card (`:378-389`). It also grants free freezes on a **calendar-month** rule (`StreakFreeze.monthlyGrantDue`) where `PASStreakConfig.freeFreezeInterval` is a fixed `TimeInterval` — a behaviour change, not a refactor. And the state is SwiftData rows, not a `Codable` `PASStreakState`.

One caveat on `weekStart`: `ProgressStore.weekStart` uses `dateInterval(of: .weekOfYear)?.start` while `pasStartOfWeek()` builds from `[.yearForWeekOfYear, .weekOfYear]` components. Both honour `firstWeekday` and agree in practice, but the value is persisted (`progress.weekStart`) and compared with granularity, so verify before swapping that one.

**Risk**
- **Persisted state.** `lastActiveDay`, `weekStart`, `dailyXPDay`, `freezeBalance`, `lastFreeFreezeGrantedAt` are all SwiftData columns mirrored to Firestore (`BackendDTOs`). Any arithmetic change moves live streaks. `ProgressStoreTests.swift` covers the rollover — run it.
- User-visible behaviour: a streak reset is the most visible thing this app can do. Treat the engine as off-limits.
- Localization / design: none.

**Effort** S–M for the helpers alone.

**Recommendation** Adopt the `Date.pas…` helpers inside the existing static methods — that deletes ~30 lines of `dateComponents` boilerplate while leaving every behaviour and every test assertion intact. Leave `PASStreakEngine` alone until PASKit grows top-up-to-cap grants, calendar-month intervals, and a lapse-magnitude outcome; if XueTang is the app that wants them, extend PASKit rather than converge the app onto weaker semantics.

---

### 10. Clock formatting is hand-rolled

**App code** `XueTang/XueTang/Features/Lesson/ViewModel/LessonSession.swift:133` — `String(format: "%d:%02d", seconds / 60, seconds % 60)`.

**PASKit equivalent** `PASDurationFormat.clock(seconds:)` (`Sources/PASKitCore/Time/`), which produces `"4:12"` under an hour and `"1:04:12"` over.

**Fit** Exact for sub-hour durations, and strictly better above one hour — the current format would render a 65-minute session as `"65:00"`.

**Risk** A lesson never runs an hour, so this is cosmetic. No persisted key, no string catalog entry (it is a formatted number).

**Effort** S.

**Recommendation** Adopt now. One line.

---

### 11. What's New migration leftover: strings bypass `XTLocalization.bundle`

**App code**
- `XueTang/XueTang/Features/System/Models/ReleaseHighlights.swift:26,27,31,32,36,37,41,42,46,47` — ten `String(localized: "…")` calls with **no** `bundle:` argument.
- `XueTang/XueTang/Features/Main/View/MainView.swift:104` — `title: String(localized: "What's New")`, same omission.

**PASKit equivalent** None — this is app-side. Listed because it is what the 2026-09-03 migration left behind, and because it is exactly the localization trap the migration was supposed to avoid.

**Fit** n/a — a defect, not a duplication.

**Risk** First-class. Per D-20 (`Core/Configuration/XTLocalization.swift:7-18`), `String(localized:)` outside a `View` resolves against the *process* localization, fixed at launch by the `AppleLanguages` override — not against the learning language the user just picked. 177 of the app's `String(localized:)` calls correctly pass `bundle: XTLocalization.bundle`; these 11 do not. All the keys do exist with de/es/fr/ja/ko/ru translations in `XueTang/XueTang/Resources/Localizable.xcstrings` (verified), so nothing is missing — but a user who switches learning language mid-session gets a What's New sheet still in the previous language until the next cold start, while every other screen has already switched. `AppInfo.versionLabel` passed as `footerMessage` on `MainView.swift:105` has the same problem for a different reason (see finding 7): its `"Version "` prefix is never localized at all.

**Effort** S — add `bundle: XTLocalization.bundle` to 11 call sites.

**Recommendation** Fix now, in the same pass as finding 7.

---

### 12. `XTFont.scaled` vs `Font.pasScaled` — partial

**App code** `XueTang/XueTang/ViewComponents/DesignSystem/Theme.swift:225-229` (`scaled`), `:204-208` (`mono`), `:174-189` (`songTi`).

**PASKit equivalent** `Font.pasScaled(_:relativeTo:weight:design:)` (`Sources/PASKitCore/Styling/Font+PASScaled.swift:26-42`).

**Fit** Partial. The scaling mechanism is identical (`UIFontMetrics(forTextStyle:).scaledFont(for:)`), but `XTFont.scaled` takes a **`UIFont.TextStyle`** while `pasScaled` takes a **SwiftUI `Font.TextStyle`** and maps internally. Every one of the ~90 `XTFont.scaled(…, relativeTo: .footnote)` call sites passes a `UIFont.TextStyle`; swapping the parameter type touches all of them. `XTFont.mono` and `XTFont.songTi` are further out — `mono` wants `monospacedSystemFont`, `songTi` wants a cascade-list descriptor across two variable fonts, neither of which `pasScaled` can express.

**Risk** Design and Dynamic Type across every screen, for zero behaviour change. Not worth it.

**Effort** M (mechanical but wide).

**Recommendation** Leave. If the duplication ever bites, reimplement `XTFont.scaled`'s *body* over `Font.pasScaled` while keeping the `UIFont.TextStyle` signature — one line changed, no call sites touched.

---

### 13. Dev overlay + dev menu — partial

**App code** `XueTang/XueTang/Development/DevelopmentOverlay.swift:8-50` (floating "DEV" capsule, `#if DEBUG`-wrapped file, `.sheet` presentation) and `XueTang/XueTang/Development/DevelopmentMenuView.swift:19-243` (a `NavigationStack` + `ScrollView` of `DevSectionShell` cards with a Done toolbar item).

**PASKit equivalent** `View.pasDevelopmentOverlay(alignment:menu:)` + `PASDevelopmentMenu(title:content:)` (`Sources/PASKitLifecycle/Development/`).

**Fit** Partial, and rejected on design. PASKit's menu is a `NavigationStack` + `Form` + Done; the app's is a `ScrollView` of `xtCard(radius: 16)` panels on `xtParchmentBackground()`, and the DEV capsule is `xtAccentSecondary` with a hammer glyph and an `accessibilityIdentifier("DEV_OVERLAY")` that automation may depend on. `PASDevelopmentMenu` exposes no container slot, so adopting it means a system `Form` inside a parchment app.

**Risk** Design regression in the one surface where design does not matter — which is also why the trade is not worth making in either direction. No persisted keys, no shipped strings (DEBUG only).

**Effort** M.

**Recommendation** Leave. Revisit only if `PASDevelopmentMenu` grows a container slot the way `WhatsNewView` has.

---

### 14. `UpdateRequiredSheet` — partial, and currently inert

**App code** `XueTang/XueTang/Features/System/View/ViewComponents/UpdateRequiredSheet.swift:6-61`, presented from `MainView.swift:77` on `AppRouter.showUpdateRequired` (`AppRouter.swift:48`). The **only** writers are two DEBUG buttons (`SettingsView.swift:221`, `DevelopmentMenuView.swift:191`). Nothing computes whether an update actually exists, and the App Store URL is a placeholder TODO (`:10-14`).

**PASKit equivalent** `VersionCheckManager` + `AppUpdateView(update:forceUpdate:)` (`Sources/PASKitLifecycle/Update/`).

**Fit** Partial in both directions. The **missing** half — `VersionCheckManager.checkIfAppUpdateAvailable()`, which hits the iTunes lookup API, compares against `AppInfo.version` and hands back a `Result` carrying the store URL — is exactly what would make this gate real, and would also resolve the placeholder URL TODO. The **present** half — the sheet — is fully branded (`XTCapsuleButton`, `XTFont.songTi`, `xtParchmentBackground`, the 需要更新 subtitle) and its copy is in the string catalog; `AppUpdateView` takes no chrome slots, so adopting it costs the design and moves 3 strings.

**Risk** Localization on the swap (3 catalog keys × 7 languages); design on the swap. No persisted keys.

**Effort** M.

**Recommendation** Keep `UpdateRequiredSheet`. Adopt `VersionCheckManager` on its own to drive `showUpdateRequired`, if and when a forced-update gate is actually wanted — that is an addition, not a replacement, and it is the piece the app is missing rather than duplicating.

---

## Documented vs. actual

Checked against the `## PASKit (linked)` section of `XueTangV2/CLAUDE.md`.

| Claim | Actual | Verdict |
|---|---|---|
| `PASKitAnalytics` — "**Stub today** — namespace placeholder only… until then, use the PostHog SDK directly" | v0.3.1 ships a complete 115-line facade (`Sources/PASKitAnalytics/PASAnalytics.swift`) with PostHog pinned in `Package.swift:30`. `README.md` documents the full surface. | **Drift — the most consequential.** The claim is why `FeedbackService` still hand-rolls HTTP capture (its own comment at `:9` says "when… PASKitAnalytics land (R5)"). Three stale references: `CLAUDE.md`'s module table and Rules bullet, `FeedbackService.swift:9`, `ToneAttemptScorer.swift:88`. Also note the app never adopted the PostHog SDK directly either, so "use the SDK directly" was never acted on. |
| Dependencies table: "PostHog — Analytics… R5 onward" | No SDK linked; one raw `URLRequest` in `FeedbackService`. | Accurate for today, but should become "consumed via `PASKitAnalytics`" once finding 1 lands. |
| "`XueTang.xcodeproj` consumes it as a **remote** SPM reference — `upToNextMinorVersion` from `0.3.0`, umbrella `PASKit` product" | `project.pbxproj:565-570` — `https://github.com/moritztucher/PASKit.git`, `upToNextMinorVersion`, `minimumVersion = 0.3.0`; `:605-608` links product `PASKit`. `Package.resolved` pins `0.3.1`. | **Accurate.** |
| "**All** RevenueCat operations go through `PASPurchases` — no direct `Purchases.…` calls from app code" | Zero `Purchases.` call sites; `PASPurchases` used in `XueTangApp.swift:38,40,124` and `PaywallViewModel.swift:35,135,149`. `import RevenueCat` appears only for the pass-through types (`Offering`, `Package`, `CustomerInfo`), which the contract sanctions. | **Accurate.** Sub-note: the paywall still hand-rolls the flow PASKit now ships (finding 3), so "all operations go through it" is true while "we use what it ships" is not yet. |
| "**All** `UNUserNotificationCenter` operations go through `PASNotifications`" | Zero `UNUserNotificationCenter` references. `ReminderService.swift` wraps `PASNotifications` behind a `ReminderScheduling` seam; `import UserNotifications` only for `UNAuthorizationStatus`. | **Accurate.** |
| "Use `PASLogger.make(category:)` instead of raw `os.Logger`" | Zero `os.Logger` / `OSLog` / `NSLog` / `print(` in the target; `PASLogger` in 15 files. | **Accurate.** |
| "`AppInfo` / `DeviceInfo` instead of `Bundle.main` / `UIDevice`" | A local `AppInfo` shadows PASKit's and reads `Bundle.main` itself (`Core/Configuration/AppInfo.swift:13,17`). `FeedbackService.swift:37-39` mixes both types in three consecutive lines. Zero `UIDevice`. | **Drift.** See finding 7. |
| "`KeychainCredentialVault` instead of raw Keychain access" | No raw Keychain access anywhere — the eight "Keychain" hits are comments about Firebase/Google's own session storage (`FreshInstallGuard.swift`). | **Accurate — nothing to change.** |
| "Before writing a local utility for… rate prompt, what's-new, update check, feedback, or settings footer — check PASKit first" | What's New: done. Feedback: PASKit's `FeedbackPayload` adopted, form deliberately local. Update check: `UpdateRequiredSheet` written locally with no `VersionCheckManager` (finding 14). Settings footer: written locally (rejected below, correctly). Rate prompt: a manual Settings row via `@Environment(\.requestReview)` — not the two-stage `presentAppRating`, and not a duplicate of it. | **Mostly honoured.** |
| "What's New is PASKit's… Card strings are `String(localized:)`… Keep the keys byte-identical" | Keys are byte-identical and all present in the catalog for de/es/fr/ja/ko/ru. But 11 call sites omit `bundle: XTLocalization.bundle`, which the rest of the app passes 177 times. | **Drift.** See finding 11. |
| "Not adopted: `ReleaseNote` and `WhatsNewGate`… no automatic post-update presentation and no changelog screen" | Confirmed: no `ReleaseNote`, no `WhatsNewGate`, no `ChangelogView`; `showWhatsNew` is only ever set from Settings (`SettingsView.swift:165,219`) and the dev menu (`DevelopmentMenuView.swift:189`). | **Accurate, and the reasoning still holds.** |

---

## Looks like a match but isn't

- **`SettingsView` version footer → `AppInfoFooter`.** `SettingsView.swift:146-195` looks like PASKit's `AppInfoFooter` (icon + name + version) but is a `Button` that opens the What's New sheet, and its "icon" is a hand-drawn `RoundedRectangle` + `XTFont.brushScript` 学 mark, not `CFBundleIcons`. `AppInfoFooter` takes no slots and is not tappable. Adopting it would cost the brush mark, the tap target, and the `xt*` typography for a five-line saving. Rejected.

- **`XTFeedbackSheet` → `FeedbackSheet`.** The app already does the right thing: it adopts PASKit's `FeedbackPayload` (`XTFeedbackSheet.swift:1,167`) and owns the form. The form is parchment + Song-Ti header + `XTFilterChip` category chips + `XTCapsuleButton`, and its ~10 labels are in the catalog in 7 languages. `FeedbackSheet` exposes only `heroSymbol` / `initialName` / `initialEmail` / `showsCloseButton` — no container slots — so swapping means a system `Form` in a hand-painted app *and* re-keying every string. The contract explicitly blesses this arrangement ("apps with a locked design language can skip `FeedbackSheet`"). Rejected, correctly.

- **`PASStreakEngine` → `ProgressStore.rollover`.** Reads like a drop-in and is not: four app-specific responsibilities and two different freeze semantics. Detail in finding 9. Rejected for the engine, accepted for the date helpers.

- **`FreezeSavedNotice` → `pasToast` / `PASToast`.** `FreezeSavedNotice.swift` is a dismissible notice with a snowflake and an ⓧ — visually a toast. But it is mounted inline in `PathView`'s content stack (`PathView.swift:76-78`), persists until tapped, and clears via `AppState.streakSavedByFreeze`. `pasToast` is an *overlay* with auto-dismiss after a duration. Adopting it would change where the notice sits, when it disappears, and how the Path lays out. Rejected.

- **`ProfileStatRing` / `DailyGoalRing` / `MemoryRing` → `PASProgressRing`.** `PASProgressRing` fills its arc from `.tint` — a single `Color`. `ProfileStatRing` fills with a conditional `LinearGradient` (`:15-21`), `DailyGoalRing` swaps the whole fill for a checkmark when the goal is met (`:31-35`), `MemoryRing` encodes FSRS retention in its gradient. None survives a `.tint`-only fill. Rejected. (`DailyGoalRing`'s own header already documents why it did not share with `MemoryRing` either — the app has thought about this.)

- **`@Environment(\.requestReview)` in `SettingsView:14,111` → `presentAppRating`.** Different mechanisms: the app ships a manual "Review the App" row the user taps deliberately; `presentAppRating` is an automatic two-stage prompt gated on caller-supplied thresholds with its own `@AppStorage` one-shot state. Adding it would be a new feature, not a replacement. Not a duplication.

- **`URLSessionNetworkService` — already adopted, and it is the only networking in the app.** `FeedbackService.swift:20,23` is the sole `URLSession` reference in the target. Nothing to replace.

- **`ExerciseChoiceButton`'s press-scale → `.buttonStyle(.pasPressable(haptic:))`.** `Features/Lesson/View/ViewComponents/Exercises/ExerciseChoiceButton.swift:37,54,60-70,116-119` is a press-scale-plus-haptic button and reads like a `PASPressableButtonStyle` call site. Three differences make it a bad swap. (a) **Reduce Motion:** the app wraps both edges in `XTMotion.press` / `XTMotion.reveal` `.respectingReducedMotion(reduceMotion)`; `PASPressableButtonStyle` hardcodes `.spring(response: 0.2, dampingFraction: 0.6)` and honours nothing — adopting it would regress an accessibility behaviour the app deliberately implements. (b) **Motion vocabulary:** the app uses two different curves for press-down and release, matching `XTMotion`; PASKit uses one. (c) **Haptic timing:** the app fires `.selection` in `handleTap` (on the action), PASKit fires it on the press-down edge. Rejected until `pasPressable` grows a Reduce Motion path — a reasonable PASKit extension if a second app wants it.

- **`.ultraThinMaterial` fills → `pasGlass`.** Four uses (`ImportWordsView.swift:241`, `UnitCard.swift:237,246,255`) are `Circle().fill(.ultraThinMaterial)` / a `.background` — shape fills inside a composed view, not the card/sheet surfaces `pasGlass(in:)` is scoped to, and none of them wants an iOS 26 `glassEffect` on a hand-painted parchment ground. Rejected.

- **Reachability, App Group storage, credentials/keychain, `PASError`, sharing/export, the onboarding engine, toasts, the loading overlay, `PASDraft`, `ChangelogView`, `MailComposerView` — nothing found.** No `NWPathMonitor` or offline UI; no App Group suite or container; no raw Keychain calls; no app error domain worth folding into `PASError` (the one `LocalizedError`, `ContentService.ContentError:777`, is content-specific); no `ImageRenderer`/`ShareLink`/`UIActivityViewController`/Instagram/Photos code; onboarding is two standalone step views (`Features/Onboarding/View/`), not a multi-step flow an engine would serve; no toast; no blocking loading overlay (the eight `ProgressView()` uses are all inline, in-place spinners); no draft persistence; no changelog screen; no mail composer. These categories are clean.
