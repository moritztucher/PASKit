# PASKitLifecycle

**Status:** Spec — not yet built. Cleanest first module — most reuse evidence, lowest extraction friction.
**Build trigger:** When the first app after XueTang needs these surfaces.
**Dependencies:** `PASKitCore` (`PASTheme`, `AppInfo`). StoreKit, MessageUI.

## Purpose

App-lifecycle / app-meta UI — the housekeeping surfaces every app needs and that are brand-light. All views are built against `PASTheme`; no view hard-codes a colour or string.

## Components

### Rate the App — Easy, near drop-in
Extract XueTang's `AppRatingHelper.swift` almost verbatim. Already app-agnostic: pure StoreKit `requestReview`, two-stage alert, caller-supplied trigger conditions. This is the template for the whole package — generic mechanism, app injects the thresholds.

### App update check — Easy–Moderate
- `VersionCheckManager` — extract as-is. Hits the iTunes lookup API, compares against `CFBundleShortVersionString`. Fully generic already.
- `AppUpdateView` — extract, inject icon + `PASTheme`.
- **Decision:** XueTang force-updates on every major.minor bump (`.interactiveDismissDisabled(true)`). Too aggressive for a portfolio default. Make force-vs-nudge a parameter, **default to dismissible nudge**; reserve the hard gate for security releases.

### WhatsNew — Moderate, clean
Extract XueTang's `WhatsNewView.swift` — keep the declarative `@resultBuilder` card API and the `blurSlide` animation. Abstract the 3 hard-coded strings + design tokens. Trigger logic (version-compare via UserDefaults, skip same-day installs) is generic — extract it too.

### Feedback — thin wrapper only
A `MailComposerView` wrapper (`MFMailComposeViewController`) with a configurable recipient — this is what XueTang actually ships in production.
- **Do NOT extract** XueTang's `FeedbackSheetView` — it is dead code (defined, presented nowhere) and wired straight into PostHog + RevenueCat.

### AppInfoFooter — NEW, build fresh
Settings-screen footer: app icon + app name + version(build). Neither XueTang nor iOS-Conferences has this — build it clean.
- App icon at runtime is the fiddly bit: read `CFBundleIcons → CFBundlePrimaryIcon → CFBundleIconFiles`, take the last entry, load via `UIImage(named:)`. Encapsulate it here once.
- Name + version from `PASKitCore.AppInfo`.

## Extraction sources

- `XueTang/XueTangApp/Core/Utilities/AppRatingHelper.swift`
- `XueTang/XueTangApp/Views/Other/UpdateChecker/VersionCheckManager.swift`
- `XueTang/XueTangApp/Views/Other/UpdateChecker/AppUpdateView.swift`
- `XueTang/XueTangApp/Views/Other/WhatsNew/WhatsNewView.swift`
- iOS-Conferences `Features/Settings/Views/SettingsView.swift` `aboutSection` — reference only; almost nothing to lift (no icon, no name, inline `Bundle.main` version read).

## What needs to be done

- [ ] Rate: lift `AppRatingHelper`, retarget tokens to `PASTheme`.
- [ ] Update check: lift `VersionCheckManager`; rebuild `AppUpdateView` with injected icon + theme + force/nudge param.
- [ ] WhatsNew: lift view + result-builder + animation; parameterise strings + theme.
- [ ] Feedback: build thin `MailComposerView` wrapper.
- [ ] AppInfoFooter: build fresh, incl. runtime app-icon loading.
