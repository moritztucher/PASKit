# CoupleCalorieTracker — what could be replaced by PASKit

Date: 2026-09-04 · PASKit audited: **v0.3.1** (`Package.swift`, `develop`) · App: `CoupleCalorieTracker`, branch `main`, `b50fd6a`

Read-only audit. No app or package source was modified.

---

## Summary

The app is already the studio's best PASKit citizen: the release-notes stack (`WhatsNewGate` / `WhatsNewView` / `ChangelogView` / `ReleaseNote`) migrated cleanly yesterday, `ContentUnavailableView` is used for empty states rather than a hand-rolled one, and there is **no** local reimplementation of rating, feedback, mail, version check, keychain, reachability, haptics, notifications, analytics, purchases, sharing, streaks, or App Group storage — those categories are clean, mostly because the app doesn't need them yet. What remains is a small set of *mechanisms* the app hand-rolled inside `Views/DesignSystem.swift` and `ViewModels/OnboardingViewModel.swift` that PASKitCore/PASKitLifecycle already own — and two of them (fixed-point hero numerals, unguarded Reduce Motion) are live accessibility defects, not cosmetic duplication. The four PASKitCore findings share one prerequisite: adding the `PASKitCore` product to the target. **That pulls no vendor SDK** — PASKitCore's only external dependency is `KeychainAccess`, and it is already resolved and linked transitively today because `PASKitLifecycle` depends on `PASKitCore`. `Package.resolved` does not change. RevenueCat and PostHog stay out of the graph. The single biggest deletion, the onboarding step engine, needs no new product at all — it lives in the already-linked `PASKitLifecycle`.

Against that, three things say "leave it": `RingGauge`'s neon glow has no expression in `PASProgressRing`, `OpenFoodFactsClient`'s typed `throws(OFFError)` + negative caching is richer than `URLSessionNetworkService` + `PASError`, and the four persisted `UserDefaults` keys are shipped installed-user state that a `PASSettingsStore` migration would gain nothing by touching.

**Persisted keys in scope across this audit** — none of the recommendations below change any of them:
`profile.localPersonID`, `profile.partnerPersonID` (`Persistence/ProfileStore.swift:5-6`), `onboarding.householdIntent` (`:7`), `whatsNew.lastSeenBuild` (`App/RootView.swift:10`).

| # | Finding | PASKit equivalent | Fit | Effort | Recommendation |
|---|---------|-------------------|-----|--------|----------------|
| 1 | Onboarding step engine + back/advance + progress header | `PASOnboardingFlow`, `pasOnboardingTransition` (PASKitLifecycle — already linked) | Close | M | Adopt now |
| 2 | `heroNumeralStyle(size:)` — fixed-point hero numerals, no Dynamic Type | `Font.pasScaled` (PASKitCore) | Close | S | Adopt now |
| 3 | 10 `.animation(...)` sites ignore Reduce Motion, incl. two `repeatForever` | `View.pasAnimation` / `Animation.respectingReducedMotion` (PASKitCore) | Exact | S | Adopt now |
| 4 | `#if DEBUG debugCard` inside the Profile tab | `pasDevelopmentOverlay` + `PASDevelopmentMenu` (PASKitLifecycle) | Close | S | Adopt now |
| 5 | `NeonPressedButtonStyle` | `.buttonStyle(.pasPressable(pressedScale:))` (PASKitCore) | Close | S | Adopt now |
| 6 | `print(...)` as the only logging in the app | `PASLogger.make(category:)` (PASKitCore) | Exact | S | Adopt now |
| 7 | `.background(.ultraThinMaterial, in: Capsule())` ×2 on the scanner | `View.pasGlass(in: .capsule)` (PASKitLifecycle) | Partial | S | Leave — fallback is thicker over a live camera |
| 8 | Hand-rolled Monday-first week start in `weeklyAdherence` | `Date.pasStartOfWeek()` (PASKitCore) | Partial | S | Leave until the app wants locale-aware weeks |
| 9 | `OpenFoodFactsClient` URLSession/status/decode plumbing | `URLSessionNetworkService` + `PASError` (PASKitCore) | Partial | M | Leave — app's error domain is richer |
| 10 | `DefaultsKey` + raw `UserDefaults` in `CoreDataProfileStore` | `PASSettingsStore` + `@PASDefault` (PASKitCore) | Partial | M | Leave — identity pointers, not preferences |

---

## Findings

### 1. Onboarding step engine is a hand-rolled `PASOnboardingFlow`

**App code**
- `ViewModels/OnboardingViewModel.swift:11-13` — `enum Step: Int, CaseIterable { case welcome, basics, job, theme, summary, household }`
- `ViewModels/OnboardingViewModel.swift:17` — `private(set) var step: Step = .welcome`
- `ViewModels/OnboardingViewModel.swift:61-78` — `advance()`, a six-case switch that walks the enum forward
- `ViewModels/OnboardingViewModel.swift:80-83` — `goBack()`, `Step(rawValue: step.rawValue - 1)`
- `Views/Onboarding/OnboardingFlow.swift:32-33` — `stepIndex` / `totalSteps` derived from `Step.rawValue` and `allCases.count`
- `Views/Onboarding/OnboardingFlow.swift:35-63` — `progressHeader` + `progressDot(for:)`, six dots and a "Step N of 6" caption
- `Views/Onboarding/OnboardingFlow.swift:18-28` — a manual back chevron in the toolbar, hidden on `.welcome`

**PASKit equivalent** — `PASOnboardingFlow<Step>` (`Sources/PASKitLifecycle/Onboarding/PASOnboardingFlow.swift`), plus `View.pasOnboardingTransition(step:direction:)` and `PASOnboardingDirection`. **No new product**: `PASKitLifecycle` is already the app's only linked product, and this is in it. No vendor SDK, no `Package.resolved` change.

`PASOnboardingFlow` supplies `current`, `count`, `index`, `isFirst`, `isLast`, `progress` (`(index+1)/count`), bounded `advance()`/`back()`, `go(to:)`, and `direction` — every line above except the step vocabulary and the dot rendering.

**Fit** — Close. Three differences, all real:
1. `advance()` in the app carries per-step validation (`:66 guard isBasicsValid`, `:69 guard jobArchetype != nil`). `PASOnboardingFlow.advance()` is unconditional, so those guards move to the call sites — i.e. `PrimaryCTAButton(isEnabled: viewModel.isBasicsValid)` in `OnboardingBasicsStep`/`OnboardingJobStep`. That is arguably better UX (a disabled CTA beats a dead one) but it *is* a change in what a tap does today.
2. `PASOnboardingProgressBar` is a capsule bar; the app draws six dots with a filled/ringed current state (`OnboardingFlow.swift:51-63`). Keep the dots — drive them off `flow.index`/`flow.count` and do not adopt the bar. See "Looks like a match but isn't".
3. `pasOnboardingTransition` would *add* a direction-aware slide the app doesn't have today. That is a visible new animation on every step change. Opt in deliberately, and pair with finding #3 so it respects Reduce Motion.

**Risk** — No persisted keys: the step index is in-memory only (`@State private var viewModel = OnboardingViewModel()` at `OnboardingFlow.swift:5`), and onboarding completion is inferred from `store.loadLocalProfile() != nil` (`RootView.swift:81`), not from a defaults flag. No localized surface is touched: step titles stay in `OnboardingFlow.title(for:)` (`:83-92`, already `String(localized:)`) and PASKit renders nothing here. No design cost — PASKit owns no chrome in this path; `PrimaryCTAButton`, `DS.background`, the dots and the nav bar all stay app-owned. `PASOnboardingFlow` requires a non-empty step list (`precondition` at `PASOnboardingFlow.swift:60`), satisfied by `Step.allCases`.

**Effort** — M. Delete `advance()`/`goBack()`/`step`, hold a `PASOnboardingFlow(steps: Step.allCases)`, rewrite the six `viewModel.advance()` call sites to `flow.advance()` (or keep a thin `viewModel.advance()` that validates then calls `flow.advance()`), swap `stepIndex`/`totalSteps` for `flow.index`/`flow.count`, and gate the toolbar chevron on `!flow.isFirst` instead of `step != .welcome`.

**Recommendation** — **Adopt now.** It is the one finding here that deletes real state-machine code rather than a helper, it needs no product change, and it puts the app on the same engine as the other studio apps. Worth pairing with `PASDraft` (PASKitCore) for resume-after-kill, which the flow has no answer for today — a killed onboarding currently loses everything.

---

### 2. `heroNumeralStyle` freezes the app's largest text at a fixed point size

**App code**
- `Views/DesignSystem.swift:40-44` — `func heroNumeralStyle(size: CGFloat) -> some View { font(.system(size: size, weight: .heavy)).fontWidth(.compressed).monospacedDigit() }`
- Call sites: `Views/DayScreen.swift:184` (calorie ring, 64pt), `:244` (fasting timer, 64pt); `Views/MealDetailView.swift:118` (56pt); `Views/MealTemplateEditorView.swift:287` (44pt), `:160` (22pt); `Views/LogEntryView.swift:154` (40pt); `Views/MealPortionSheet.swift:112` (40pt); `Views/MealsScreen.swift:211` (28pt)

`Font.system(size:)` does not track Dynamic Type. The eight biggest, most information-dense numbers in the app — today's calories, the fasting clock, the portion amount — are pinned at their design size for every user, at every text-size setting.

**PASKit equivalent** — `Font.pasScaled(_:relativeTo:weight:design:)` (`Sources/PASKitCore/Styling/Font+PASScaled.swift`), a `UIFontMetrics`-scaled system font at a custom point size. **Needs the `PASKitCore` product added** to the target: one `XCSwiftPackageProductDependency` alongside the existing `PASKitLifecycle` entry in `CoupleCalorieTracker.xcodeproj/project.pbxproj:380-383`. **No vendor SDK** — PASKitCore's only external dependency is `KeychainAccess` (`Package.swift:56-60`), already in the resolved graph via `PASKitLifecycle → PASKitCore`. RevenueCat/PostHog are untouched.

**Fit** — Close. The fix is a one-line body change inside `heroNumeralStyle`; all eight call sites stay byte-identical:
```swift
func heroNumeralStyle(size: CGFloat) -> some View {
    font(.pasScaled(size, relativeTo: .largeTitle, weight: .heavy))
        .fontWidth(.compressed)
        .monospacedDigit()
}
```
`.fontWidth`/`.monospacedDigit` are view modifiers, not part of the `Font`, so they compose unchanged. Point sizes are identical at the default (Large) setting — nothing moves for a user who never changed text size.

**Risk** — No persisted keys. No localized strings (these render numerals). Design: this is where the trade sits — at AX sizes a 64pt compressed numeral grows, and `DayScreen`'s 240pt ring (`:174`, `:238`) has fixed geometry, so a very large accessibility size could push the label against the ring. Pick `relativeTo:` per call site (`.largeTitle` for the 64pt heroes, `.title2` for the 22pt one) and check the two 64pt sites at AX3. The alternative — leaving it — is a permanent Dynamic Type failure on the app's primary screen.

**Effort** — S (one function body + the product line; then a visual pass at two AX sizes).

**Recommendation** — **Adopt now.** Highest value-per-line in this audit: one edit, one product line, and the app's headline numbers start honoring the system text size.

---

### 3. Ten animation sites ignore Reduce Motion — including two `repeatForever`

**App code**
- `Views/ScanScreen.swift:305` — `.animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)`
- `Views/ScanScreen.swift:306` — `.animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isSweeping)`
- `Views/DesignSystem.swift:112` (`MacroBar`), `:170` (`RingGauge`), `:234` (`NeonPressedButtonStyle`) — `.animation(DS.spring, value:)`
- `Views/DayScreen.swift:209`, `:336`, `:508`; `Views/MealDetailView.swift:138`; `Views/MealsScreen.swift:282` — `.animation(DS.spring, value:)`
- `Views/DesignSystem.swift:5` — `static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)`

Nothing in the app reads `@Environment(\.accessibilityReduceMotion)` (grep: zero hits). The two `repeatForever` animations on the scanner are the ones that matter — a perpetually pulsing, sweeping overlay is exactly the class of motion Reduce Motion exists to stop, and it runs for as long as the scanner is open.

**PASKit equivalent** — `View.pasAnimation(_:reducedMotion:value:)` and `Animation.respectingReducedMotion(_:)` (`Sources/PASKitCore/Styling/Animation+ReducedMotion.swift`). Same product prerequisite as #2 (`PASKitCore`, no vendor SDK). `pasAnimation` reads the environment itself, so the swap is mechanical: `.animation(DS.spring, value: x)` → `.pasAnimation(DS.spring, value: x)`.

**Fit** — Exact. `pasAnimation` is `animation(_:value:)` with a Reduce-Motion branch; the default substitute is `nil` (changes snap). The `DS.spring` token stays in the app, which is exactly PASKit's "mechanism here, vocabulary there" split.

**Risk** — No persisted keys, no strings. User-visible behaviour changes **only for users who have Reduce Motion on** — for them, ring/bar fills snap instead of springing and the scanner overlay stops pulsing. That is the intended fix, not a regression. For the two scanner animations, `pasAnimation` with the default `nil` substitute stops the loop entirely, which is the correct outcome. Design: zero cost — `DS.spring` is unchanged and the neon look is untouched.

**Effort** — S. Ten call sites, mechanical.

**Recommendation** — **Adopt now**, bundled with #2 since they share the product line. Do the two `ScanScreen` `repeatForever` sites first; they are the actual defect.

---

### 4. The DEBUG affordances live in a card inside the shipping Profile screen

**App code**
- `Views/ProfileScreen.swift:99-101` — `#if DEBUG debugCard #endif` inside the Profile `LazyVStack`
- `Views/ProfileScreen.swift:545-568` — `debugCard`: "Reset onboarding (DEBUG)", "Seed sample day (DEBUG)", "Delete all entries (DEBUG)"
- Backed by `ViewModels/ProfileViewModel.swift:134-202` — `resetOnboarding()`, `seedSampleDay()`, `deleteAllEntries()`, all already `#if DEBUG`
- Related: `Views/ScanScreen.swift:10-12, 56-62, 137-139` — a second, separate DEBUG affordance (manual barcode entry sheet) reached from the scanner

**PASKit equivalent** — `View.pasDevelopmentOverlay(alignment:menu:)` + `PASDevelopmentMenu` (`Sources/PASKitLifecycle/Development/`). **Already-linked product**, no vendor SDK. The overlay compiles to `self` in release (`View+PASDevelopmentOverlay.swift:33-37`); the menu is a `NavigationStack` + `Form` + Done whose sections stay app vocabulary.

**Fit** — Close. The three buttons become one `Section("Persisted state")` in a `PASDevelopmentMenu`, hung off `RootView`'s `content` so both the Profile card *and* the scanner's manual-entry entry point collapse into one DEV capsule. `ProfileScreen` loses `debugCard` and its `#if DEBUG` block; the `ProfileViewModel` methods stay exactly as they are.

**Risk** — No persisted keys. No shipped behaviour change at all: both the current card and the PASKit overlay are DEBUG-only, so TestFlight and App Store builds are byte-equivalent either way. Localization: `PASDevelopmentMenu`'s internal "Development" title and "Done" button are hardcoded English (`PASDevelopmentMenu.swift:30, 46`) and are *not* in `Localizable.xcstrings` — irrelevant here precisely because it is DEBUG-only, but it is the reason this pattern must not be reused for shipping UI. Design: the floating DEV capsule is `.tint`-filled, so it picks up `DS.volt` from `RootView.swift:18` — it will look like the app.

**Effort** — S.

**Recommendation** — **Adopt now.** It removes a DEBUG conditional from a 573-line shipping view, consolidates two scattered dev entry points into one, and costs nothing.

---

### 5. `NeonPressedButtonStyle` is `.pasPressable` with a different spring

**App code** — `Views/DesignSystem.swift:230-236`
```swift
private struct NeonPressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DS.spring, value: configuration.isPressed)
    }
}
```
Used once, at `Views/DesignSystem.swift:222` inside `PrimaryCTAButton`.

**PASKit equivalent** — `PASPressableButtonStyle` / `.buttonStyle(.pasPressable(pressedScale:haptic:isHapticEnabled:))` (`Sources/PASKitCore/Styling/PASPressableButtonStyle.swift`). Same `PASKitCore` product prerequisite as #2/#3; no vendor SDK.

**Fit** — Close, not exact. PASKit's default `pressedScale` is `0.96` (pass `0.97` to preserve the app's feel) and its spring is `.spring(response: 0.2, dampingFraction: 0.6)`, hardcoded — noticeably snappier than `DS.spring` (`0.4`/`0.8`) and not overridable. So `.buttonStyle(.pasPressable(pressedScale: 0.97))` deletes a type but changes the press feel of the app's one primary CTA.

**Risk** — No persisted keys, no strings. User-visible: the CTA press-in becomes faster and less damped. Design: minor but real — this is the app's single most-tapped control, and the app deliberately routes *everything* through one `DS.spring` token. Bonus if adopted: `.pasPressable(haptic: .light)` would give the CTA press feedback the app currently has none of (no haptics anywhere in the codebase).

**Effort** — S.

**Recommendation** — **Adopt now**, alongside #3 — but only if the faster spring is acceptable on a side-by-side. If the `DS.spring` timing is load-bearing to the neon feel, this is the one finding to skip: it saves 7 lines and costs a deliberate motion decision. Alternatively, **adopt once PASKit adds an `animation:` parameter to `PASPressableButtonStyle`** — a small, obviously-correct addition that would make this exact.

---

### 6. The app's only logging is a `print`

**App code** — `Persistence/PersistenceController.swift:29-37`
```swift
container.loadPersistentStores { _, error in
    if let error {
#if DEBUG
        fatalError("Failed to load Core Data store: \(error)")
#else
        print("Failed to load Core Data store: \(error)")
#endif
    }
}
```
That `print` is the entire logging story of the app (grep: no `os.Logger`, no `import OSLog`, no other `print`). In release, a store that fails to load writes one line to stdout that nobody will ever read — a silent, unfielded crash-class failure.

**PASKit equivalent** — `PASLogger.make(category:)` (`Sources/PASKitCore/Logging/PASLogger.swift`), an `os.Logger` scoped to `AppInfo.bundleIdentifier`. Same `PASKitCore` product prerequisite; no vendor SDK.

**Fit** — Exact. `private let log = PASLogger.make(category: "persistence")` then `log.error("Core Data store failed to load: \(error.localizedDescription, privacy: .public)")`. Surfaces in Console.app and in sysdiagnose from a real user's device.

**Risk** — None. No persisted keys, no strings, no design surface. Note the privacy modifier: `error.localizedDescription` is a `String` and therefore `.private` by default — mark it `.public` explicitly (as above) or the release log is `<redacted>`.

**Effort** — S.

**Recommendation** — **Adopt now**, bundled with #2/#3/#5. Also consider `AppInfo` in the same pass: the app never reads `Bundle.main` at all today (grep: zero hits), so there is nothing to delete, but a logged `AppInfo.versionWithBuild` at launch would make that Console line actionable.

---

### 7. Two `.ultraThinMaterial` capsules on the scanner overlay

**App code**
- `Views/ScanScreen.swift:127-130` — `ProgressView("Loading product…").padding().background(.ultraThinMaterial, in: Capsule())`
- `Views/ScanScreen.swift:314-319` — `Text("Hold the barcode inside the frame")…background(.ultraThinMaterial, in: Capsule())`

**PASKit equivalent** — `View.pasGlass(_:in:)` (`Sources/PASKitLifecycle/LiquidGlass/View+PasGlass.swift:21`), already-linked product, no vendor SDK. On iOS 26 it uses Apple's `glassEffect`; below 26 it falls back to `.regularMaterial` plus an optional tint.

**Fit** — Partial. Signature-wise it is a drop-in (`.pasGlass(in: .capsule)`), and on iOS 26 these two chips would get real Liquid Glass over the live camera feed, which is where the effect actually earns its keep. But the pre-26 fallback is `.regularMaterial`, which is **thicker** than the `.ultraThinMaterial` the app chose — over a camera preview that is a visible change in how much of the frame shows through, on every device below iOS 26.

**Risk** — No persisted keys. Localization: `"Loading product…"` and `"Hold the barcode inside the frame"` stay app-owned strings; PASKit adds none. Design: the fallback-thickness change is the whole risk, and it lands on the scanner — the screen where seeing through the chrome matters most.

**Effort** — S.

**Recommendation** — **Leave**, or **adopt once PASKit's `pasGlass` fallback material is caller-selectable**. The iOS 26 upside is real, but a thicker scrim over a camera viewfinder on every pre-26 device is a worse trade than the two lines it saves. Nothing else in the app uses `Material` (grep: these two sites only), so there is no wider pattern to unify.

---

### 8. Hand-rolled Monday-first week start in the "This week" card

**App code** — `ViewModels/ProfileViewModel.swift:111-132`
```swift
let weekday = calendar.component(.weekday, from: today)   // 1 = Sunday…7 = Saturday
let daysSinceMonday = (weekday + 5) % 7
guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else { … }
```
Paired with `Views/ProfileScreen.swift:418-422`, which rotates `Calendar.current.shortWeekdaySymbols` from Sunday-first to Monday-first by hand.

**PASKit equivalent** — `Date.pasStartOfWeek(calendar:)` and `Date.pasIsSameWeek(as:)` (`Sources/PASKitCore/Time/Date+PASCalendar.swift`). Same `PASKitCore` prerequisite; no vendor SDK.

**Fit** — Partial, and the gap is behavioural, not cosmetic. `pasStartOfWeek()` **honors the calendar's `firstWeekday`**; the app deliberately hard-codes Monday, in both the data (`ProfileViewModel:119`) and the labels (`ProfileScreen:421`). Swapping only the data side would put a Sunday-first locale's bars under Monday-first labels — a silent off-by-one on a chart. Swapping both sides is a locale-aware-weeks product decision, not a refactor.

**Risk** — No persisted keys. User-visible: in any Sunday-first locale (US, JP, CA…) the "This week" card would start on a different day and the seven adherence percentages would shift. The app currently ships English-only with German planned (`.claude/memory.md`), both Monday-first — so today the change is invisible, and it becomes visible exactly when the app expands.

**Effort** — S mechanically, M including the locale decision and its verification.

**Recommendation** — **Leave for now.** Revisit as "adopt once the app decides it wants locale-aware weeks" — at which point adopt `pasStartOfWeek()` **and** drop the manual label rotation in the same change, never one without the other.

---

### 9. `OpenFoodFactsClient`'s URLSession plumbing overlaps `URLSessionNetworkService`

**App code** — `Networking/OpenFoodFactsClient.swift:26-76`, specifically:
- `:38-46` — `session.data(for:)` wrapped in a `URLError` → `OFFError.network(code)` catch
- `:48-59` — status switch: `404 → .notFound`, `429 → .rateLimited`, `200..<300 → ok`, else `.server(statusCode:)`
- `:61-66` — `JSONDecoder().decode` → `OFFError.decoding`
- `Networking/OFFError.swift:3-23` — the typed error domain and its `userMessage`

**PASKit equivalent** — `NetworkService` / `URLSessionNetworkService` + `PASError` (`Sources/PASKitCore/Networking/`, `Sources/PASKitCore/Errors/`). `URLSessionNetworkService.validatedData` (`:36-60`) covers 2xx validation, 429 with `Retry-After` parsing, decode-failure mapping, offline mapping and `CancellationError`. `PASKitCore` product prerequisite; **no vendor SDK** (KeychainAccess already in the graph).

**Fit** — Partial, and the app's version is the richer one on three axes that matter here:
1. **Typed throws.** `product(forBarcode:) async throws(OFFError)` (`:26`) and the exhaustive `switch` in `ScanViewModel.lookUp` (`:102-108`) depend on the concrete error type. `NetworkService.send` is untyped `throws`, so adopting it means catching, re-mapping to `OFFError` at the boundary, and reintroducing a default branch — the mapping code does not disappear, it moves.
2. **404 is a domain outcome, not a failure.** `:50-52` caches `.notFound` per barcode so a re-scan of an unknown product is instant and offline-safe. `PASError` has no `notFound`; it would arrive as `.requestFailed(statusCode: 404, body:)` and need unwrapping back into a domain case.
3. **Localization.** `OFFError.userMessage` (`OFFError.swift:10-23`) is five `String(localized:)` messages that live in `Localizable.xcstrings`. `PASError.errorDescription` (`PASError.swift:23-45`) is hardcoded English and ships no catalog — surfacing it would put untranslatable English into the German build the app is planning.

Net saving if adopted: roughly 20 lines of status/decode switch, against a new error-domain hop and the loss of typed throws.

**Risk** — No persisted keys. Localization risk is the material one (point 3): any `PASError` string that reaches the user is un-localizable. The per-barcode negative cache (`:19`, `:27-33`, `:51`, `:69`) is behaviour the app relies on to stay inside Open Food Facts' 15 req/min/IP budget (`.claude/memory.md`) — it must survive any refactor.

**Effort** — M.

**Recommendation** — **Leave.** Revisit only if the app grows a second endpoint (search, or the ShelfBase fallback named in project memory), at which point `NetworkService` becomes worth it as the shared transport seam with `OFFError` mapping kept at the client boundary. One PASKit piece *is* worth taking today regardless: `URLRequest.cURL(pretty:)` (`Sources/PASKitCore/Networking/URLRequest+cURL.swift`) logged next to a failed lookup would make the staging-vs-production auth setup (`:94-97`) debuggable from a Console line.

---

### 10. `DefaultsKey` + raw `UserDefaults` in `CoreDataProfileStore`

**App code**
- `Persistence/ProfileStore.swift:4-8` — `enum DefaultsKey { localPersonID, partnerPersonID, householdIntent }`
- `Persistence/ProfileStore.swift:23-28` — injected `UserDefaults`, defaulting to `.standard`
- Read/write sites: `:31`, `:53`, `:57`, `:63-64`, `:69`, `:91`, `:95`, `:101`
- `ViewModels/OnboardingViewModel.swift:123` — `UserDefaults.standard.set(intent.rawValue, forKey: DefaultsKey.householdIntent)`
- `Persistence/PersistenceController.swift:49-80` — preview seeding writes the same two keys into a `"preview"` suite

**PASKit equivalent** — `PASSettingsStore` + `@PASDefault` + `UserDefaultsStorable` (`Sources/PASKitCore/Settings/`). `PASKitCore` prerequisite; no vendor SDK. It would collapse the key enum and the eight get/set sites into three declarations, and the suite injection (`PASSettingsStore(defaults:)`) maps exactly onto the existing preview pattern.

**Fit** — Partial, for a reason of kind rather than mechanism. These are not user preferences — they are **identity pointers** (which `CDPerson` row is "me", which is "the partner") plus one deferred-feature marker, all read inside a persistence repository. `PASSettingsStore` is `@Observable`; making the profile store observable would put SwiftUI invalidation on a type that deliberately has none, and `CoreDataProfileStore` currently exposes no observation at all. `HouseholdIntent` is a `String`-raw enum so it conforms to `UserDefaultsStorable` with an empty extension; the two UUID pointers would be `@PASDefault("profile.localPersonID") var localPersonID: String?`, matching today's `nil`-when-absent semantics exactly.

**Risk** — **The persisted keys are the whole risk, and they are shipped installed-user state.** `profile.localPersonID` and `profile.partnerPersonID` are the only link between the app and its Core Data rows: get either key wrong during adoption and every existing install loses its profile and its partner, permanently, with the entries orphaned. `onboarding.householdIntent` is lower stakes but is the record of a deferred decision the app promises to honour later (`OnboardingHouseholdStep.swift:29`). `@PASDefault` takes the key as its argument, so the keys *can* be preserved verbatim — but the migration has no upside proportional to that downside. No localized surface, no design surface.

**Effort** — M (small diff, disproportionate verification burden — a fresh-install *and* an upgrade-over-existing-install pass).

**Recommendation** — **Leave.** Adopt `PASSettingsStore` when the app grows an actual settings surface (units, haptics, reminder time) — that is what it is for. Do not migrate identity pointers into it just to delete a key enum.

---

## Looks like a match but isn't

**`RingGauge` → `PASProgressRing`.** `Views/DesignSystem.swift:147-185` vs `Sources/PASKitLifecycle/Indicators/PASProgressRing.swift`. Structurally near-identical — same `-90°` start, same `.round` cap, same spring on change, same optional center label. Rejected on one line: `RingGauge` applies `.neonGlow(color, enabled: glow)` **to the progress stroke only** (`:166`), which is the app's signature look on its three biggest surfaces (`DayScreen.swift:174` calorie ring, `:238` fasting ring, `MealDetailView.swift:145`). `PASProgressRing` has no glow slot, and applying `.neonGlow` from outside would shadow the track and the center label too. Secondary: `PASProgressRing` fills from `.tint` only, while `RingGauge` takes an explicit `color` that varies per person (`DS.personColor(isPartner:)`) and per status — workable via `.tint(color)`, but it stacks on top of the glow problem. **Adopt once `PASProgressRing` exposes a stroke-modifier or shadow slot**; until then this is exactly the "PASKit ships no design layer" boundary working as intended.

**Onboarding progress dots → `PASOnboardingProgressBar`.** `Views/Onboarding/OnboardingFlow.swift:51-63` draws six dots, the current one ringed. PASKit ships a capsule bar. Different affordance, not a different implementation of the same one — and the dots are distinctly the app's. Keep the dots; take only the engine (finding #1). Also worth knowing before any adoption: `PASOnboardingProgressBar` hardcodes `.accessibilityLabel("Progress")` in English (`:44`), outside the app's string catalog.

**`recentlyLoggedID` confirmation → `.pasToast`.** `ViewModels/MealsViewModel.swift:222-228` sets an id, sleeps 1.2s, clears it; `Views/MealsScreen.swift:51` + `:273-284` swap a `plus` glyph for a `checkmark` on that row's button. This looks like the hand-rolled-toast pattern `pasToast` exists to replace, but it isn't a toast — it is an inline, per-row icon state with no overlay, no placement and no message. It also already dodges the stale-timer bug PASKit warns about, via the `self.recentlyLoggedID == id` guard on wake (`:226`). Nothing to delete.

**`FastingSchedule.clockLabel` / `.compactLabel` → `PASDurationFormat`.** `Domain/PersonProfile.swift:112-121` vs `Sources/PASKitCore/Time/PASDurationFormat.swift`. Same intent, incompatible shapes. `clockLabel(12h 42m)` → `"12:42"` (hours:minutes); `PASDurationFormat.clock` for the same interval → `"12:42:00"` (h:mm:ss). `compactLabel` → `"3H 18M"`; `PASDurationFormat.compact` → `"3h 18m"`. Adopting either would change the fasting timer's face on `DayScreen.swift:244` and `:249` — a 64pt hero numeral gaining a `:00` seconds field it never had. Rejected. If the studio wants one duration vocabulary, that is a PASKit change (an `hoursMinutes` shape), not an app change.

**`DayViewModel` calendar one-liners → `Date.pas…`.** `ViewModels/DayViewModel.swift:39` (`isDateInToday`), `:110`/`:116`/`:156`/`:187` (`date(byAdding: .day…)`), `:126` (`startOfDay`). These map to `pasIsSameDay`, `pasAdding(days:)` and `pasStartOfDay`, but Foundation already gives them cleanly — PASKit's actual value in `Date+PASCalendar` is `pasDaysSince` (both ends startOfDay-normalized, killing the cross-midnight off-by-one), and the app never computes a day *span*. Cosmetic; not worth a diff.

**`Color(hex:)` → `Color(light:dark:)`.** `Views/DesignSystem.swift:28-36` is a hex initializer; PASKit ships an appearance-resolving initializer. Different problems. And the app is hard-locked to dark (`RootView.swift:17` `.preferredColorScheme(.dark)`), so `Color(light:dark:)` has nothing to resolve. PASKit ships no hex initializer — nothing to delete, and nothing PASKit should add for one app.

**`currentDisplayVersion` → `AppInfo.version`.** `Views/ProfileScreen.swift:539-541` reads `ReleaseNotes.all.first?.displayVersion` — PASKit's own `ReleaseNote.displayVersion` (`ReleaseNote.swift:43`) — for the version shown on the "What's New" row. Not a duplication of `AppInfo`: for a row that opens the changelog, labelling it with the newest *documented* release is arguably more correct than the bundle version. Worth a note rather than a change, though — ship a build without adding a `ReleaseNote` and this row silently shows the previous version. If that becomes a real risk, `AppInfo.versionWithBuild` produces the same `"1.0 (1)"` shape from the bundle.

**Scanner loading overlay → `.loading(isPresented:)`.** `Views/ScanScreen.swift:124-130` overlays a `ProgressView` capsule on the live scanner. PASKit's `.loading` dims the backdrop and **blocks underlying interaction** (`View+Loading.swift:15-28`) — wrong for a screen where the camera stays live and two alerts (`:88`, `:97`) must remain reachable. The bare `ProgressView`s at `App/RootView.swift:59` and `Views/ProfileScreen.swift:22, 51` are full-screen *placeholders* for an unresolved state, not overlays on existing content — also not what `.loading` is. Rejected on all four.

**`CameraAccess` and `HealthProfileReader`.** `Scanner/CameraAccess.swift` (AVFoundation authorization + torch) and `Health/HealthProfileReader.swift` (HealthKit one-shot read) have no PASKit counterpart, and shouldn't — PASKit ships neither an AVFoundation nor a HealthKit surface, and per the build philosophy neither earns a place until a second app needs it. Both are clean.

**`PersistenceController` → `PASAppGroupContainer`.** `Persistence/PersistenceController.swift` points `NSPersistentCloudKitContainer` at the default store location. `PASAppGroupContainer` is for sharing a store with a widget or extension; this app has neither target today. Not a duplicate — a capability the app hasn't needed yet.

**Categories that are genuinely clean — nothing found.** Rate prompt, feedback form / mail composer, version & update check, app-info footer, toasts, Liquid Glass beyond finding #7, streak engine, App Group storage, keychain / credentials, reachability, haptics, analytics, purchases, notifications, sharing / export: the app contains **no** local implementation, near-duplicate or thin wrapper for any of them. Grep confirms zero hits for `requestReview`/`SKStoreReview`, `MFMailCompose`, `UNUserNotification`, `NWPathMonitor`, `Keychain`, `UIImpactFeedbackGenerator`/`sensoryFeedback`, `ImageRenderer`/`UIActivityViewController`/`ShareLink`, and `Bundle.main`/`UIDevice`. There is nothing to delete in those categories — only capabilities the app has not yet reached for.

**Release notes — already migrated, nothing left behind.** `Domain/ReleaseNotes.swift` is data only, `App/RootView.swift:85-97` follows the `WhatsNewGate` contract exactly (including `seed` before onboarding completes and `markPresented` on the empty-cards path), and `Views/ProfileScreen.swift:511-520` uses `ChangelogView` with the `entryContainer` slot. The gate key is correctly pinned to the already-shipped `"whatsNew.lastSeenBuild"` (`RootView.swift:10`). No local `WhatsNew`/`Changelog`/`ReleaseNote` types survive anywhere in the app (grep: the only files mentioning them are those three plus docs). Clean.
