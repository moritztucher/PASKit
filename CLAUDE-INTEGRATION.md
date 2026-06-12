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
| `PASKitCore` | App + device metadata (`AppInfo`, `DeviceInfo`); networking (`NetworkService`, `URLSessionNetworkService`); shared error domain (`PASError`); reachability (`Reachability` protocol + `@MainActor @Observable NWReachability`); credentials (`CredentialVault` protocol + `KeychainCredentialVault`); logging (`PASLogger` → `os.Logger`); haptics (`Haptics.play`, `View.hapticOnTap`); settings (`PASSettingsStore` + `@PASDefault` + `UserDefaultsStorable`); draft persistence (`PASDraft`). |
| `PASKitLifecycle` | App-lifecycle UI: `View.presentAppRating(...)`, `View.presentAppFeedback(...)` + `FeedbackSheet`, `View.loading(...)` + `DefaultLoadingView`, `View.paskitGlass(...)` + `View.paskitGlassButtonStyle(...)` (iOS 26 with pre-26 fallback), `VersionCheckManager` + `AppUpdateView`, `WhatsNewView` with `@WhatsNewCardResultBuilder`, `ChangelogView` (`ChangelogEntry` / `ChangelogItem`), `MailComposerView` (iOS), `AppInfoFooter` (iOS), onboarding engine (`PASOnboardingFlow` + `View.pasOnboardingTransition` + `PASOnboardingProgressBar`). |
| `PASKitPurchases` | RevenueCat facade: `PASPurchases.shared.configure(...)` / `.customerInfo` (observable, stream-fed) / `.isEntitled` / `.offerings` / `.currentOffering` / `.offering(identifier:)` / `.products` / `.purchase(package/product)` → `PASPurchaseResult` / `.restorePurchases` / `.logIn` / `.logOut`. App owns entitlement + product IDs and the paywall UI. |
| `PASKitAnalytics` | PostHog facade: `PASAnalytics.shared.setup(...)` / `.capture` / `.screen` / `.identify` / `.register` / `.reset` / `.optIn` / `.optOut` / `.flush` / `.isFeatureEnabled` / `.featureFlagPayload`. App owns event vocabulary as an extension on `PASAnalytics`. |
| `PASKitNotifications` | Local-notification facade: `PASNotifications.shared.configure(...)` / `.authorizationStatus` + `.isAuthorized` (observable) / `.onResponse` (tap routing, cold-start buffered) / `.requestAuthorization` / `.schedule(PASNotificationRequest)` / `.cancel(ids:)` / `.cancelAll` / `.pendingIDs` / `.setBadgeCount`. App owns scheduling policy, copy, identifiers, and navigation. |
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

**5. Lifecycle UI — use what `PASKitLifecycle` ships before writing your own.**

Rate prompt:
```swift
import PASKitLifecycle
SomeView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 }
)
```

Update check:
```swift
let result = await VersionCheckManager().checkIfAppUpdateAvailable()
// present .sheet(item: $result) { AppUpdateView(update: $0) }
// AppUpdateView(update:, forceUpdate: false) — dismissible nudge by default
```

What's-new (one-shot post-update sheet):
```swift
WhatsNewView(appName: "MyApp", title: "What's New") {
    WhatsNewCard(symbol: "star.fill", title: "X", subtitle: "Y")
    WhatsNewCard(symbol: "bolt.fill", title: "A", subtitle: "B")
} onContinue: { dismiss() }
```
SF Symbol names for `symbol`, not asset names.

Changelog (multi-version Settings screen — distinct from the one-shot `WhatsNewView`):
```swift
NavigationLink("Changelog") {
    ChangelogView(entries: [
        ChangelogEntry(version: "1.2.0", date: .now, items: [
            .added("Live Activities on the home screen"),
            .changed("Faster sync"),
            .fixed("Crash on launch under iOS 18.0"),
        ]),
        ChangelogEntry(version: "1.1.0", items: [
            .added("Widget"),
            .note("First public beta."),
        ]),
    ])
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

Onboarding — PASKit owns the step engine and transition choreography; the app owns step vocabulary, step views, and navigation chrome (buttons/bars are brand):
```swift
enum Step: String, Codable, Hashable { case welcome, units, permissions }

// Static flow — or pass a closure for conditional steps that appear/disappear
// as earlier answers change: PASOnboardingFlow { model.visibleSteps }
@State private var flow = PASOnboardingFlow(steps: Step.allCases)

VStack(spacing: 0) {
    PASOnboardingProgressBar(progress: flow.progress)          // brand via .tint
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
Card(...).paskitGlass(in: .rect(cornerRadius: 16))
Card(...).paskitGlass(.regular.tint(.orange), in: .rect(cornerRadius: 16))      // tint the glass
Card(...).paskitGlass(.regular.foreground(.white), in: .capsule)                // tint the text
Card(...).paskitGlass(.regular.tint(.orange).foreground(.white), in: .capsule)  // both
```

For glass buttons (iOS 26+ uses `.buttonStyle(.glass)`; pre-26 falls back to `.borderedProminent` / `.bordered`):
```swift
Button("Continue") { ... }.paskitGlassButtonStyle()         // .regular
Button("Dismiss") { ... }.paskitGlassButtonStyle(.clear)    // clear variant
```

Do not apply `paskitGlass` to nav bars or toolbars — they adopt Liquid Glass automatically on iOS 26 and the existing `.toolbarBackground(_:for:)` / `.toolbarForegroundStyle(_:for:)` are cross-version.

**6. Styling — SwiftUI defaults + the standard environment.** PASKit views use `.tint`, system fonts, `.primary` / `.secondary`. Apps style at the call site (`.tint(.brand)`, `.font(...)`). PASKit owns no design layer — every app keeps its own theme.

**7. Don't reinvent what PASKit owns.** Before writing a local utility for networking, keychain, reachability, version/build reads, app-icon loading at runtime, rate prompt, what's-new, update check, settings footer, a UserDefaults-backed settings store, or local notifications (permission, scheduling, tap routing) — check PASKit. If something belongs in PASKit but isn't there yet, extend PASKit rather than ship a parallel local copy.

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

// Custom paywall flow:
let offering = try await PASPurchases.shared.currentOffering()
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
    userInfo: ["destination": "path"],
    trigger: .calendar(DateComponents(hour: 20), repeats: false)
))

// Cancel when the condition clears (e.g. the user opened the app today):
PASNotifications.shared.cancel(ids: ["streak-protection"])
```
Rules: never cache a permission boolean — observe `authorizationStatus` (auto-refreshed on iOS foreground return). Use stable, app-vocabulary notification ids (`"streak-protection"`), not UUIDs — replace-on-reschedule + `cancel(ids:)` depend on them. `userInfo` is `[String: String]` routing keys only, not state. Triggers: `.interval(_:repeats:)`, `.calendar(DateComponents, repeats:)`, `.at(Date)`. Remote push (APNs/FCM/OneSignal) is not in the module — added when the first app adopts server-side push; local scheduling works without `configure`, but foreground presentation and tap routing need it.

## Baseline

iOS 18+, macOS 15+, swift-tools 6.3, Swift 6 language mode. SwiftLint via `SimplyDanny/SwiftLintPlugins` — one shared `.swiftlint.yml` in the repo root.

## Build philosophy

A capability earns a place in PASKit when it's used across multiple apps (RevenueCat and PostHog are universal; UI/theme is per-app). Build on real need — a module is built when the first real app needs it, designed app-agnostic from line one. PASKit owns the *mechanism*; each app owns its *vocabulary* (event names, entitlement names, brand styling).
