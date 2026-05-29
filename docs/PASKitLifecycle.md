# PASKitLifecycle

**Status:** Built — eleven components.
**Dependencies:** `PASKitCore`. StoreKit, SwiftUI, MessageUI (iOS), UIKit (iOS).
**Platforms:** iOS 18+, macOS 15+. The mail composer and the runtime app-icon loader are iOS-only (`#if canImport(MessageUI)` / `#if canImport(UIKit)`); the rest works on both.

## Purpose

App-lifecycle / app-meta UI — the housekeeping surfaces every app needs and that stay brand-light. Views use SwiftUI defaults (system colours, system fonts, `.tint`); apps style via the standard SwiftUI environment (`.tint(.brand)`, `.font(...)`, etc.). PASKit has no design module — theme stays per-app.

## Components

### AppRatingHelper — ✅ built (`AppRatingHelper.swift`)
`View.presentAppRating(initialCondition:askLaterCondition:)` — a view modifier wrapping StoreKit's `requestReview`. Two-stage alert (Yes / Ask Later / Never Ask Me Again; then Yes / Nope). Caller supplies the trigger conditions as async closures. State persisted via `@AppStorage`. Extracted from a shipped Mandarin-learning app.

### AppFeedbackHelper — ✅ built (`AppFeedbackHelper.swift`)
`View.presentAppFeedback(initialCondition:askLaterCondition:content:)` — same two-stage pattern as `presentAppRating`, but accepting presents the supplied view as a sheet (typically `FeedbackSheet`). The destination view is injected so apps can wire any feedback view. One-shot, state persisted via `@AppStorage`. Cross-platform.

### FeedbackSheet — ✅ built (`FeedbackSheet.swift`)
In-app feedback form. PASKit owns the form UI (category picker, name, email, message); the caller owns the transport via `onSubmit: @Sendable (FeedbackPayload) async throws -> Void`. Configurable hero (`title`, `subtitle`, `heroSymbol`) and `categories` array. Adaptive layout — two-pane on regular width / macOS, stacked on compact iOS. Dismisses on successful submit; surfaces an alert on thrown errors.

### LoadingOverlay — ✅ built (`LoadingOverlay.swift`)
`View.loading(isPresented:message:)` (system-default `ProgressView` + optional caption) and `View.loading(isPresented:content:)` (custom view) — both render a centred card over a dimmed backdrop with a fade transition, blocking underlying interaction. PASKit owns the mechanism; apps that want a branded loading view (spinning app-icon, determinate progress ring) pass it via `content:`. `DefaultLoadingView` is public so apps can compose it directly. Extracted from a shipped Mandarin-learning app.

### VersionCheckManager — ✅ built (`VersionCheckManager.swift`)
`@MainActor public final class` — hits `https://itunes.apple.com/lookup?bundleId=...`, compares against `AppInfo.version`. Compares only major.minor — patch differences are ignored. Returns `Result?` (current / available version + App Store URL).

### AppUpdateView — ✅ built (`AppUpdateView.swift`)
SwiftUI view presenting the update prompt. System styling, `.borderedProminent` "Update App" button that opens the App Store URL via `openURL`. Self-sets `.presentationDetents([.medium])` so apps presenting it via `.sheet(item:)` get the right height automatically; drag indicator visible when dismissible. `forceUpdate: Bool = false` controls dismissibility — defaults to a dismissible nudge; reserve `true` for security releases.

### WhatsNewView — ✅ built (`WhatsNewView.swift`)
Declarative card-list view using `@WhatsNewCardResultBuilder` and a staggered `blurSlide` entrance animation. Strings (`appName`, `title`, `footerMessage`, `continueButtonTitle`) are parameters; cards take SF Symbol names. Styling via `.tint`, `.primary`, `.secondary`.

### ChangelogView — ✅ built (`ChangelogView.swift`)
Multi-version changelog list for Settings — distinct from `WhatsNewView` (single-release sheet shown once after an update). Apps supply `[ChangelogEntry]` (newest first); each entry's `items: [ChangelogItem]` are tagged `.added` / `.changed` / `.fixed` / `.note` and rendered with SF Symbols (`plus.circle`, `arrow.triangle.2.circlepath`, `wrench.adjustable`, `circle`) plus `.tint` accent. Resolves bullet-list and `+/~/*` prefix variants from prior apps into one typed shape. Section header = `v{version}` + optional formatted date.

### MailComposerView — ✅ built (`MailComposerView.swift`, iOS-only)
Thin `UIViewControllerRepresentable` over `MFMailComposeViewController` — configurable recipients, subject, body, and an `onDismiss` `Result` callback. Static `canSendMail` check to gate presentation. iOS-only — `MessageUI` is not available on macOS.

### AppInfoFooter — ✅ built (`AppInfoFooter.swift`, iOS-only)
Settings-screen footer: app icon + display name + version. Loads the app's own icon at runtime via `CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconFiles`. iOS-only.

### LiquidGlass — ✅ built (`LiquidGlass.swift`)
`View.paskitGlass(_:in:)` and `View.paskitGlassButtonStyle(_:)`. iOS/macOS 26+ uses Apple's `glassEffect` + `.buttonStyle(.glass)`; earlier OSes fall back to `.regularMaterial` (+ optional tint overlay) / `.borderedProminent` (or `.bordered` for the clear variant). `PASGlass` is chainable — `.regular.tint(...)` colours the material, `.foreground(...)` colours the wrapped content. Surfaces only — PASKit deliberately does not wrap `.toolbarBackground` / `.toolbarForegroundStyle`; those are already cross-version and nav bars adopt Liquid Glass automatically on iOS 26.

## Notes

- No `PASKitUI` / `PASTheme` dependency — views use SwiftUI's environment-injected styling. Apps style at the call site (`.tint`, `.font`, `.preferredColorScheme`, etc.).
- Built against SwiftLint with the repo's shared config — no warnings on these files.

## Remaining

- [ ] Unit tests where practical (`VersionCheckManager.requiresUpdate` is the obvious target).
- [ ] Localisation of `AppUpdateView` / `FeedbackSheet` strings if a non-English app consumes the views.
- [ ] File attachments on `FeedbackSheet` — add when the first app needs them.
