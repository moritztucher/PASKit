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
| `PASKitCore` | App + device metadata (`AppInfo`, `DeviceInfo`); networking (`NetworkService`, `URLSessionNetworkService`); shared error domain (`PASError`); reachability (`Reachability` protocol + `@MainActor @Observable NWReachability`); credentials (`CredentialVault` protocol + `KeychainCredentialVault`); logging (`PASLogger` → `os.Logger`). |
| `PASKitLifecycle` | App-lifecycle UI: `View.presentAppRating(...)`, `View.presentAppFeedback(...)` + `FeedbackSheet`, `VersionCheckManager` + `AppUpdateView`, `WhatsNewView` with `@WhatsNewCardResultBuilder`, `MailComposerView` (iOS), `AppInfoFooter` (iOS). |
| `PASKitPurchases` | RevenueCat wrapper. **Stub today** — namespace placeholder only. |
| `PASKitAnalytics` | PostHog facade. **Stub today** — namespace placeholder only. |
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

What's-new:
```swift
WhatsNewView(appName: "MyApp", title: "What's New") {
    WhatsNewCard(symbol: "star.fill", title: "X", subtitle: "Y")
    WhatsNewCard(symbol: "bolt.fill", title: "A", subtitle: "B")
} onContinue: { dismiss() }
```
SF Symbol names for `symbol`, not asset names.

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

**6. Styling — SwiftUI defaults + the standard environment.** PASKit views use `.tint`, system fonts, `.primary` / `.secondary`. Apps style at the call site (`.tint(.brand)`, `.font(...)`). PASKit owns no design layer — every app keeps its own theme.

**7. Don't reinvent what PASKit owns.** Before writing a local utility for networking, keychain, reachability, version/build reads, app-icon loading at runtime, rate prompt, what's-new, update check, or settings footer — check PASKit. If something belongs in PASKit but isn't there yet, extend PASKit rather than ship a parallel local copy.

## Not yet built

- `PASKitPurchases` is a stub. Use the RevenueCat SDK directly until the module is implemented; expand the stub when wiring up paywalls.
- `PASKitAnalytics` is a stub. Use the PostHog SDK directly until the module is implemented.

## Baseline

iOS 18+, macOS 15+, swift-tools 6.3, Swift 6 language mode. SwiftLint via `SimplyDanny/SwiftLintPlugins` — studio-wide `.swiftlint.yml` (matches the Dashboard's).

## Build philosophy

A capability earns a place in PASKit when it's used across the studio's portfolio (RevenueCat and PostHog are universal; UI/theme is per-app). Build on real need — a module is built when the first real app needs it, designed app-agnostic from line one. PASKit owns the *mechanism*; each app owns its *vocabulary* (event names, entitlement names, brand styling).
