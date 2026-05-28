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
| `PASKitCore` | App + device metadata (`AppInfo`, `DeviceInfo`); networking (`NetworkService`, `URLSessionNetworkService`); shared error domain (`PASError`); reachability (`Reachability` protocol + `@MainActor @Observable NWReachability`); credentials (`CredentialVault` protocol + `KeychainCredentialVault`); logging (`PASLogger` → `os.Logger`); haptics (`Haptics.play`, `View.hapticOnTap`). |
| `PASKitLifecycle` | App-lifecycle UI: `View.presentAppRating(...)`, `View.presentAppFeedback(...)` + `FeedbackSheet`, `View.loading(...)` + `DefaultLoadingView`, `View.paskitGlass(...)` + `View.paskitGlassButtonStyle(...)` (iOS 26 with pre-26 fallback), `VersionCheckManager` + `AppUpdateView`, `WhatsNewView` with `@WhatsNewCardResultBuilder`, `ChangelogView` (`ChangelogEntry` / `ChangelogItem`), `MailComposerView` (iOS), `AppInfoFooter` (iOS). |
| `PASKitPurchases` | RevenueCat wrapper. **Stub today** — namespace placeholder only. |
| `PASKitAnalytics` | PostHog facade: `PASAnalytics.shared.setup(...)` / `.capture` / `.screen` / `.identify` / `.register` / `.reset` / `.optIn` / `.optOut` / `.flush` / `.isFeatureEnabled` / `.featureFlagPayload`. App owns event vocabulary as an extension on `PASAnalytics`. |
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
//       FeedbackSheet { payload in try await sendFeedback(payload) }
//   }
```

Mail composer is still available for the simple "open a prefilled mail draft" use case (iOS-only):
```swift
if MailComposerView.canSendMail {
    .sheet { MailComposerView(recipients: ["support@..."]) }
}
```

Settings footer (iOS): `AppInfoFooter()` — renders app icon (via `CFBundleIcons`) + name + version.

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

**7. Don't reinvent what PASKit owns.** Before writing a local utility for networking, keychain, reachability, version/build reads, app-icon loading at runtime, rate prompt, what's-new, update check, or settings footer — check PASKit. If something belongs in PASKit but isn't there yet, extend PASKit rather than ship a parallel local copy.

## Not yet built

- `PASKitPurchases` is a stub. Use the RevenueCat SDK directly until the module is implemented; expand the stub when wiring up paywalls.

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

## Baseline

iOS 18+, macOS 15+, swift-tools 6.3, Swift 6 language mode. SwiftLint via `SimplyDanny/SwiftLintPlugins` — studio-wide `.swiftlint.yml` (matches the Dashboard's).

## Build philosophy

A capability earns a place in PASKit when it's used across the studio's portfolio (RevenueCat and PostHog are universal; UI/theme is per-app). Build on real need — a module is built when the first real app needs it, designed app-agnostic from line one. PASKit owns the *mechanism*; each app owns its *vocabulary* (event names, entitlement names, brand styling).
