# Lifecycle UI Overview

The housekeeping UI every app eventually wants — rate prompt, what's-new, changelog, feedback form, loading overlay, update gate, Liquid Glass.

## Overview

`PASKitLifecycle` ships the surfaces that aren't part of an app's core flow but show up in every product eventually. Views use SwiftUI's environment-driven styling (`.tint`, system fonts, `.primary` / `.secondary`); apps style at the call site rather than handing PASKit a theme.

## Rate prompt

A two-stage StoreKit prompt with caller-supplied trigger conditions:

```swift
ContentView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 }
)
```

The first prompt offers Yes / Ask Later / Never Ask Me Again. If the user picks Ask Later, the second prompt offers Yes / Nope. One-shot for the lifetime of the install; state persisted via `@AppStorage`.

## Feedback prompt + sheet

Same two-stage pattern, but accepting presents a sheet — typically the built-in `FeedbackSheet` form:

```swift
ContentView().presentAppFeedback(
    initialCondition: { await sessions.count >= 5 },
    askLaterCondition: { await sessions.count >= 12 }
) {
    FeedbackSheet { payload in
        try await sendFeedback(payload)   // app picks transport
    }
}
```

`FeedbackSheet` ships the category picker, name field, email field, message field, and the hero copy — all configurable. The `onSubmit` closure is the app's transport (email, HTTP, webhook). PASKit owns the form; the app owns delivery.

## Release notes: one source, two surfaces

A release is authored once, as a `ReleaseNote`. It carries both shapes — the full change list and the short highlight cards — so the two surfaces can never drift:

```swift
let notes = [
    ReleaseNote(
        build: 45, version: "1.2.0", date: "2026-09-02",
        changes: ["+ Live Activities on the home screen", "~ Fixed a crash on launch"],
        highlights: [
            WhatsNewCard(symbol: "bolt.fill", title: "Live Activities", subtitle: "From the lock screen."),
        ]
    ),
]
```

- `WhatsNewView` — the one-shot post-update card sheet, shown once after a build bump.
- `ChangelogView` — the retrospective multi-release list for Settings, with typed items (`.added`, `.changed`, `.fixed`, `.note`).

`WhatsNewGate` owns the cadence — including catching a user up on every build they skipped, and staying quiet on downgrades:

```swift
let gate = WhatsNewGate()
if let build = WhatsNewGate.currentBuild,
   let cards = gate.highlightsForLaunch(currentBuild: build, notes: notes) {
    gate.markPresented(build: build)          // mark even when cards is empty
    if !cards.isEmpty { highlights = WhatsNewHighlights(cards: cards) }
}

NavigationLink("What's New") { ChangelogView(notes: notes) }
```

A build whose `highlights` are empty is absorbed silently, so "don't interrupt for a patch" is an authoring choice, not a gate change.

Both views take the app's chrome through chainable slots — `.header { }`, `.cardContainer { }`, `.continueButton { }`, `.entryContainer { }` — while PASKit keeps the layout and the entrance animation.

## Update gate

Check for an App Store update via `VersionCheckManager`:

```swift
let result = await VersionCheckManager().checkIfAppUpdateAvailable()
// .sheet(item: $result) { AppUpdateView(update: $0) }
```

`AppUpdateView` self-sets a `.medium` presentation detent so apps don't have to remember; pass `forceUpdate: true` for security releases.

## Loading overlay

System spinner over a dimmed backdrop:

```swift
ContentView().loading(isPresented: $isLoading, message: "Signing in…")
```

Or supply a branded loading view (custom animation, determinate progress, app-icon ring):

```swift
ContentView().loading(isPresented: $isLoading) {
    MyBrandedLoadingView(progress: progress)
}
```

## Liquid Glass

Surfaces only — cards, sheet content, custom backgrounds. iOS 26 uses Apple's `glassEffect`; earlier OSes fall back to `.regularMaterial` with an optional tint overlay:

```swift
Card(...).pasGlass(in: .rect(cornerRadius: 16))
Card(...).pasGlass(.regular.tint(.orange), in: .rect(cornerRadius: 16))
Card(...).pasGlass(.regular.foreground(.white), in: .capsule)
```

For buttons that should adopt Liquid Glass with a pre-26 fallback:

```swift
Button("Continue") { ... }.pasGlassButtonStyle()
Button("Dismiss") { ... }.pasGlassButtonStyle(.clear)
```

Do not apply `PASGlass` to nav bars or toolbars — they adopt Liquid Glass automatically on iOS 26, and `.toolbarBackground(_:for:)` is already cross-version.
