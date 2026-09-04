# PASKit — Integration guide for consuming apps

When an app adds PASKit as a dependency, it should add this line to its own `CLAUDE.md` so Claude sessions in that app know what PASKit provides and follow its conventions:

```
@<relative-path-to-PASKit>/CLAUDE-INTEGRATION.md
```

For a sibling repo: `@../PASKit/CLAUDE-INTEGRATION.md`. The rest of this file then sets the rules for any session working inside the consuming app.

---

## Modules

| Module | Provides |
|--------|----------|
| `PASKitCore` | App + device metadata (`AppInfo`, `DeviceInfo`); networking (`NetworkService`, `URLSessionNetworkService`); shared error domain (`PASError` + `PASError.localizer`); reachability (`Reachability` protocol + `@MainActor @Observable NWReachability`); credentials (`CredentialVault` protocol + `KeychainCredentialVault`); logging (`PASLogger` → `os.Logger`); haptics (`Haptics.play`, `View.hapticOnTap`); settings (`PASSettingsStore` + `@PASDefault` + `UserDefaultsStorable`); draft persistence (`PASDraft`); styling mechanisms (`Animation.respectingReducedMotion`, `View.pasAnimation`, `Color(light:dark:)`, `Font.pasScaled`, `PASFontRegistration`); calendar math + durations (`Date.pas…` helpers, `PASDurationFormat`); streak engine (`PASStreakState` + `PASStreakEngine` + `PASStreakConfig`); App Group storage (`PASAppGroupContainer` — store-engine-agnostic, no persistence dependency); pressable button style (`.buttonStyle(.pasPressable())`). |
| `PASKitLifecycle` | App-lifecycle UI: `View.presentAppRating(...)` + `PASAppRatingKeys` / `PASAppRatingCopy`, `View.presentAppFeedback(...)` + `PASAppFeedbackKeys` / `PASAppFeedbackCopy` + `FeedbackSheet`, `View.loading(...)` + `DefaultLoadingView`, `View.pasGlass(...)` + `View.pasGlassButtonStyle(...)` (iOS 26 with pre-26 fallback), `VersionCheckManager` + `AppUpdateView`, `WhatsNewView` + `WhatsNewGate` + `WhatsNewHighlights` (build-number-gated post-update sheet), `ChangelogView` (`ReleaseNote` / `ChangelogItem`), `MailComposerView` (iOS), `AppInfoFooter` (iOS), onboarding engine (`PASOnboardingFlow` + `View.pasOnboardingTransition`), dev-menu scaffold (`View.pasDevelopmentOverlay` + `PASDevelopmentMenu`), toasts (`View.pasToast` + `PASToast`), progress ring + bar (`PASProgressRing`, `PASProgressBar`). |
| `PASKitPurchases` | RevenueCat facade: `PASPurchases.shared.configure(...)` / `.customerInfo` (observable, stream-fed) / `.isEntitled` / `.offerings` / `.currentOffering` / `.offering(identifier:)` / `.products` / `.purchase(package/product)` → `PASPurchaseResult` / `.restorePurchases` / `.logIn` / `.logOut`. App owns entitlement + product IDs and the paywall UI. |
| `PASKitAnalytics` | PostHog facade: `PASAnalytics.shared.setup(...)` / `.capture` / `.screen` / `.identify` / `.register` / `.reset` / `.optIn` / `.optOut` / `.flush` / `.isFeatureEnabled` / `.featureFlagPayload`. App owns event vocabulary as an extension on `PASAnalytics`. |
| `PASKitNotifications` | Local-notification facade: `PASNotifications.shared.configure(...)` / `.authorizationStatus` + `.isAuthorized` (observable) / `.onResponse` (tap routing, cold-start buffered) / `.requestAuthorization` / `.schedule(PASNotificationRequest)` (triggers incl. `.dailyAt` sugar; `sound: PASNotificationSound`) / `.fireTest` / `.cancel(ids:)` / `.cancelAll` / `.pendingIDs` / `.setBadgeCount`. App owns scheduling policy, copy, identifiers, and navigation. |
| `PASKitSharing` | Share-card export: `PASShareCard.render` (SwiftUI→`UIImage`), `PASInstagramStories.share`/`.copySticker`, `PASPhotoLibrary.save`, `PASShareItems` + `PASActivitySheet` (sheet + imperative `present`), `PASScaledCardPreview` + `PASTransparencyCheckerboard`. App owns card designs, captions, fallback policy. |
| `PASKit` (umbrella) | Re-exports every module — one dependency line, `import` modules individually. |

## Conventions

**1. Logging — `PASLogger.make`, not raw `os.Logger`.**
```swift
import PASKitCore
private let log = PASLogger.make(category: "purchases")
log.info("user \(id, privacy: .public) signed in")
```
Subsystem resolves to `AppInfo.bundleIdentifier`. No `bootstrap()` step. `os.Logger`'s privacy modifier — `String`/custom types default to `.private` (redacted in release); opt into `.public` only for non-sensitive values. Logs surface in Console.app and the Logging instrument in Instruments.

**2. App / device metadata — `AppInfo` / `DeviceInfo`, not raw `Bundle.main` / `UIDevice`.**
```swift
AppInfo.version             // "1.2"
AppInfo.build               // "45"
AppInfo.versionWithBuild    // "1.2 (45)"
AppInfo.displayName         // CFBundleDisplayName → CFBundleName
AppInfo.bundleIdentifier
DeviceInfo.modelIdentifier  // "iPhone16,1" — all platforms
DeviceInfo.systemName / .systemVersion / .model  // iOS-only (UIKit-gated)
```

**3. Reachability — `NWReachability`.**
```swift
@State private var reachability = NWReachability()
// .onAppear { reachability.start() } / .onDisappear { reachability.stop() }
// observe reachability.status: .unknown / .online / .offline
```

**4. Credentials — `KeychainCredentialVault`, not raw `KeychainAccess`.**
```swift
let vault = KeychainCredentialVault()  // baseService defaults to AppInfo.bundleIdentifier
try vault.set("token", source: "posthog", key: "apiKey")
let token = try vault.get(source: "posthog", key: "apiKey")
```

**4a. Haptics — `Haptics.play`, not raw `UIImpactFeedbackGenerator`.**
Primitives only — apps decide what they mean. Pass an app-level preference for the gate.
```swift
import PASKitCore
Haptics.play(.success, isEnabled: settings.hapticsEnabled)
Haptics.play(.selection)
// SwiftUI sugar — fires the haptic on tap, then runs the action:
Text("Mark Done").hapticOnTap(.success) { markDone() }
// Multi-step patterns — presets or custom sequences, not Task.sleep chains:
Haptics.play(.celebration, isEnabled: settings.hapticsEnabled)  // also .milestone / .levelUp / .triplePulse
Haptics.play(PASHapticSequence([.init(.soft, delay: 0), .init(.success, delay: 0.2)]))
```
iOS-only at the hardware level; macOS compiles to a no-op.

**4b. User preferences — `PASSettingsStore` + `@PASDefault`, not hand-rolled UserDefaults plumbing.**
Subclass once, one line per setting. The declared value is the default; keys are the app's vocabulary. No `@Observable`, no key enum, no `didSet` write-through, no `access`/`withMutation` boilerplate:
```swift
import PASKitCore

@MainActor
final class SettingsStore: PASSettingsStore {
    @PASDefault("settings.hapticsEnabled") var hapticsEnabled = true
    @PASDefault("settings.weightUnit")     var weightUnit: WeightUnit =
        Locale.current.measurementSystem == .metric ? .kg : .lb   // locale-aware default
    @PASDefault("settings.customRest")     var customRest: Int?   // nil = key absent, no 0-sentinels
}
extension WeightUnit: UserDefaultsStorable {}  // any RawRepresentable enum — empty extension
```
Inject via `.environment(settings)`; views read properties and observe automatically (granularity is per-store, which is fine at settings scale — split stores if a hot value churns). App Group sharing and tests inject a suite: `SettingsStore(defaults: UserDefaults(suiteName: "group.…")!)`. Storable out of the box: `Bool`, `Int`, `Double`, `String`, `Date`, `Data`, `URL`, optionals of those, raw-representable enums. Reset one setting with `removeValue(forKey:)`. Declare optional settings with a `nil` default — writing `nil` removes the key.

**4c. Calendar math & durations — `Date.pas…` / `PASDurationFormat`, not hand-rolled.**
```swift
import PASKitCore
date.pasIsSameDay(as: lastOpen)              // day gating
today.pasDaysSince(challengeStart)           // whole days, startOfDay-normalized both ends
date.pasStartOfWeek()                        // honors the calendar's firstWeekday
Date.now.pasHoursUntilMidnight()             // streak-deadline copy
PASDurationFormat.compact(seconds: 252)      // "4m 12s" — stats labels
PASDurationFormat.clock(seconds: 3852)       // "1:04:12" — timers
```
All take `calendar:` (default `.current`) — inject a fixed calendar in tests. For date *strings* use `formatted(.dateTime…)` / `RelativeDateTimeFormatter` — PASKit deliberately doesn't wrap those.

**4d. Streaks — `PASStreakEngine`, not hand-rolled rollover math.**
Pure value-in/value-out; the app persists `PASStreakState` (it's Codable) wherever it already stores things. **Run `rolledOver` at launch AND on every `scenePhase == .active`** — iOS keeps apps resident for days:
```swift
import PASKitCore
let config = PASStreakConfig(freezeCap: 2, freeFreezeInterval: 30 * 24 * 3600)  // omit → freezes off

let (rolled, outcome) = PASStreakEngine.rolledOver(state, config: config)
if outcome.freezeConsumed { showStreakSavedNotice() }
if outcome.streakDidReset { /* optional empathy copy */ }
if outcome.gapDays >= 7, outcome.streakLost > 0 { showWelcomeBack(lost: outcome.streakLost) }

let (next, firstToday) = PASStreakEngine.recordingActivity(rolled, config: config)
if firstToday { Haptics.play(.celebration); checkMilestones(next.streak) }  // milestones stay app vocabulary

// Weekly counters reset on week change — granularity compare, never week-start equality:
if !(weekStart?.pasIsSameWeek(as: .now) ?? false) { weekStart = Date.now.pasStartOfWeek(); weeklyXP = 0 }
```

**4e. App Group store sharing — `PASAppGroupContainer`, not hand-rolled container/migration code.**
Store-engine agnostic — same helper for Realm, SQLite, SwiftData, or a JSON cache. PASKit ships **no persistence dependency**; the store's config/schema/migration stays in your app:
```swift
import PASKitCore
let container = try PASAppGroupContainer(identifier: "group.studio.pocketapps.app")
let storeURL = container.url(for: "app.store")
try container.migrateStore(                              // one-time, idempotent — safe every launch
    from: existingDefaultStoreURL, to: storeURL,
    sidecarExtensions: ["sqlite-wal", "sqlite-shm"]      // Realm: ["realm.lock","realm.note","realm.management"]
)
// then point your own Configuration / ModelContainer at storeURL
```
The app and its widget/extension must use the **same** App Group identifier — a mismatch silently breaks sharing.

**5. Lifecycle UI — use what `PASKitLifecycle` ships before writing your own.**

Rate prompt:
```swift
import PASKitLifecycle
SomeView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 }
)
```
Migrating an app that already shipped its own rate-prompt keys and copy — pass what it shipped with, or every installed user who resolved the prompt sees it again:
```swift
SomeView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 },
    keys: PASAppRatingKeys(isCompleted: "isRatingInteractionComplete", isInitialPromptShown: "isInitialPromptComplete"),
    copy: PASAppRatingCopy(
        initialTitle: "Enjoying \(AppInfo.displayName)?",
        initialMessage: "Would you like to rate \(AppInfo.displayName) on the App Store?",
        initialAccept: "Yes, Rate It!",
        askLater: "Ask Later",
        neverAsk: "Never Ask Again",
        followUpTitle: "Enjoying \(AppInfo.displayName)?",
        followUpMessage: "A quick rating helps us a lot.",
        followUpAccept: "Rate Now",
        followUpDecline: "No Thanks"
    )
)
```
`presentAppFeedback` takes the same `keys:` / `copy:` pair (`PASAppFeedbackKeys` / `PASAppFeedbackCopy`), for the same reason.

Update check:
```swift
let result = await VersionCheckManager().checkIfAppUpdateAvailable()
// present .sheet(item: $result) { AppUpdateView(update: $0) }
// AppUpdateView(update:, forceUpdate: false) — dismissible nudge by default
```

Release notes — author each release **once**, as a `[ReleaseNote]` newest build first. It drives both the post-update sheet and the Settings changelog. Do not write your own release-note model:
```swift
enum ReleaseNotes {
    static let all: [ReleaseNote] = [
        ReleaseNote(
            build: 45, version: "1.2.0", date: "2026-09-02",   // ISO; nil hides the date
            changes: [                                          // + added / > changed / ~ fixed / * note
                "+ Live Activities on the home screen",
                "~ Fixed a crash on launch under iOS 18.0",
            ],
            highlights: [                                       // [] = don't interrupt for this build
                WhatsNewCard(symbol: "bolt.fill", title: "Live Activities", subtitle: "From the lock screen."),
            ]
        ),
    ]
}
```
`build` is the identity and the cadence key — unique and strictly increasing. SF Symbol names for `symbol`, not asset names.

What's-new (one-shot post-update sheet, gated on the build number). `WhatsNewGate` owns the whole cadence — skipped-build catch-up, downgrades, fresh installs. Never reimplement it:
```swift
@State private var highlights: WhatsNewHighlights?
private let gate = WhatsNewGate()   // already shipped a sheet? pass lastSeenBuildKey: your existing key

.task {
    let build = WhatsNewGate.currentBuild
    guard hasCompletedOnboarding else { gate.seed(currentBuild: build); return }
    guard let build, let cards = gate.highlightsForLaunch(currentBuild: build, notes: ReleaseNotes.all)
    else { return }
    gate.markPresented(build: build)   // mark even when cards is empty — state must converge
    guard !cards.isEmpty else { return }
    highlights = WhatsNewHighlights(cards: cards)
}
.sheet(item: $highlights) { highlights in
    WhatsNewView(cards: highlights.cards, headerSymbol: "sparkles") { self.highlights = nil }
}
```
Return contract: `nil` = present nothing, mark nothing. `[]` = mark presented, show nothing. Non-empty = mark presented, show the sheet.

The same sheet also serves a manual "What's New" row in Settings — pass `isDismissible: true` there (default is `false`, so the one-shot post-update sheet must be acknowledged via the CTA) and pair it with `.presentationDragIndicator(.visible)`:
```swift
.sheet(isPresented: $showWhatsNew) {
    WhatsNewView(cards: ReleaseHighlights.current, isDismissible: true) { showWhatsNew = false }
        .presentationDragIndicator(.visible)
}
```

Changelog (multi-release Settings screen — distinct from the one-shot `WhatsNewView`, same notes):
```swift
NavigationLink("What's New") {
    ChangelogView(notes: ReleaseNotes.all)
}
```

Branding both views — PASKit owns layout, spacing and animation; the app supplies chrome through chainable slots. Wrap `config.content`, never rebuild it:
```swift
WhatsNewView(cards: highlights.cards) { self.highlights = nil }
    .header { _ in Image(systemName: "dumbbell.fill").foregroundStyle(.brandGradient) }
    .cardContainer { config in BrandCard { config.content } }
    .continueButton { config in BrandButton(config.title, action: config.action) }
    .background { BrandBackground() }

ChangelogView(notes: ReleaseNotes.all)
    .entryContainer { config in BrandCard { config.content } }
```
Accent colour otherwise comes from `.tint`. Strings are rendered verbatim — PASKit ships no string catalog, so pass already-localized text. The same rule covers error copy: `PASError.errorDescription` is English developer text until the app installs `PASError.localizer` at launch; do it in every localized app.
```swift
// App launch — once, before the first network call:
PASError.localizer = { error in
    switch error {
    case .networkUnreachable:
        String(localized: "No internet connection.", bundle: XTLocalization.bundle)
    case .rateLimited:
        String(localized: "Too many requests. Please try again shortly.", bundle: XTLocalization.bundle)
    case .requestFailed, .decodingFailed, .unexpected:
        String(localized: "Something went wrong. Please try again.", bundle: XTLocalization.bundle)
    case .cancelled, .missingCredentials, .invalidCredentials:
        nil   // fall back to developerDescription
    }
}
```

Feedback prompt — two-stage prompt that opens `FeedbackSheet` on accept. PASKit owns the form, the app owns the transport (the `onSubmit` closure):
```swift
SomeView().presentAppFeedback(
    initialCondition: { await sessions.count >= 5 },
    askLaterCondition: { await sessions.count >= 12 }
) {
    FeedbackSheet { payload in
        try await sendFeedback(payload)  // email, HTTP, webhook — app's choice
    }
}
```

Or present `FeedbackSheet` directly from a Settings row (no prompt gating):
```swift
@State private var showFeedback = false
// Button("Send Feedback") { showFeedback = true }
//   .sheet(isPresented: $showFeedback) {
//       FeedbackSheet(
//           heroSymbol: nil,                    // hide the symbol (default "lifepreserver")
//           initialName: user.name,             // prefill known identity
//           initialEmail: user.email,
//           showsCloseButton: true              // ⓧ top-trailing; drops Cancel on compact
//       ) { payload in try await sendFeedback(payload) }
//   }
```
Apps with a locked design language can skip `FeedbackSheet` and build their own form over `FeedbackPayload`, sharing only the transport.

Mail composer is still available for the simple "open a prefilled mail draft" use case (iOS-only):
```swift
if MailComposerView.canSendMail {
    .sheet { MailComposerView(recipients: ["support@..."]) }
}
```

Settings footer (iOS): `AppInfoFooter()` — renders app icon (via `CFBundleIcons`) + name + version.

Toasts — lifecycle (placement, transition, auto-dismiss with correct re-arm) from PASKit; content is `PASToast` or any app view:
```swift
.pasToast(isPresented: $showUndo, duration: 5) {
    PASToast(message: "Habit completed", actionTitle: "Undo") { undo() }
}
// Content changes per trigger? Use item: — a new item restarts the timer:
.pasToast(item: $confirmation, duration: 2) { PASToast(symbol: "checkmark.circle.fill", symbolTint: .green, message: $0.text) }
```
`duration: nil` = sticky. Default placement `.bottom`; pass `alignment: .top` for banners.

Dev menu — DEBUG-only floating "DEV" capsule + menu container; release builds compile to a no-op. Menu sections are the app's vocabulary (state toggles, demo seeds, resets, mock-screen links). Gate DEBUG-only menu types *inside* the closure so call sites build in release:
```swift
ContentView().pasDevelopmentOverlay {
    #if DEBUG
    PASDevelopmentMenu {
        Section("Runtime state") { Toggle("Premium", isOn: $state.isPremium) }
        Section("Persisted state") { Button("Reset", role: .destructive) { state.resetAll() } }
    }
    #endif
}
```

Onboarding — PASKit owns the step engine and transition choreography; the app owns step vocabulary, step views, and navigation chrome (buttons/bars are brand):
```swift
enum Step: String, Codable, Hashable { case welcome, units, permissions }

// Static flow — or pass a closure for conditional steps that appear/disappear
// as earlier answers change: PASOnboardingFlow { model.visibleSteps }
@State private var flow = PASOnboardingFlow(steps: Step.allCases)

VStack(spacing: 0) {
    PASProgressBar(progress: flow.progress)                    // brand via .tint
    stepContent(for: flow.current)                             // app's @ViewBuilder switch
        .pasOnboardingTransition(step: flow.current, direction: flow.direction)
    bottomBar                                                  // app's buttons → flow.advance() / flow.back()
}
```
Resume-after-kill with `PASDraft` (PASKitCore): save a Codable snapshot of answers + `flow.current` on change and on `scenePhase != .active`; at launch hydrate answers **first** (so conditional steps compute), then `flow.go(to: restoredStep)`; `clear()` on completion. `progress` is `(index+1)/count`. `advance()`/`back()` are bounded no-ops at the ends — gate the buttons with `flow.isFirst`/`flow.isLast`.

Loading overlay — system-default spinner over a dimmed backdrop:
```swift
SomeView().loading(isPresented: $isLoading, message: "Signing in…")
```

Or supply a branded loading view (custom animation, determinate progress, app-icon ring):
```swift
SomeView().loading(isPresented: $isLoading) {
    MyBrandedLoadingView(progress: progress)
}
```

Liquid Glass — surfaces only (cards, sheet content, custom backgrounds). iOS 26+ uses Apple's `glassEffect`; pre-26 falls back to `.regularMaterial` (+ optional tint overlay):
```swift
Card(...).pasGlass(in: .rect(cornerRadius: 16))
Card(...).pasGlass(.regular.tint(.orange), in: .rect(cornerRadius: 16))      // tint the glass
Card(...).pasGlass(.regular.foreground(.white), in: .capsule)                // tint the text
Card(...).pasGlass(.regular.tint(.orange).foreground(.white), in: .capsule)  // both
```

For glass buttons (iOS 26+ uses `.buttonStyle(.glass)`; pre-26 falls back to `.borderedProminent` / `.bordered`):
```swift
Button("Continue") { ... }.pasGlassButtonStyle()         // .regular
Button("Dismiss") { ... }.pasGlassButtonStyle(.clear)    // clear variant
```

Do not apply `pasGlass` to nav bars or toolbars — they adopt Liquid Glass automatically on iOS 26 and the existing `.toolbarBackground(_:for:)` / `.toolbarForegroundStyle(_:for:)` are cross-version.

**6. Styling — SwiftUI defaults + the standard environment.** PASKit views use `.tint`, system fonts, `.primary` / `.secondary`. Apps style at the call site (`.tint(.brand)`, `.font(...)`). PASKit owns no design layer — every app keeps its own theme (token values, spacing/radius/motion enums, semantic color names). The brand-free *mechanisms* under those tokens do live in PASKitCore — use them instead of re-rolling:
```swift
import PASKitCore

// Reduce Motion — pure (caller reads the environment) or self-contained:
withAnimation(.easeOut(duration: 0.25).respectingReducedMotion(reduceMotion)) { … }
CardView().pasAnimation(.spring, value: isExpanded)   // reducedMotion: substitute optional

// Light/dark color without an asset catalog — build app tokens on top:
static let cardBackground = Color(light: .white, dark: Color(red: 0.11, green: 0.11, blue: 0.12))

// System font at a custom size that tracks Dynamic Type:
Text("Streak").font(.pasScaled(28, relativeTo: .title, weight: .heavy))

// At launch, when Xcode's generated Info.plist drops UIAppFonts:
PASFontRegistration.registerBundledFonts(named: ["BrushScript.ttf"])
```
And from PASKitLifecycle's glass shims: `CoverImage().pasConcentricClip(fallbackRadius: 12)` — iOS 26 `ConcentricRectangle` with pre-26 `RoundedRectangle` fallback.

Three brand-free UI primitives (colors come from `.tint`; the rest is mechanism — the full styled buttons/cards stay per-app, and prefer Apple's `ContentUnavailableView` for empty states):
```swift
import PASKitLifecycle
PASProgressRing(progress: 0.75, lineWidth: 6) { Text("3/4").font(.caption.bold()) }.tint(.brand)
PASProgressBar(progress: 0.4).tint(.brand)

import PASKitCore
Button("Start") { … }.buttonStyle(.pasPressable())                                  // scale + spring (snaps under Reduce Motion)
Button("Log") { … }.buttonStyle(.pasPressable(haptic: .selection,                   // + press haptic
                                              isHapticEnabled: settings.hapticsEnabled))
```

**7. Don't reinvent what PASKit owns.** Before writing a local utility for networking, keychain, reachability, version/build reads, app-icon loading at runtime, rate prompt, what's-new, update check, settings footer, a UserDefaults-backed settings store, or local notifications (permission, scheduling, tap routing) — check PASKit. If something belongs in PASKit but isn't there yet, extend PASKit rather than ship a parallel local copy.

**8. Never redeclare a PASKit public name — run the collision check.** Swift resolves an unqualified name against the current module before an imported one, so a local `AppInfo` or `extension View { func presentAppRating(...) }` in a file that imports PASKit silently wins over PASKit's own — the call site looks identical either way. This has happened three times across three apps. Before pushing:
```sh
python3 ../PASKit/Scripts/check-collisions.py <app-root> [<app-root> …]
```
CI runs the same check on every push via the `ios-ci` reusable workflow (`paskit-collisions.yml`). A deliberate exception — a local type/extension member that must coexist with PASKit's for now — goes in `.paskit-collisions-allow` at the repo root, one entry per line:
```
<type|extension> <Symbol> [@ <path>]  -- <justification>
```
`type AppInfo -- <why>` suppresses a whole-type collision; `extension View.presentAppRating -- <why>` suppresses one extension member. The optional `@ <path>` scopes the entry to one file (a second colliding declaration elsewhere still fails). **An entry with no justification after `--` fails the run with exit 2** — see `Scripts/README.md` in PASKit for the full CLI, exit codes, and output formats.

## Purchases — `PASPurchases`, not raw `Purchases`

Configure once at launch, then gate on the observable `customerInfo` and run purchase flows through the facade. RevenueCat types pass through unwrapped — this is a convenience wrapper, not a vendor abstraction:
```swift
import PASKitPurchases

// At launch (public SDK key, never a secret key):
PASPurchases.shared.configure(.init(apiKey: AppKeys.revenueCat))

// App-side entitlement vocabulary — typed, never stringly at call sites:
enum Entitlement: String { case premium }

// Gate features — observable, updates live across renewals/refunds/devices:
if PASPurchases.shared.isEntitled(Entitlement.premium) { … }

// Custom paywall flow — pricing math + state machine, not hand-rolled:
let offering = try await PASPurchases.shared.offering(firstOf: ["campaign", "default"])  // falls back to current
let savings = offering?.annual?.storeProduct
    .pasSavingsPercent(comparedToMonthly: offering?.monthly?.storeProduct)   // Int? — honest, live-price-based
let showTrial = offering?.annual?.pasHasFreeTrial == true                    // CTA: "Start free trial"

@State private var flow = PASPaywallFlow()   // isPurchasing / errorMessage / $flow.isShowingError
// Button: if await flow.purchase(selectedPackage, entitlement: Entitlement.premium) { dismiss() }
// Restore: if await flow.restore(entitlement: Entitlement.premium) { dismiss() }
// User-cancel → false with no error; nil package → "unreachable" message; copy overridable at init.

// Raw flow still available when the state machine doesn't fit:
let result = try await PASPurchases.shared.purchase(package)
guard !result.userCancelled else { return }

// Consumables by product ID (coin packs etc.) — app credits its own wallet:
let products = try await PASPurchases.shared.products(["app.coins.200"])
try await PASPurchases.shared.purchase(products[0])
```
Rules: never cache an `isPro` boolean — derive from `customerInfo`. Always offer an explicit "Restore Purchases" control (`restorePurchases()`). Never run raw StoreKit listeners (`Transaction.updates`) alongside — RevenueCat owns StoreKit. RevenueCat's server-side Virtual Currencies need a backend to debit; backend-less apps keep the wallet client-side and sell consumables. Hosted paywall (`RevenueCatUI`) is not in the module yet — added when the first app wants it.

## Analytics — `PASAnalytics`, not raw `PostHogSDK`

Configure once at launch, then capture from anywhere. PASKit owns the mechanism; the app owns the event vocabulary as a thin extension:
```swift
import PASKitAnalytics

// At launch:
PASAnalytics.shared.setup(.init(apiKey: AppKeys.posthog))

// From anywhere:
PASAnalytics.shared.capture("paywall_viewed")
PASAnalytics.shared.screen("Home")
PASAnalytics.shared.identify(userId: user.id, traits: ["plan": "pro"])
PASAnalytics.shared.register(["app_theme": "dark"])
PASAnalytics.shared.reset()                          // logout

// App-side vocabulary lives as an extension — never inside PASKit:
extension PASAnalytics {
    func captureOnboardingCompleted() { capture("onboarding_completed") }
}
```
Session replay is a config flag (`sessionReplay: true`), default off, iOS-only. Use the same user ID for `identify` as you pass to `PASKitPurchases.logIn` so analytics and revenue join.

## Notifications — `PASNotifications`, not raw `UNUserNotificationCenter`

Configure once at launch (installs the one notification-center delegate), register the tap router where navigation lives, then schedule/cancel with stable app-vocabulary identifiers. PASKit owns the mechanism; the app owns scheduling policy, copy, and where a tap navigates:
```swift
import PASKitNotifications

// At launch — before a cold-start tap can arrive:
PASNotifications.shared.configure()   // PASNotificationsConfig(foregroundPresentation:) to customize

// Where navigation lives — cold-start taps are buffered until this runs:
PASNotifications.shared.onResponse { response in
    router.handle(destination: response.userInfo["destination"])
}

// Permission at an earned moment (post-first-delight), never at first launch:
let granted = try await PASNotifications.shared.requestAuthorization()

// Observable gating — drive permission UI from authorizationStatus / isAuthorized:
if PASNotifications.shared.isAuthorized { … }

// Schedule idempotently — re-using an id replaces the pending request:
try await PASNotifications.shared.schedule(PASNotificationRequest(
    id: "streak-protection",
    title: "Your streak ends at midnight",
    body: "4 hours left — one quick lesson keeps it alive.",
    sound: .named("rest_complete.wav"),  // bundled clip; default is the system sound
    userInfo: ["destination": "path"],
    trigger: .calendar(DateComponents(hour: 20), repeats: false)
))

// Daily reminder at a user-picked time — pass the Date, .dailyAt extracts hour/minute:
try await PASNotifications.shared.schedule(PASNotificationRequest(
    id: "daily-reminder", title: "Time to practice", body: "Keep your streak alive.",
    trigger: .dailyAt(settings.reminderTime)        // or .dailyAt(hour: 19, minute: 30)
))
// Reschedule on settings change = schedule again (same id). Cancel = cancel(ids:).

// Cancel when the condition clears (e.g. the user opened the app today):
PASNotifications.shared.cancel(ids: ["streak-protection"])

// DEBUG dev-menu "test notifications" button — preview content now, under a test.* id:
try await PASNotifications.shared.fireTest(dailyReminderRequest)
```
Rules: never cache a permission boolean — observe `authorizationStatus` (auto-refreshed on iOS foreground return). Use stable, app-vocabulary notification ids (`"streak-protection"`), not UUIDs — replace-on-reschedule + `cancel(ids:)` depend on them. `userInfo` is `[String: String]` routing keys only, not state. Triggers: `.interval(_:repeats:)`, `.calendar(DateComponents, repeats:)`, `.at(Date)`. Remote push (APNs/FCM/OneSignal) is not in the module — added when the first app adopts server-side push; local scheduling works without `configure`, but foreground presentation and tap routing need it.

## Sharing — `PASKitSharing`, not hand-rolled ImageRenderer/Instagram/Photos plumbing

The app designs the cards (explicit colors — `.accentColor`/`.tint` do **not** resolve inside `ImageRenderer`); PASKit runs the pipeline:
```swift
import PASKitSharing

// Render at canonical size — story full-bleed, sticker transparent:
let story   = PASShareCard.render(StoryCard(stats: stats), size: .init(width: 1080, height: 1920))
let sticker = PASShareCard.render(StickerCard(stats: stats), size: StickerCard.canonicalSize, opaque: false)

// Instagram Stories — returns false when Instagram can't open; app owns the fallback:
if await PASInstagramStories.share(background: story) == false {
    shareItems = PASShareItems([story, "Day 12 done 💪"])
}
// .sheet(item: $shareItems) { PASActivitySheet(items: $0.items) }

// Save to Photos (app Info.plist must declare NSPhotoLibraryAddUsageDescription):
try await PASPhotoLibrary.save(story)

// Sticker-to-clipboard flow — pair with a confirmation alert/toast:
PASInstagramStories.copySticker(sticker)
```
Previews that match the render pixel-for-pixel: `PASScaledCardPreview(cardSize:containerSize:)` (same `cardSize` as the render call); transparent stickers preview over `PASTransparencyCheckerboard` with `clipsToCard: false`. `PASInstagramStories` and `PASActivitySheet.present` are app-only (unavailable in extensions). Add `instagram-stories` to `LSApplicationQueriesSchemes` only if you pre-check availability for showing/hiding an Instagram button.

## Baseline

iOS 18+, macOS 15+, swift-tools 6.2, Swift 6 language mode. SwiftLint via `SimplyDanny/SwiftLintPlugins` — one shared `.swiftlint.yml` in the repo root.

## Build philosophy

A capability earns a place in PASKit when it's used across multiple apps (RevenueCat and PostHog are universal; UI/theme is per-app). Build on real need — a module is built when the first real app needs it, designed app-agnostic from line one. PASKit owns the *mechanism*; each app owns its *vocabulary* (event names, entitlement names, brand styling).
