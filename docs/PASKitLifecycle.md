# PASKitLifecycle

**Status:** Built — eight components.
**Dependencies:** `PASKitCore`. StoreKit, SwiftUI, MessageUI (iOS), UIKit (iOS).
**Platforms:** iOS 18+, macOS 15+. The mail composer and the runtime app-icon loader are iOS-only (`#if canImport(MessageUI)` / `#if canImport(UIKit)`); the rest works on both.

## Purpose

App-lifecycle / app-meta UI — the housekeeping surfaces every app needs and that stay brand-light. Views use SwiftUI defaults (system colours, system fonts, `.tint`); apps style via the standard SwiftUI environment (`.tint(.brand)`, `.font(...)`, etc.). PASKit has no design module — theme stays per-app.

## Components

### AppRatingHelper — ✅ built (`AppRatingHelper.swift`)
`View.presentAppRating(initialCondition:askLaterCondition:)` — a view modifier wrapping StoreKit's `requestReview`. Two-stage alert (Yes / Ask Later / Never Ask Me Again; then Yes / Nope). Caller supplies the trigger conditions as async closures. State persisted via `@AppStorage`. Extracted from XueTang.

### AppFeedbackHelper — ✅ built (`AppFeedbackHelper.swift`)
`View.presentAppFeedback(initialCondition:askLaterCondition:content:)` — same two-stage pattern as `presentAppRating`, but accepting presents the supplied view as a sheet (typically `FeedbackSheet`). The destination view is injected so apps can wire any feedback view. One-shot, state persisted via `@AppStorage`. Cross-platform.

### FeedbackSheet — ✅ built (`FeedbackSheet.swift`)
In-app feedback form. PASKit owns the form UI (category picker, name, email, message); the caller owns the transport via `onSubmit: @Sendable (FeedbackPayload) async throws -> Void`. Configurable hero (`title`, `subtitle`, `heroSymbol`) and `categories` array. Adaptive layout — two-pane on regular width / macOS, stacked on compact iOS. Dismisses on successful submit; surfaces an alert on thrown errors.

### VersionCheckManager — ✅ built (`VersionCheckManager.swift`)
`@MainActor public final class` — hits `https://itunes.apple.com/lookup?bundleId=...`, compares against `AppInfo.version`. Compares only major.minor — patch differences are ignored. Returns `Result?` (current / available version + App Store URL).

### AppUpdateView — ✅ built (`AppUpdateView.swift`)
SwiftUI view presenting the update prompt. System styling, `.borderedProminent` "Update App" button that opens the App Store URL via `openURL`. `forceUpdate: Bool = false` controls dismissibility — defaults to a dismissible nudge; reserve `true` for security releases.

### WhatsNewView — ✅ built (`WhatsNewView.swift`)
Declarative card-list view using `@WhatsNewCardResultBuilder` and a staggered `blurSlide` entrance animation. Strings (`appName`, `title`, `footerMessage`, `continueButtonTitle`) are parameters; cards take SF Symbol names. Styling via `.tint`, `.primary`, `.secondary`.

### MailComposerView — ✅ built (`MailComposerView.swift`, iOS-only)
Thin `UIViewControllerRepresentable` over `MFMailComposeViewController` — configurable recipients, subject, body, and an `onDismiss` `Result` callback. Static `canSendMail` check to gate presentation. iOS-only — `MessageUI` is not available on macOS.

### AppInfoFooter — ✅ built (`AppInfoFooter.swift`, iOS-only)
Settings-screen footer: app icon + display name + version. Loads the app's own icon at runtime via `CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconFiles`. iOS-only.

## Notes

- No `PASKitUI` / `PASTheme` dependency — views use SwiftUI's environment-injected styling. Apps style at the call site (`.tint`, `.font`, `.preferredColorScheme`, etc.).
- Built against SwiftLint with the studio-wide config — no warnings on these files.

## Remaining

- [ ] Unit tests where practical (`VersionCheckManager.requiresUpdate` is the obvious target).
- [ ] Localisation of `AppUpdateView` / `FeedbackSheet` strings if a non-English app consumes the views.
- [ ] File attachments on `FeedbackSheet` — add when the first app needs them.
