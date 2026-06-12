# PASKitLifecycle

**Status:** Built — twelve components.
**Dependencies:** `PASKitCore`. StoreKit, SwiftUI, MessageUI (iOS), UIKit (iOS).
**Platforms:** iOS 18+, macOS 15+. The mail composer and the runtime app-icon loader are iOS-only (`#if canImport(MessageUI)` / `#if canImport(UIKit)`); the rest works on both.

## Purpose

App-lifecycle / app-meta UI — the housekeeping surfaces every app needs and that stay brand-light. Views use SwiftUI defaults (system colours, system fonts, `.tint`); apps style via the standard SwiftUI environment (`.tint(.brand)`, `.font(...)`, etc.). PASKit has no design module — theme stays per-app.

## Layout

Sources are grouped by topic — one public type per file:

```
Sources/PASKitLifecycle/
├── Rating/        View+PresentAppRating.swift
├── Feedback/      FeedbackPayload.swift, FeedbackSheet.swift,
│                  View+PresentAppFeedback.swift, MailComposerView.swift
├── Update/        VersionCheckManager.swift, AppUpdateView.swift
├── WhatsNew/      WhatsNewCard.swift, WhatsNewCardResultBuilder.swift, WhatsNewView.swift
├── Changelog/     ChangelogItem.swift, ChangelogEntry.swift, ChangelogView.swift
├── Loading/       DefaultLoadingView.swift, View+Loading.swift
├── LiquidGlass/   PASGlass.swift, PASGlassButtonVariant.swift, View+PaskitGlass.swift,
│                  View+PaskitConcentricClip.swift
├── Onboarding/    PASOnboardingFlow.swift, PASOnboardingDirection.swift,
│                  View+PASOnboardingTransition.swift, PASOnboardingProgressBar.swift
└── Settings/      AppInfoFooter.swift
```

## Components

### Rating — ✅ built
`View.presentAppRating(initialCondition:askLaterCondition:)` — wraps StoreKit's `requestReview` with a two-stage alert (Yes / Ask Later / Never Ask Me Again; then Yes / Nope). Caller supplies trigger conditions as async closures. State persisted via `@AppStorage`. Extracted from a shipped Mandarin-learning app.

### Feedback — ✅ built
- `View.presentAppFeedback(initialCondition:askLaterCondition:content:)` — same two-stage pattern as `presentAppRating`, but accepting presents the supplied view as a sheet (typically `FeedbackSheet`). Destination view is injected so apps can wire any feedback view. One-shot, persisted via `@AppStorage`. Cross-platform.
- `FeedbackSheet` — in-app feedback form. PASKit owns the form UI (category picker, name, email, message); caller owns the transport via `onSubmit: @Sendable (FeedbackPayload) async throws -> Void`. Configurable: hero (`title`, `subtitle`, `heroSymbol` — `nil` hides the symbol), `categories`, prefill (`initialName` / `initialEmail` — pass known identity so users don't retype), `showsCloseButton` (ⓧ top-trailing; replaces Cancel on compact). Adaptive — two-pane on regular width / macOS with inline Cancel/Send, stacked on compact iOS with a full-width large Send. Surfaces an alert on thrown errors. Apps with a locked design language can bypass the form and build their own UI over `FeedbackPayload` (XueTang V2 does) — payload + transport stay the shared mechanism.
- `FeedbackPayload` — the typed payload (`category`, `name`, `email`, `message`).
- `MailComposerView` (iOS-only) — thin `UIViewControllerRepresentable` over `MFMailComposeViewController`. Static `canSendMail` check to gate presentation.

### Update — ✅ built
- `VersionCheckManager` — `@MainActor public final class`. Hits `https://itunes.apple.com/lookup?bundleId=...`, compares against `AppInfo.version`. Compares only major.minor — patch differences ignored. Returns `Result?` (current / available version + App Store URL).
- `AppUpdateView` — SwiftUI view presenting the update prompt. System styling, `.borderedProminent` "Update App" button. Self-sets `.presentationDetents([.medium])` so `.sheet(item:)` apps get the right height automatically; drag indicator visible when dismissible. `forceUpdate: Bool = false` controls dismissibility — reserve `true` for security releases.

### WhatsNew — ✅ built
- `WhatsNewView` — declarative card-list view using `@WhatsNewCardResultBuilder` with a staggered `blurSlide` entrance. Strings (`appName`, `title`, `footerMessage`, `continueButtonTitle`) parameterised; cards take SF Symbol names. Styling via `.tint`, `.primary`, `.secondary`.
- `WhatsNewCard` — one feature card (symbol + title + subtitle).
- `WhatsNewCardResultBuilder` — declarative card builder.

### Changelog — ✅ built
- `ChangelogView` — multi-version changelog list for Settings (distinct from `WhatsNewView`'s single-release sheet). Section header = `v{version}` + optional formatted date.
- `ChangelogEntry` — one released version's record (`version`, `date`, `[ChangelogItem]`).
- `ChangelogItem` — `.added` / `.changed` / `.fixed` / `.note`, rendered with SF Symbols (`plus.circle`, `arrow.triangle.2.circlepath`, `wrench.adjustable`, `circle`) plus `.tint` accent. Resolves bullet-list and `+/~/*` prefix variants from prior apps into one typed shape.

### Loading — ✅ built
- `View.loading(isPresented:message:)` (system-default `ProgressView` + optional caption) and `View.loading(isPresented:content:)` (custom view). Both render a centred card over a dimmed backdrop with a fade transition, blocking underlying interaction.
- `DefaultLoadingView` — public so apps that want the default treatment with extra decoration can compose it directly. Extracted from a shipped Mandarin-learning app.

### LiquidGlass — ✅ built
- `View.paskitGlass(_:in:)` (surfaces) and `View.paskitGlassButtonStyle(_:)` (buttons). iOS/macOS 26+ uses Apple's `glassEffect` + `.buttonStyle(.glass)`; earlier OSes fall back to `.regularMaterial` (+ optional tint overlay) / `.borderedProminent` (or `.bordered` for `.clear`).
- `PASGlass` — chainable: `.regular.tint(...)` colours the material, `.foreground(...)` colours the wrapped content.
- `PASGlassButtonVariant` — `.regular` / `.clear`.
- `View.paskitConcentricClip(fallbackRadius:)` — iOS/macOS 26+ clips with `ConcentricRectangle()` (radius auto-derived from the ancestor's `.containerShape` and inset); pre-26 falls back to a `RoundedRectangle` with the supplied radius (typically `containerRadius − inset`).
- Surfaces only — PASKit deliberately does not wrap `.toolbarBackground` / `.toolbarForegroundStyle`; those are already cross-version and nav bars adopt Liquid Glass automatically on iOS 26.

### Onboarding — ✅ built
- `PASOnboardingFlow<Step: Hashable>` — `@Observable @MainActor` step engine: index-based navigation over a **live step list** (closure, re-evaluated on access, so conditional flows stay correct as answers change; static list via convenience init). `current` / `count` / `isFirst` / `isLast`, `progress = (index+1)/count`, `advance()` / `back()` (bounded, set `direction`), `go(to:)` (jump with direction from index comparison — used by draft resume). Index clamps when a conditional list shrinks underneath it. Engine only — step vocabulary, step views, and navigation chrome stay per-app (the chrome diverged across all surveyed apps; one had no nav buttons at all).
- `PASOnboardingDirection` — `.forward` / `.backward`.
- `View.pasOnboardingTransition(step:direction:animation:)` — the step-change choreography every container hand-rolled: `.id(step)` + direction-flipped asymmetric `.move + .opacity` transition + matching animation (pass the app's motion token).
- `PASOnboardingProgressBar` — slim capsule bar, track `.quaternary` / fill `.tint`, animated, accessibility value as percentage.
- Resume-after-kill pairs with `PASDraft` (PASKitCore): snapshot answers + current step on change/scene-phase, at launch hydrate answers **first**, then `flow.go(to: restoredStep)`.
- Extracted from three production implementations (66-day-challenge app, workout app, habit app); the conditional-steps + draft-resume design follows the workout app's, the most evolved of the three.

### Settings — ✅ built
- `AppInfoFooter` (iOS-only) — Settings-screen footer with app icon (via `CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconFiles`) + display name + version.

## Notes

- No `PASKitUI` / `PASTheme` dependency — views use SwiftUI's environment-injected styling. Apps style at the call site (`.tint`, `.font`, `.preferredColorScheme`, etc.).
- Built against SwiftLint with the repo's shared config — no warnings on these files.

## Remaining

- [ ] Unit tests where practical (`VersionCheckManager.requiresUpdate` is the obvious target).
- [ ] Localisation of `AppUpdateView` / `FeedbackSheet` strings if a non-English app consumes the views.
- [ ] File attachments on `FeedbackSheet` — add when the first app needs them.
