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
├── Rating/        View+PresentAppRating.swift, PASAppRatingKeys.swift, PASAppRatingCopy.swift
├── Feedback/      FeedbackPayload.swift, FeedbackSheet.swift,
│                  View+PresentAppFeedback.swift, MailComposerView.swift,
│                  PASAppFeedbackKeys.swift, PASAppFeedbackCopy.swift
├── Update/        VersionCheckManager.swift, AppUpdateView.swift
├── WhatsNew/      WhatsNewCard.swift, WhatsNewCardResultBuilder.swift, WhatsNewView.swift,
│                  WhatsNewSlots.swift, WhatsNewGate.swift, WhatsNewHighlights.swift
├── Changelog/     ReleaseNote.swift, ChangelogItem.swift, ChangelogView.swift,
│                  ChangelogSlots.swift
├── Loading/       DefaultLoadingView.swift, View+Loading.swift
├── LiquidGlass/   PASGlass.swift, PASGlassButtonVariant.swift, View+PasGlass.swift,
│                  View+PasConcentricClip.swift
├── Onboarding/    PASOnboardingFlow.swift, PASOnboardingDirection.swift,
│                  View+PASOnboardingTransition.swift
├── Development/   View+PASDevelopmentOverlay.swift, PASDevelopmentMenu.swift
├── Toast/         View+PASToast.swift, PASToast.swift
├── Indicators/    PASProgressRing.swift, PASProgressBar.swift
└── Settings/      AppInfoFooter.swift
```

## Components

### Rating — ✅ built
`View.presentAppRating(initialCondition:askLaterCondition:keys:copy:)` — wraps StoreKit's `requestReview` with a two-stage alert (Yes / Ask Later / Never Ask Me Again; then Yes / Nope). Caller supplies trigger conditions as async closures. State persisted via `@AppStorage`. Extracted from a shipped Mandarin-learning app.
- `PASAppRatingKeys` — the two `UserDefaults` keys are an init parameter, not a constant: installed-user state, so an app that already shipped a rate prompt must pass the keys it shipped with or every resolved user sees the prompt replay. `.standard` for new apps.
- `PASAppRatingCopy` — per-stage alert copy is injectable — the string-catalog-free localisation answer for this surface (`String(localized:bundle:)` at the call site) and where app-name personalisation (`"Enjoying \(AppInfo.displayName)?"`) lives. `.standard` byte-matches the strings PASKit has always shown.

### Feedback — ✅ built
- `View.presentAppFeedback(initialCondition:askLaterCondition:keys:copy:content:)` — same two-stage pattern as `presentAppRating`, but accepting presents the supplied view as a sheet (typically `FeedbackSheet`). Destination view is injected so apps can wire any feedback view. One-shot, persisted via `@AppStorage`. Cross-platform.
- `PASAppFeedbackKeys` / `PASAppFeedbackCopy` — same installed-user-state and copy-injection rules as `PASAppRatingKeys` / `PASAppRatingCopy` above.
- `FeedbackSheet` — in-app feedback form. PASKit owns the form UI (category picker, name, email, message); caller owns the transport via `onSubmit: @Sendable (FeedbackPayload) async throws -> Void`. Configurable: hero (`title`, `subtitle`, `heroSymbol` — `nil` hides the symbol), `categories`, prefill (`initialName` / `initialEmail` — pass known identity so users don't retype), `showsCloseButton` (ⓧ top-trailing; replaces Cancel on compact). Adaptive — two-pane on regular width / macOS with inline Cancel/Send, stacked on compact iOS with a full-width large Send. Surfaces an alert on thrown errors. Apps with a locked design language can bypass the form and build their own UI over `FeedbackPayload` (XueTang V2 does) — payload + transport stay the shared mechanism.
- `FeedbackPayload` — the typed payload (`category`, `name`, `email`, `message`).
- `MailComposerView` (iOS-only) — thin `UIViewControllerRepresentable` over `MFMailComposeViewController`. Static `canSendMail` check to gate presentation.

### Update — ✅ built
- `VersionCheckManager` — `@MainActor public final class`. Hits `https://itunes.apple.com/lookup?bundleId=...`, compares against `AppInfo.version`. Compares only major.minor — patch differences ignored. Returns `Result?` (current / available version + App Store URL).
- `AppUpdateView` — SwiftUI view presenting the update prompt. System styling, `.borderedProminent` "Update App" button. Self-sets `.presentationDetents([.medium])` so `.sheet(item:)` apps get the right height automatically; drag indicator visible when dismissible. `forceUpdate: Bool = false` controls dismissibility — reserve `true` for security releases.

### WhatsNew — ✅ built
The one-shot post-update sheet and the cadence that decides when it is due. Extracted from two shipped apps that had carried near-identical copies.
- `WhatsNewGate` — `@MainActor struct`. Decides whether the sheet is due from the build number, and collects the highlights for every build the user skipped, newest build first. Three-way return contract: `nil` = present nothing, mark nothing; `[]` = the build advanced but nothing was authored, so mark presented and show nothing (state converges instead of re-checking forever); non-empty = mark presented and show the sheet. Downgrades keep the stored maximum. `seed(currentBuild:)` records a fresh install's build during onboarding so finishing onboarding in-session can never trigger the sheet. `static currentBuild` reads `Int(AppInfo.build)`.
  - **The `UserDefaults` key is an init parameter, not a constant** — it is installed-user state, so an app that already shipped a what's-new sheet must pass the key it shipped with or every user sees the sheet replay. `legacyVersionKey` covers migration from an older `CFBundleShortVersionString`-gated sheet: such an install is treated as "has seen nothing" and catches up, and the legacy key is retired only by `markPresented`, so a kill before presentation retries next launch.
  - Build-number gating is deliberate: it is the only cadence that shows TestFlight testers anything. "Don't interrupt for a patch" lives in authoring discipline — ship `highlights: []` for patch builds and the gate absorbs them silently. No gate change is ever needed.
- `WhatsNewHighlights` — the `.sheet(item:)` presentation value. Carrying the cards *as* the value makes the empty-sheet race (SwiftUI capturing `[]` before the same-transaction write lands) unrepresentable.
- `WhatsNewView` — the sheet. PASKit owns layout, spacing and the staggered `blurSlide` entrance; the sheet stays inert until the footer lands so the CTA cannot be tapped mid-entrance. Strings (`title`, `headerSymbol`, `footerMessage`, `continueButtonTitle`) parameterised and rendered verbatim. Three chainable branding slots — `.header { }`, `.cardContainer { }`, `.continueButton { }` — take the app's chrome; the app applies its own background at the call site. Accent otherwise via `.tint`. `isDismissible` (default `false`) controls swipe-to-dismiss: `false` for the one-shot post-update sheet, which should be acknowledged; `true` for a sheet the user opened deliberately from Settings, paired with a visible drag indicator.
- `WhatsNewCard` — one feature card (symbol + title + subtitle).
- `WhatsNewCardResultBuilder` — declarative card builder, for cards written inline.

### Changelog — ✅ built
- `ReleaseNote` — the single authoring source behind both changelog surfaces: `build`, `version`, `date`, the full `[ChangelogItem]` list, and the short `[WhatsNewCard]` highlights. `build` is the identity, the sort key, and `WhatsNewGate`'s cadence key, so builds must be unique and strictly increasing. Equality is `build` alone — `WhatsNewCard` carries a per-instance `UUID`, so field-wise equality would never hold. A `date:` string convenience parses ISO `"yyyy-MM-dd"` at noon UTC (so rendering west of UTC cannot roll the day back) and degrades to `nil` on a typo rather than trapping.
- `ChangelogView` — scrolling multi-release list for Settings (distinct from `WhatsNewView`'s single-release sheet). One block per release, newest first in the order supplied — PASKit does not sort. `v{version} ({build})` header, "Latest" badge on the first entry (`latestBadgeTitle: nil` hides it), optional localized date. One branding slot, `.entryContainer { }`, for the app's card surface.
- `ChangelogItem` — `.added` / `.changed` / `.fixed` / `.note`, rendered with SF Symbols (`plus.circle.fill`, `arrow.triangle.2.circlepath`, `wrench.adjustable.fill`, `checkmark.circle.fill`) plus `.tint` accent. `init(prefixed:)` resolves the `+` / `>` / `~` / `*` prefix vocabulary from prior apps into the typed shape; an unmarked line degrades to `.note` carrying the whole string rather than dropping content.

### Loading — ✅ built
- `View.loading(isPresented:message:)` (system-default `ProgressView` + optional caption) and `View.loading(isPresented:content:)` (custom view). Both render a centred card over a dimmed backdrop with a fade transition, blocking underlying interaction.
- `DefaultLoadingView` — public so apps that want the default treatment with extra decoration can compose it directly. Extracted from a shipped Mandarin-learning app.

### LiquidGlass — ✅ built
- `View.pasGlass(_:in:)` (surfaces) and `View.pasGlassButtonStyle(_:)` (buttons). iOS/macOS 26+ uses Apple's `glassEffect` + `.buttonStyle(.glass)`; earlier OSes fall back to `.regularMaterial` (+ optional tint overlay) / `.borderedProminent` (or `.bordered` for `.clear`).
- `PASGlass` — chainable: `.regular.tint(...)` colours the material, `.foreground(...)` colours the wrapped content.
- `PASGlassButtonVariant` — `.regular` / `.clear`.
- `View.pasConcentricClip(fallbackRadius:)` — iOS/macOS 26+ clips with `ConcentricRectangle()` (radius auto-derived from the ancestor's `.containerShape` and inset); pre-26 falls back to a `RoundedRectangle` with the supplied radius (typically `containerRadius − inset`).
- Surfaces only — PASKit deliberately does not wrap `.toolbarBackground` / `.toolbarForegroundStyle`; those are already cross-version and nav bars adopt Liquid Glass automatically on iOS 26.

### Onboarding — ✅ built
- `PASOnboardingFlow<Step: Hashable>` — `@Observable @MainActor` step engine: index-based navigation over a **live step list** (closure, re-evaluated on access, so conditional flows stay correct as answers change; static list via convenience init). `current` / `count` / `isFirst` / `isLast`, `progress = (index+1)/count`, `advance()` / `back()` (bounded, set `direction`), `go(to:)` (jump with direction from index comparison — used by draft resume). Index clamps when a conditional list shrinks underneath it. Engine only — step vocabulary, step views, and navigation chrome stay per-app (the chrome diverged across all surveyed apps; one had no nav buttons at all).
- `PASOnboardingDirection` — `.forward` / `.backward`.
- `View.pasOnboardingTransition(step:direction:animation:)` — the step-change choreography every container hand-rolled: `.id(step)` + direction-flipped asymmetric `.move + .opacity` transition + matching animation (pass the app's motion token).
- Progress chrome: `PASProgressBar` — see the Indicators section below.
- Resume-after-kill pairs with `PASDraft` (PASKitCore): snapshot answers + current step on change/scene-phase, at launch hydrate answers **first**, then `flow.go(to: restoredStep)`.
- Extracted from three production implementations (66-day-challenge app, workout app, habit app); the conditional-steps + draft-resume design follows the workout app's, the most evolved of the three.

### Development — ✅ built
- `View.pasDevelopmentOverlay(alignment:menu:)` — floating "DEV" capsule (hammer + monospaced label, white on `.tint`, `accessibilityIdentifier("PAS_DEV_OVERLAY")`) presenting the app's dev menu as a sheet. **Compile-time DEBUG-gated**: in release the modifier body is `self` — the symbol stays available so call sites build in every configuration; the menu closure is never invoked in release but must compile (gate DEBUG-only menu types *inside* the closure, or gate the call site). TestFlight builds are release config, so testers never see it; a runtime escape hatch gets added only if dev tooling in TestFlight becomes a real need.
- `PASDevelopmentMenu(title:content:)` — menu container chrome: `NavigationStack` + `Form` + inline title + Done. Sections are the app's vocabulary (state toggles, demo seeds, reset buttons, mock-screen links) as plain `Form` content.
- Extracted from four apps' independent dev tooling (floating-overlay, dedicated screen, and settings-section variants); the shell is shared, every menu's contents stay per-app.

### Toast — ✅ built
- `View.pasToast(isPresented:duration:alignment:content:)` and `View.pasToast(item:duration:alignment:content:)` — toast lifecycle: overlay placement (default `.bottom`), slide+fade transition (fade-only under Reduce Motion), spring animation, auto-dismiss after `duration` (default 4s; `nil` = sticky). Dismiss runs on `.task(id:)` so structured cancellation re-arms the timer correctly — a new `item` restarts it (the stale-timer bug a bare `Task.sleep` causes can't happen). Use `item:` whenever consecutive triggers change content.
- `PASToast` — default content row: optional SF symbol + tint, message, optional trailing action ("Undo"); `.ultraThickMaterial` with a Reduce Transparency solid fallback, 16pt rounded, soft shadow. Apps with a locked design language pass their own view and share only the lifecycle.
- Extracted from three apps' hand-rolled toasts (undo snackbar, saved-to-Photos capsule, set-logged row).

### Indicators — ✅ built
- `PASProgressRing` — circular progress indicator, the circular sibling of `PASProgressBar`. Track defaults to a faint adaptive grey (override via `trackColor`), fill is `.tint`, optional `@ViewBuilder` center label, `size`/`lineWidth` params, progress clamped 0…1, `-90°` start + `.round` cap, percentage a11y, spring-animates on progress change (Reduce Motion-aware — snaps instead of springing). Extracted from four apps' rings (the only divergence was color — handled by `.tint` + the track param).
- `PASProgressBar` — slim capsule bar, track `.quaternary` / fill `.tint`, `height` default 4, progress clamped 0…1, percentage a11y, ease-animates on progress change (Reduce Motion-aware). Renamed from `PASOnboardingProgressBar` in v0.3.2 — the bar was never onboarding-specific; the old name survives as a deprecated typealias, planned for removal in the next minor.

### Settings — ✅ built
- `AppInfoFooter` (iOS-only) — Settings-screen footer with app icon (via `CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconFiles`) + display name + version.

## Notes

- No `PASKitUI` / `PASTheme` dependency — views use SwiftUI's environment-injected styling. Apps style at the call site (`.tint`, `.font`, `.preferredColorScheme`, etc.).
- Built against SwiftLint with the repo's shared config — no warnings on these files.

## Remaining

- [ ] Unit tests where practical (`VersionCheckManager.requiresUpdate` is the obvious target).
- [ ] Localisation of `AppUpdateView` / `FeedbackSheet` strings if a non-English app consumes the views.
- [ ] File attachments on `FeedbackSheet` — add when the first app needs them.
