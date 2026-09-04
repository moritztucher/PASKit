# XueTang V2 → PASKit extraction audit

**Date:** 2026-09-04 · **PASKit:** v0.3.1 · **App:** `XueTangV2`, branch `develop-xt2-revamp`, `0d5d743b9`

Repo audited: `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2` (app target `XueTang/XueTang/`, 343 Swift files incl. 63 test files). Cross-checked against `/Users/moritztucher/Private/WorkoutApp` and `/Users/moritztucher/Private/CoupleCalorieTracker`. Read-only — no app source was modified.

---

## Summary

XueTang is the studio's most mature app and it does own real app-agnostic mechanism, but the cross-app evidence is thinner than expected: WorkoutApp and CoupleCalorieTracker are both offline, account-less, single-stack apps, so almost every heavyweight capability here (auth, backend sync, deep-linking, quick actions, in-app language switching, a paywall) exists in exactly one app today. Under "build on real need" that makes most of the list *extract-when-a-second-app-needs-it* rather than *extract-now*. The genuine extract-now set is small and unglamorous: the UIKit quick-action bridge (pure platform boilerplate with zero vocabulary), the audio-session lifecycle (the one place WorkoutApp already has a cruder twin), the in-app language override (fully generic, subtle enough that a second implementation would be wrong), and one missing field on a PASKit type the app itself donated. The larger finding is the reverse of the brief: **this app runs parallel local copies of five things PASKit already ships** — the streak engine, the settings store, haptics, the dev overlay, and font registration — and the streak copy has forked forward. Reconciling that is worth more to the studio than any new module, because it is where "a capability implemented twice is a bug" is currently being violated in the donor app itself.

| # | Candidate | Proposed PASKit module | Second-app evidence | Effort | Recommendation |
|---|---|---|---|---|---|
| 1 | Streak lapse-length outcome + migrate app back onto `PASStreakEngine` | `PASKitCore/Streak` (extend) | PASKit already owns it; WorkoutApp has a 3rd, week-granular copy | S | **Extract now** |
| 2 | Home Screen quick-action bridge | `PASKitLifecycle/QuickActions` (new) | none — single app today | S | **Extract now** |
| 3 | Audio-session lifecycle (duck / deactivate-when-idle / interruption) | `PASKitCore/Audio` (new folder) | **yes** — `WorkoutApp/Core/Services/RestEndSound.swift:26-49` | S | **Extract now** |
| 4 | In-app language override (`String(localized:)` bundle + `AppleLanguages`) | `PASKitCore/Localization` (new folder) | none — both siblings ship `en` only | M | **Extract now** |
| 5 | Firebase auth facade (Apple + Google + anonymous link + deletion) | `PASKitAuth` (new module) | none — neither sibling has accounts | L | Extract when a second app needs accounts |
| 6 | Doc-level last-write-wins `SyncPolicy` | `PASKitCore/Sync` (new folder) | none | S | Extract when a second app syncs |
| 7 | Confetti burst + seeded RNG | `PASKitLifecycle/Indicators` | none (WorkoutApp has milestones, no confetti) | S | Extract when a second app celebrates |
| 8 | CoreHaptics ramp/curve (`rise`, `flourish`) | `PASKitCore/Haptics` (extend) | partial — `WorkoutApp/Core/Services/RestEndHaptics.swift:6` | M | Extract when a second app needs a curve |
| 9 | `PriceLoadState` for the paywall | `PASKitPurchases` (extend) | none — WorkoutApp links RevenueCat but ships no paywall | S | Extract when a second app builds a paywall |
| 10 | Font cascade + glyph-coverage fallback | `PASKitCore/Styling` (extend) | none | M | Extract when a second app ships a script font |
| 11 | `Color(hex:)` (from `CLLDesign`, not the app) | `PASKitCore/Styling` (extend) | **yes** — `CLLDesign` + MandarinToneTrainer | XS | Extract now (trivial) |

---

## Already in PASKit — migrate, don't extract

Not extraction candidates, but the highest-value finding. Each is a local copy of something the app already links:

| Local copy | PASKit equivalent |
|---|---|
| `.../Core/State/ProgressStore.swift:349` `rollover(today:calendar:isPremium:)` + `:439` `missedExactlyOneDay` + `:453` `dayGap` + `:465` `rolledStreak` | `PASStreakEngine.rolledOver` / `.survivingStreak` — whose header explicitly says "Extracted from a shipped learning app's engine". This app is that donor and has since forked. |
| `.../Core/State/SettingsStore.swift:12` — 24 hand-written `didSet` write-throughs against a `private enum Key` | `PASSettingsStore` + `@PASDefault` (one line per setting) |
| `.../Core/Services/HapticManager.swift:14` + its own `UserDefaults` gate read at `:40` | `PASKitCore.Haptics.play(_:isEnabled:)` |
| `.../Development/DevelopmentOverlay.swift:10` `View.developmentOverlay()` | `View.pasDevelopmentOverlay` + `PASDevelopmentMenu` |
| `.../XueTangApp.swift:163` `registerBundledFonts()` | `PASFontRegistration.registerBundledFonts(named:)` |
| `.../Core/Configuration/AppInfo.swift:9` `enum AppInfo` — **shadows** PASKitCore's `AppInfo` in this module | `PASKitCore.AppInfo` (`.version` / `.build` / `.versionWithBuild`) |
| `.../Features/System/View/ViewComponents/UpdateRequiredSheet.swift:6`, with a hardcoded front-page App Store URL at `:14` and no version source | `VersionCheckManager` + `AppUpdateView(update:forceUpdate: true)` |
| `.../Features/Commerce/ViewModel/PaywallViewModel.swift:54` hand-rolled savings math, `:121`/`:145` hand-rolled purchase/restore state machine | `StoreProduct.pasSavingsPercent(comparedToMonthly:)`, `.pasHasFreeTrial`, `PASPaywallFlow` |

The app also ships none of `presentAppRating`, `presentAppFeedback`, `pasToast`, `PASProgressRing`, `pasPressable`, `PASDraft`, `PASOnboardingFlow` despite having surfaces for most of them (grep for those symbols in the app target returns zero hits).

---

## Candidates

### 1. Streak lapse-length outcome — and migrating the app back onto `PASStreakEngine`

**What it is.** `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/State/ProgressStore.swift:349` `rollover(today:calendar:isPremium:)`, returning `RolloverOutcome` (`:318`), with pure helpers `missedExactlyOneDay` (`:439`), `dayGap` (`:453`), `rolledStreak` (`:465`). Consumed by `.../Core/State/AppState.swift:244` `refreshDay(now:)` and re-run on `scenePhase == .active` at `.../XueTangApp.swift:141`.

Order-for-order this is `PASStreakEngine.rolledOver` — consume-before-grant, one-day-only freeze coverage, at-cap grants that skip without advancing the timestamp. It has forked in exactly three places: (a) `outcome.streakLost` carries *how many days* the lapse cost, not just that a reset happened (PASKit has only `streakDidReset: Bool`); (b) a 7+ day gap is flagged separately to drive the welcome-back surface; (c) freeze grants branch on a premium flag (top-to-cap) versus a free cadence.

**Why it is mechanism, not vocabulary.** PASKit already decided this is mechanism — the module exists and this app is the documented donor. The three deltas are all still mechanism: a lapse length is a number, a lapse-length threshold is a caller-supplied `Int`, and "premium tops up to cap" is `freeFreezeInterval: 0` plus a cap. None of it mentions lessons, XP or Chinese.

**Proposed home.** `Sources/PASKitCore/Streak/PASStreakEngine.swift` — add `streakLost: Int` and `gapDays: Int` to `PASStreakRolloverOutcome`; both are already computed internally by `survivingStreak`/`pasDaysSince` and thrown away. The daily/weekly XP counter resets at `ProgressStore.swift:396-413` stay app-side — `CLAUDE-INTEGRATION.md` §4d already documents the `pasIsSameWeek` recipe for them.

**What the app injects.** `PASStreakConfig(freezeCap: StreakFreeze.cap, freeFreezeInterval: isPremium ? 0 : 30*24*3600)`, and its own `lapseThresholdDays = 7` comparison against `outcome.gapDays`. Persistence stays in SwiftData: `PASStreakState` is `Codable` and maps 1:1 onto the five fields `ProgressStore` already stores.

**Second-app evidence.** PASKit itself is the second consumer. A *third* implementation exists at `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Utilities/WorkoutStreak.swift:7` (`weeks(now:firstWeekday:hasSession:)`, `longestRun`) — week-granular, so it is genuinely a different engine and should **not** be forced onto `PASStreakEngine`; note it only as proof that streak code gets rewritten per app when the shared one doesn't fit.

**Effort.** S (two fields + a migration of `AppState.refreshDay`; the app's `ProgressStoreTests` already pin the behaviour).

**Recommendation.** **Extract now.** This is the one place the studio's own anti-duplication rule is being broken by the donor app.

---

### 2. Home Screen quick-action bridge

**What it is.** Four small pieces:
- `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/XueTangAppDelegate.swift:9` `XueTangAppDelegate` → installs `XueTangSceneDelegate` (`:19`), which buffers a cold-start shortcut from `connectionOptions` (`:22-28`) and a warm-resume one from `performActionFor` (`:31-40`).
- `.../Core/Navigation/QuickAction.swift:26` `QuickActionCenter` — `@Observable @MainActor` singleton with a `PendingQuickAction` (`:17`, fresh `UUID` per tap so a repeat re-triggers a keyed `.task`) and a consume-once `take()` (`:34`).
- `.../Core/Navigation/QuickAction.swift:42` `QuickActionPolicy.canConsume(contentLoaded:lessonActive:drillActive:)` — a shortcut never fires into a half-ready tree or on top of a modal.
- `.../Core/Services/QuickActionService.swift:11` — builds and installs `UIApplication.shared.shortcutItems`.

**Why it is mechanism, not vocabulary.** The whole thing exists because SwiftUI has no cold-start shortcut API: a shortcut tapped from a cold launch arrives only through `UIScene.ConnectionOptions` and `performActionFor` is *not* called. That gap is the platform's, identical in every SwiftUI app, and the code above contains nothing app-specific except the three `rawValue` strings at `QuickAction.swift:9` and the SF Symbol/title triples at `QuickActionService.swift:49-73`. The buffer-plus-consume-once shape and the readiness gate are the reusable parts; both are already UIKit-free and unit-tested (`XueTangTests/QuickActionTests.swift`).

**Proposed home.** New `Sources/PASKitLifecycle/QuickActions/` — it is app-lifecycle plumbing, same family as the dev overlay and the what's-new gate, and iOS-only, which `PASKitLifecycle` already is. Shape: `PASQuickActions.shared` (`pending`, `take()`, `setItems([PASQuickActionItem])`) plus `PASQuickActionSceneDelegate` and a `PASQuickActionsAppDelegate` the app adopts via `@UIApplicationDelegateAdaptor`, mirroring how `PASNotifications.configure()` installs the one notification-center delegate.

**What the app injects.** Its `QuickAction` enum as `[PASQuickActionItem(type:title:subtitle:systemImage:)]`, refreshed on `scenePhase == .background`, and its own readiness predicate at the drain site.

**Second-app evidence.** None — single app today. WorkoutApp has no `AppDelegate` at all (`WorkoutAppApp.swift:5-6`) and no shortcut items; CoupleCalorieTracker's `App/CoupleCalorieTrackerApp.swift` is a 9-line `WindowGroup`. That is an argument *for* extraction rather than against: neither has shortcuts partly because wiring the UIKit bridge by hand is the cost, and PASKit removing that cost is exactly the "makes apps 3, 4, 5 cheap" case.

**Effort.** S — ~120 lines, no dependencies, no design surface.

**Recommendation.** **Extract now.**

---

### 3. Audio-session lifecycle

**What it is.** Inside `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Services/AudioService.swift:20`, three private members that have nothing to do with Chinese:
- `:227` `activateSession()` — one-time `setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])`, then `setActive(true)`.
- `:242` `deactivateSessionIfIdle()` — releases the session with `.notifyOthersOnDeactivation` only once nothing is speaking, playing or queued, so other apps' audio returns to full volume.
- `:251` `observeInterruptions()` — an async `NotificationCenter.notifications(named: AVAudioSession.interruptionNotification)` loop that hard-stops on `.began`, cancelled in `deinit` (`:68`).

**Why it is mechanism, not vocabulary.** The category/mode/options triple is a *policy* the caller picks; everything else — activate-once, deactivate-only-when-idle, stop-on-interruption, cancel the observer on deinit — is the correct lifecycle for any app that plays audio, and getting it wrong is why apps leave background music ducked after playback ends. Nothing here knows about hanzi, voices or clips; the Mandarin parts (`Voice`, `mandarinVoices()` at `:215`, the syllable-scheduling at `:146`) are cleanly separable and stay put.

**Proposed home.** New `Sources/PASKitCore/Audio/PASAudioSession.swift` — `PASKitCore`, not `PASKitLifecycle`, because it is a service primitive with no UI, alongside `Reachability` and `Haptics`. Shape: `PASAudioSession(category:mode:options:)` with `activate()`, `deactivateIfIdle(isBusy: () -> Bool)` (or an explicit `release()`), and an `onInterruption` hook. AVFoundation is a system framework, so it adds no dependency.

**What the app injects.** The session policy (`.playback`/`.spokenAudio`/`.duckOthers` here; WorkoutApp would pass `.mixWithOthers`), the idle predicate, and its own stop behaviour.

**Second-app evidence.** **Yes — the clearest twin in the audit.** `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Services/RestEndSound.swift:26` sets `AVAudioSession(.playback, options: [.mixWithOthers])`, holds the player strongly at `:16`, and deactivates with `.notifyOthersOnDeactivation` in `audioPlayerDidFinishPlaying` at `:41-49` — the same lifecycle, one policy flag different, and **missing the interruption observer** XueTang has. That asymmetry is the argument: WorkoutApp has the bug XueTang already fixed.

**Effort.** S.

**Recommendation.** **Extract now.**

---

### 4. In-app language override

**What it is.** A three-part mechanism for letting the user pick the app's language inside the app, rather than in iOS Settings:
- `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Configuration/XTLocalization.swift:25` — a `nonisolated enum` exposing `bundle` (`:36`) and `setLanguage(_:)` (`:40`), backed by a lock-guarded `@unchecked Sendable` box (`:46`) because the bundle is written from the main actor and read from a detached decode. Its 20-line header documents the actual trap: `Text("key")` follows `\.locale` from the environment, but `String(localized:)` outside a View resolves against the **process's** preferred localization, fixed at launch — so every ViewModel/mapper string stays in the launch language until a cold restart unless you hand it an explicit `.lproj` bundle. English is deliberately **not** special-cased to `.main` (`:33-35`).
- `.../Core/State/SettingsStore.swift:265` `setLearningLanguage(_:)` — writes the `AppleLanguages` override (`:274`) only on an actual change, because iOS's own per-app language setting writes the same key and an unconditional write fights it; repoints `XTLocalization` in the same call so the pick lands in-session.
- `.../Core/State/SettingsStore.swift:279` `defaultLearningLanguage(preferred:shipped:)` — first device-preferred language inside the shipped set, else `"en"`; and `:293` `resolvedLearningLanguage(defaults:)`, readable off the main actor. Applied at the root by `.../XueTangApp.swift:36` (before the first string is built) and `:102` (`.environment(\.locale, …)`).

**Why it is mechanism, not vocabulary.** Every line above is about *how* iOS resolves localizations; not one is about Chinese. The app's vocabulary is entirely in `.../Core/Configuration/LearningLanguages.swift:12` — the native display names and the "shipped means a gloss file is bundled" rule (`:35`) — which stays local. The four traps this encodes (process vs. environment locale, the `AppleLanguages`/Settings conflict, `en` not being `.main`, and the concurrency-safe cache) are precisely the kind of thing a second implementation gets wrong; the app has a test suite for it at `XueTangTests/XTLocalizationTests.swift` and `LearningLanguageTests.swift`.

**Proposed home.** New `Sources/PASKitCore/Localization/PASLocalization.swift` — `PASKitCore`, with the styling and settings primitives, since it is `Foundation`-only. Shape: `PASLocalization.bundle` / `.setLanguage(_:)`, `PASLocalization.deviceDefault(among:preferred:)`, and `PASLocalization.applyOverride(_:in:)` for the `AppleLanguages` write. PASKit ships no string catalog and this does not change that — it hands *the app's* catalog the right bundle.

**What the app injects.** The set of shipped codes, the display names, its own persistence key, and the `.environment(\.locale, …)` call at its own root.

**Second-app evidence.** None — single app today. `WorkoutApp/WorkoutApp/Resources/Localizable.xcstrings` is 742 keys with `en` as the only localization; `CoupleCalorieTracker/CoupleCalorieTracker/Localizable.xcstrings` is likewise `en`-only, and its `Scripts/sync-strings.sh` is a 13-line `xcstringstool sync` wrapper with no locale handling. Neither has any bundle/locale override.

**Effort.** M — the code is small, but it wants a doc section in `CLAUDE-INTEGRATION.md` explaining the process-vs-environment split, or callers will use it wrongly.

**Recommendation.** **Extract now.** It is fully generic, already shipping, and the cheapest thing in this list to get wrong twice. (If the studio's position is "no second app is localized, so leave it" that is a defensible read of the philosophy — but then it should be revisited the moment app 2 adds a second language, and this section is the pre-written spec.)

---

### 5. Firebase auth facade

**What it is.** Three files under `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Services/Backend/`:
- `FirebaseAuthService.swift:26` — `@MainActor @Observable`, exposing `uid` / `isAnonymous` / `displayName` / `email` / `lastError` / `busyFlow`. `signInAnonymouslyIfNeeded()` (`:75`), `prepareAppleRequest(_:)` (`:108`, sets scopes + hashed nonce and flips the busy flag from the request-builder closure because the native button has no start callback), `signInWithGoogle()` (`:157`, including the `topViewController()` window-scene walk at `:198`), `linkOrSignIn(with:fullName:)` (`:209`, which upgrades an anonymous guest in place and recovers from `credentialAlreadyInUse` via `AuthErrorUserInfoUpdatedCredentialKey`), `deleteAuthUser()` (`:289`, best-effort Apple token revocation for App Store guideline 5.1.1(v), and `.requiresRecentLogin` as a first-class result), and the canonical `randomNonceString`/`sha256` pair (`:326`, `:348`).
- `FirebaseBootstrap.swift:17` — `configure()` is a deliberate no-op without a bundled `GoogleService-Info.plist`, so every backend entry point guards on `isConfigured` and the app runs local-only until the plist lands.
- `FreshInstallGuard.swift:25` — `resetIfFreshInstall()` (`:33`) signs out of Firebase and Google on the first launch after a delete+reinstall, because iOS wipes `UserDefaults` and the store but **not** the Keychain, and both SDKs persist their session there.

**Why it is mechanism, not vocabulary.** There is nothing about Chinese, lessons or XueTang in any of it — the only app-specific line is the log category. Every non-obvious behaviour is a platform or store requirement: the nonce is Firebase's replay protection, the link-then-recover dance is what Apple/Google identity reuse forces, the revocation is a review-guideline requirement, the fresh-install guard is a Keychain-survives-reinstall fact. Wrapping a vendor SDK thinly as a concrete facade is explicitly PASKit's pattern (RevenueCat, PostHog); this is the same shape, and `PASPurchases.logIn/logOut` already assumes a stable user id exists that something else produced.

**Proposed home.** New `PASKitAuth` module (`Sources/PASKitAuth/`) with `PASAuth.shared` mirroring `PASPurchases.shared` / `PASNotifications.shared`: `configure()`, observable `uid`/`isAnonymous`/`isLinked`, `signInAnonymouslyIfNeeded()`, `prepareAppleRequest(_:)` / `completeAppleSignIn(_:)`, `signInWithGoogle()`, `signOut()`, `deleteAccount() -> PASAccountDeletionResult`, plus `PASFreshInstallGuard`. It must be its own product, not part of `PASKitCore`: it pulls in the Firebase iOS SDK and GoogleSignIn-iOS, and an app that takes no accounts must not link them — the same rule that keeps RevenueCat out of `PASKitCore`.

**What the app injects.** The `GoogleService-Info.plist`, the URL scheme handling (`XueTangApp.swift:121` `GIDSignIn.sharedInstance.handle($0)`), all sign-in UI (`ViewComponents/Controls/XTSignInWithAppleButton.swift`, `XTGoogleSignInButton.swift`), and its own post-sign-in policy (`AppRouter.logOut(using:backend:)` at `Core/State/AppRouter.swift:85`).

**Second-app evidence.** None — and strongly so. WorkoutApp has zero Firebase/`ASAuthorization` hits and is fully local SwiftData; CoupleCalorieTracker has no accounts at all (its "partner" is a second local `PersonProfile` record, `Persistence/ProfileStore.swift:6-18`). One app needs this today.

**Effort.** L — new module, two new SDK dependencies, a `Package.swift` product, an integration-guide section, and a plist-absent test story.

**Recommendation.** **Extract when a second app needs accounts.** Ranked #5 on value despite that, because it is by far the most expensive and most dangerous code here to re-derive; when app 2 does need sign-in, this section is the extraction plan. In the meantime the app should keep it exactly where it is — moving it now would be speculative generalisation by PASKit's own rule.

---

### 6. Doc-level last-write-wins `SyncPolicy`

**What it is.** `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Services/Backend/BackendDTOs.swift:316` — `nonisolated enum SyncPolicy` with `direction(localUpdatedAt:remoteUpdatedAt:) -> .push/.pull/.inSync` (`:326`) and `clockAfterPull(remoteUpdatedAt:previousPushedAt:unpushedLocalRows:)` (`:351`). Its counterpart is `.../Core/Services/Backend/LocalSyncClock.swift:19` — a logical "last meaningful mutation" timestamp with `isDirty` (`:48`), deliberately untouched by launch housekeeping so a fresh reinstall reads as "pull the cloud", not "push empty over good remote data". Driven from `BackendCoordinator.swift:60` `reconcile()`.

**Why it is mechanism, not vocabulary.** `SyncPolicy` is two pure functions over `Date?` pairs and an `Int`; it names no store, no backend and no model. `LocalSyncClock` is a pair of `UserDefaults`-backed dates with an injectable suite (`:28`). The two rules they encode — stamp the remote doc with the *logical* clock so two devices converge instead of ping-ponging, and don't advance `lastPushedAt` while local-only rows remain unpushed — are exactly the subtle parts, and both are backend-agnostic (Firestore, CloudKit, a plain REST doc).

**Proposed home.** `Sources/PASKitCore/Sync/PASSyncPolicy.swift` + `PASSyncClock.swift`. `PASKitCore` and no new dependency: the whole point is that the transport stays app-side, the way `PASAppGroupContainer` deliberately ships no persistence dependency. Everything else in `Backend/` — the DTOs, `BackendCoordinator`'s merge, `purgeCardDocs`, `applyToLocal` — is XueTang's schema and stays.

**What the app injects.** Its Firestore client, its DTOs, its merge, and when to call `touch()`.

**Second-app evidence.** None. WorkoutApp's only "sync" is HealthKit (`Core/Services/WorkoutHealthSyncing.swift`, `MeasurementHealthSyncing.swift`) — a different shape with no LWW clock; CoupleCalorieTracker has `NSPersistentCloudKitContainer` with sync explicitly disabled (`Persistence/PersistenceController.swift:53`, `cloudKitContainerOptions = nil`).

**Effort.** S (~90 lines, already pure and tested in `XueTangTests/BackendTests.swift`).

**Recommendation.** **Extract when a second app syncs.** Note the plausible near-term trigger: CoupleCalorieTracker's disabled CloudKit is described in its own source as "slice 3", and a two-person shared tracker is the app most likely to need reconcile rules next.

---

### 7. Confetti burst

**What it is.** `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/ViewComponents/Decoration/ConfettiBurstView.swift:13` — a one-shot particle burst parameterised by `particleCount`, `duration`, `colors` and `onFinished`. Field generated once per mount from `SeededRandomGenerator` (`.../Core/Content/SeededRandomGenerator.swift:9`, SplitMix64), drawn in a `TimelineView(.animation)` + `Canvas` where each particle's position is an analytic function of elapsed time (`ConfettiParticle.state(at:duration:)`, `:108`) — no per-frame mutable state, no `Timer`. Ships `.allowsHitTesting(false)`, `.accessibilityHidden(true)` and a defence-in-depth reduce-motion self-check.

**Why it is mechanism, not vocabulary.** Colours are a parameter; only the *default* value references `xt` tokens, and dropping the default makes the file brand-free. The reusable content is the analytic-position-plus-`Canvas` technique and the reduce-motion/accessibility discipline, both of which a second implementation typically misses. Nothing about it knows what is being celebrated. The seeded RNG is a 14-line generic `RandomNumberGenerator` and would come along.

**Proposed home.** `Sources/PASKitLifecycle/Indicators/PASConfettiBurst.swift`, next to `PASProgressRing` — the folder already exists for exactly this class of brand-free primitive. `SeededRandomGenerator` → `Sources/PASKitCore/` as `PASSeededRandom`.

**What the app injects.** `colors:` (required, no default), counts, duration, and the decision to mount it at all.

**Second-app evidence.** None. WorkoutApp has milestones and achievement badges (`Core/Services/Milestones.swift:13`, `ViewComponents/AchievementBadge.swift`) but no particle celebration; CoupleCalorieTracker has none.

**Effort.** S.

**Recommendation.** **Extract when a second app celebrates.** It is one self-contained file with an obvious API, so the cost of waiting is near zero and the cost of guessing the API wrong is real.

---

### 8. CoreHaptics ramp/curve

**What it is.** `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Core/Services/HapticEngine.swift:25` — a shared instance owning the process-wide `CHHapticEngine` (`:66-67`). `Beat` (`:31`) names the moment rather than a hardware strength and carries `intensity`/`sharpness`/`fallbackStyle`; `play(_:)` (`:76`), `rise(duration:from:to:punctuated:)` (`:90`, a continuous event plus a `CHHapticParameterCurve` on `.hapticIntensityControl`), `flourish()` (`:124`), `stop()` (`:137`). Every entry point degrades gracefully when `CHHapticEngine.capabilitiesForHardware().supportsHaptics` is false — the ramp collapses to its punctuation rather than firing a misleading full-strength buzz.

**Why it is mechanism, not vocabulary.** `PASKitCore.Haptics` today is `UIFeedbackGenerator` presets and `PASHapticSequence` — discrete taps at offsets. A *curve* is the thing those generators cannot express, and the code here is the generic CoreHaptics plumbing (engine start/restart, player retention, hardware capability fallback) with a three-case intensity vocabulary sitting on top. The vocabulary is the app's; the plumbing and the fallback policy are not.

**Proposed home.** `Sources/PASKitCore/Haptics/` — extend the existing surface rather than add a type: `Haptics.play(PASHapticRamp(duration:from:to:punctuated:))`, with the CoreHaptics engine as an internal lazily-started singleton and the same `isEnabled:` gate the rest of `Haptics` takes.

**What the app injects.** Its `Beat` names and the moments they fire on; the haptics preference.

**Second-app evidence.** Partial. `/Users/moritztucher/Private/WorkoutApp/WorkoutApp/Core/Services/RestEndHaptics.swift:6` plays three heavy taps — already expressible as PASKit's existing `.triplePulse`, so it argues for *migration*, not for the ramp. No second app needs a curve today.

**Effort.** M — CoreHaptics engine lifecycle (stop/reset handlers, foreground restart) is fiddly, and it is untestable in the Simulator.

**Recommendation.** **Extract when a second app needs a curve.** Meanwhile WorkoutApp should move `RestEndHaptics` onto `Haptics.play(.triplePulse)` and XueTang should move `HapticManager` onto `Haptics.play(_:isEnabled:)`; that alone removes two of the three copies.

---

### 9. `PriceLoadState` for the paywall

**What it is.** `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/Features/Commerce/Models/PriceLoadState.swift:9` — `.loading` / `.loaded` / `.failed`, consumed by `.../Features/Commerce/ViewModel/PaywallViewModel.swift:32` and `:103` `loadOffering()`. The rule it encodes: the paywall shows an honest loading or failed state and no price at all, rather than a hardcoded USD placeholder, and `.failed` is retryable — the guard is on the state, not on whether a package is nil, so a retry after failure actually re-runs.

**Why it is mechanism, not vocabulary.** "Never show a fake price" is a store-facing correctness rule, not a XueTang rule, and the retry-guard bug it prevents is one every paywall hits. Everything else in `PaywallViewModel` is either app copy or already-shipped PASKit: the savings math at `:54` duplicates `StoreProduct.pasSavingsPercent(comparedToMonthly:)`, `yearlyHasTrial` at `:71` duplicates `.pasHasFreeTrial`, and `subscribe`/`restore` (`:121`, `:145`) duplicate `PASPaywallFlow`. The monthly-vs-annual two-plan selection is genuinely missing from `PASPaywallFlow`, but it is a two-line `Bool` at the call site and generalising it (three plans? a lifetime tier?) would produce a worse API than the local version.

**Proposed home.** `Sources/PASKitPurchases/` — add `PASPriceLoadState` and fold it into `PASPaywallFlow` as an observable `loadState` alongside `isPurchasing`, so `flow.loadOffering(firstOf:)` owns the retry guard.

**What the app injects.** Its offering identifiers, plan copy, and the selection binding.

**Second-app evidence.** None. WorkoutApp links `RevenueCat` and `RevenueCatUI` and calls `PASPurchases.shared.configure(...)` once at `App/WorkoutAppApp.swift:100` — and that is the only purchase line in the app; no paywall, no entitlement gate. CoupleCalorieTracker has no StoreKit at all.

**Effort.** S.

**Recommendation.** **Extract when a second app builds a paywall.** Independently and immediately: migrate `PaywallViewModel` onto `pasSavingsPercent` / `pasHasFreeTrial` / `PASPaywallFlow`, which are already shipping and already cover ~70% of that file.

---

### 10. Font cascade + glyph-coverage fallback

**What it is.** `/Users/moritztucher/Private/ChineseLanguageLearning/XueTangV2/XueTang/XueTang/ViewComponents/DesignSystem/Theme.swift:174` `XTFont.songTi(size:weight:)` — resolves a variable font's weight through its named instances, attaches a `.cascadeList` descriptor so a script the primary face lacks falls through to a subset face instead of tofu, and wraps the result in `UIFontMetrics(forTextStyle:).scaledFont(for:)` so a custom font still tracks Dynamic Type. And `:166` `brushScript(size:covering:)` — a `UIFont.canRender(_:)` coverage check that drops the *whole* run to a system fallback rather than rendering one missing glyph.

**Why it is mechanism, not vocabulary.** Nothing in either function names a font; the family strings are the app's. Three generic problems are solved: custom fonts silently ignoring Dynamic Type, variable-font weight resolution (`.custom(_:size:)` cannot ask for SemiBold), and per-run glyph coverage. `PASKitCore/Styling` already owns the adjacent pieces — `Font.pasScaled` does the metrics wrap for *system* fonts, `PASFontRegistration` registers bundled faces — so this is the missing third of a surface PASKit already has.

**Proposed home.** `Sources/PASKitCore/Styling/Font+PASScaled.swift` — extend with `Font.pasCustom(_ family: String, size:, relativeTo:, weight:, cascadingTo: [String] = [], covering: String? = nil)`.

**What the app injects.** Family names, the cascade order, and its own token layer (`XTFont` stays; it just calls through).

**Second-app evidence.** None — neither sibling bundles a font. XueTang's own `XueTangTests/FontRegistrationTests.swift` is the only coverage.

**Effort.** M — `CoreText` descriptor work and a real risk of an API that reads worse than the local one; the cascade list only matters for multi-script apps.

**Recommendation.** **Extract when a second app ships a script-specific font.** Single app, real generalisation risk.

---

### 11. `Color(hex:)`

**What it is.** Not in the app target — `/Users/moritztucher/Private/ChineseLanguageLearning/CLLDesign/Sources/CLLDesign/Extensions/Color+Hex.swift:10`, a 3/6/8-digit hex `Color` initializer.

**Why it is mechanism, not vocabulary.** It is a parser. `PASKitCore/Styling` already ships `Color(light:dark:)` for exactly the "build app tokens without an asset catalog" case, and every token layer that does that needs to type colours as hex.

**Proposed home.** `Sources/PASKitCore/Styling/Color+LightDark.swift` (same file, it is the companion initializer).

**What the app injects.** The hex strings.

**Second-app evidence.** `CLLDesign` is consumed by MandarinToneTrainer (`MandarinToneTrainer/.../Core/Theme/MTTTheme.swift` and 9 other files), so it already has two in-family consumers; a third studio app defining tokens would want it too.

**Effort.** XS.

**Recommendation.** **Extract now** — but only as a trailer on whatever commit touches `Styling` next; it does not justify its own release.

---

## The sibling local packages

Three local packages sit beside XueTangV2 in `/Users/moritztucher/Private/ChineseLanguageLearning/`. The four-package picture (PASKit + CLL*) is more coherent than it looks: **PASKit is the studio's service layer; `CLLDesign`/`FSRS`/`ToneTrainerKit` are one product family's design and domain layers.** That is the right axis to split on, and none of the three belongs inside PASKit.

**`CLLDesign`** (`CLLDesign/Package.swift`, 1,177 lines across 8 files) — hex colours, elevation shadows, text styles, `CLLColor`/`CLLConstants` tokens, `PrimaryButton`/`SecondaryButton`, `PressScaleButtonStyle`. **Rightly separate, and must stay separate**: PASKit deliberately owns no design layer (`CLAUDE-INTEGRATION.md` §6 — "every app keeps its own theme"), and a shared tokens package is the exact thing that rule excludes. Two caveats. First, it is *not used by XueTangV2 at all* — `grep -rn "import CLLDesign" XueTangV2` returns nothing; its only consumer is `MandarinToneTrainer`, so "CLL" overstates its reach and it is really MandarinToneTrainer's design package. Second, it is the place most likely to drift into PASKit's lane: `Styles/PressScaleButtonStyle.swift:4` already duplicates `.buttonStyle(.pasPressable())` including the reduce-motion guard, and its animation constants overlap `Animation.respectingReducedMotion`. The fix is not to move CLLDesign into PASKit but to have CLLDesign depend on PASKitCore for the brand-free mechanisms and keep only token *values*.

**`FSRS`** (`FSRS/Package.swift`, algorithm + schedulers + four test suites) — a port of the open-source FSRS spaced-repetition scheduler. **Rightly separate.** This is squarely the domain the brief names as off-limits: spaced-repetition scheduling is XueTang's pedagogy, one app consumes it, and PASKit's philosophy forbids carrying an algorithm no second app needs. It also has a genuine reason to be its own package rather than app source — it is a vendored upstream port with its own characterization tests, and keeping that boundary is what lets it be re-synced.

**`ToneTrainerKit`** (`ToneTrainerKit/Package.swift`, CoreML classifier + audio corpus + views + its own `ToneExerciseTheme`) — Mandarin tone classification. **Rightly separate**, for the same reason plus two more: it bundles a `.mlpackage` and an audio corpus (PASKit ships no resources), and it depends on `CLLDependencies` and `CLLDesign`, so absorbing it would drag a design layer into the service package. Worth flagging that it is a *feature* package, not a library — it ships `PracticeView`, `WordListView`, view models and a theme — which is fine for a two-app family but means it can never be shared outside it.

**The structural note.** The one real risk is not the count of packages but the absence of a stated rule for which layer a new capability goes to. The rule the evidence supports: *mechanism with no domain and no brand → PASKit; Chinese-learning domain → FSRS/ToneTrainerKit; Chinese-family brand → CLLDesign; everything else → the app.* Under that rule the current split is correct and nothing needs moving — but `PressScaleButtonStyle` is already on the wrong side of it, which is how these things start.

---

## Should stay local

**Settings-screen scaffolding.** `.../Features/System/View/ViewComponents/SettingsRow.swift:6`, `SettingsSection.swift:21`, `SettingsToggleRow.swift:6`, `SettingsMenuPickerRow.swift:12`. Tempting because they are clean, generic-looking row types and neither sibling has an equivalent. Rejected: every one of them is soaked in `Color.xtAccentPrimary`, `XTFont.body`, `.xtCard(radius:)` and `XTHairlineDivider`, and stripping those leaves a `Form`/`Section` with extra steps. PASKit owns no design layer by policy; a generalised `PASSettingsRow` would either ship a look (violating that) or be a worse `List` (pointless). Note also that WorkoutApp's `Features/Settings/Views/SettingsView.swift:4` is a plain `Form` and is fine — which is evidence the abstraction is not needed, not that it is missing.

**`SpeechClipLibrary`.** `.../Core/Services/SpeechClipLibrary.swift:24`. The most tempting rejection in the audit: it is a genuinely generic mechanism — thousands of small assets concatenated into a few memory-mapped packs with a byte-range JSON index, bounds-checked slicing (`:106`), and graceful absence (`clip(for:slot:)` returns nil and the caller falls back). But the index format is co-designed with `content-pipeline/generate.py`, so extracting the reader without the writer ships half a contract; and exactly one app has a six-thousand-clip corpus. Revisit only if a second app hits the "loose files flatten into the bundle root and slow every build" problem this solves.

**Streak/XP/league/chest gamification.** `.../Core/Gamification/ChestRules.swift:1`, `Core/State/XPBoost.swift`, `Core/State/DailyGoal.swift`, `ViewComponents/Celebration/*`, `Features/League/`. Vocabulary in disguise — chest tiers, XP multipliers, league ladders and freeze economics are product design, not mechanism. The one genuinely generic layer underneath (day rollover, freeze consume/grant) is already `PASStreakEngine`; see candidate #1.

**Readiness.** `.../Features/Readiness/Models/ReadinessBand.swift:9`, `ReadinessDimension.swift:9`, `ReadinessProjection.swift:8`. Named in the brief, but it is HSK 3.0 / GF0025-2021 all the way down — five official dimensions, three official bands, official cumulative targets. `ReadinessProjection` (coverage + trailing-28-day pace → a date, with `.insufficientData` and `.beyondHorizon` as honest refusals) is the only arguably generic piece, and generalising "when will I be ready" without a band, a denominator and a pace definition produces an API with three closures and no meaning.

**Content pipeline and build scripts.** `content-pipeline/generate.py`, `scripts/build_content_bundle.py`, `build_content_glosses.py`, `build_artwork.py`, `gen_vocab_tips.py`, `docs/content/course-mined/*.py`. Python, and PASKit is a Swift package with no tooling product. Worth noting for contrast: WorkoutApp does the equivalent verification as XCTest suites instead (`WorkoutAppTests/ExerciseDatabaseIntegrityTests.swift:11`, `ExerciseMuscleAttributionTests.swift:210` — bundle sweeps via `Bundle.main.urls(forResourcesWithExtension:)`), which is the more portable pattern; if anything graduates from this area it is that test *shape*, not these scripts.

**Localization tooling.** There is none to extract — the repo has no `.xcstrings` audit/translate/verify scripts (`find` for `*.py`/`*.sh` over the repo returns only content-pipeline files). The brief's "localization tooling" is entirely the Swift-side override, which is candidate #4. CoupleCalorieTracker's `Scripts/sync-strings.sh` is the only string-catalog script in the studio and is a 13-line `xcstringstool sync` wrapper.

**`VocabImportParser`.** `.../Core/Utilities/VocabImportParser.swift:40`. 621 lines of excellent, pure, testable code — that classifies columns by whether cells contain Han characters and tone-marked pinyin. Chinese-specific by construction.

**`DisplayName`.** `.../Core/Utilities/DisplayName.swift:29`. Exists solely because one brush font has no accented Latin (`Theme.swift:166`); its own doc comment says to delete it if the avatar ever gets a fallback face. Not a mechanism — a workaround for one asset.

**`APIKeys` / `AppInfo` support constants.** `.../Core/Configuration/APIKeys.swift:7` and `AppInfo.swift:22-25`. A near-twin exists (`WorkoutApp/WorkoutApp/Core/Services/AppKeys.swift`, same two keys, same placeholder shape) — but the content is literally per-app literals. The convention is worth writing down in `CLAUDE-INTEGRATION.md`; the code is not worth sharing. Separately, the app's local `AppInfo` (`AppInfo.swift:9`) *shadows* `PASKitCore.AppInfo` inside this module and should be renamed or removed.

**Test helpers.** `ModelConfiguration(isStoredInMemoryOnly: true)` appears in 18 test files (`XueTangTests/AppStateTests.swift:9`, `ProgressStoreTests.swift:15`, …). Tempting as a `PASKitTesting` module; rejected because the "helper" is one line of first-party SwiftData API and the schema is the app's. The one shape with real duplication cost is WorkoutApp's temp-directory on-disk migration container (`WorkoutAppTests/WeeklyRecapMigrationTests.swift:13-27`, duplicated at `DataStoreWeeklyRecapTests.swift:89-97`, with manual `.store`/`.wal`/`.shm` cleanup) — and `PASAppGroupContainer.migrateStore(from:to:sidecarExtensions:)` already covers the sidecar half of it.

**Dev-menu contents, `MemoryRing`/`DailyGoalRing`, `ArtworkCatalog`, `PinyinAligner`, `ToneColoredCharacters`, `ChineseNumber`, `ConfusionSets`.** Dev-menu *sections* are vocabulary by PASKit's own documented design (the shell is `pasDevelopmentOverlay`, which this app should adopt). The two rings are `PASProgressRing` with app tokens — `DailyGoalRing.swift:6` even documents why it is deliberately not shared with `MemoryRing`, which is the same argument against sharing either upward. The rest is curriculum.
