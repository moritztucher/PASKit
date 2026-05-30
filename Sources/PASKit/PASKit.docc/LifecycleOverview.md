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

## What's-new vs. changelog

Two different surfaces for two different moments:

- `WhatsNewView` — one-shot post-update card sheet (presented once after a version bump).
- `ChangelogView` — multi-version list for Settings, with typed items (`.added`, `.changed`, `.fixed`, `.note`).

```swift
NavigationLink("Changelog") {
    ChangelogView(entries: [
        ChangelogEntry(version: "1.2.0", date: .now, items: [
            .added("Live Activities on the home screen"),
            .fixed("Crash on launch under iOS 18.0"),
        ]),
    ])
}
```

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
Card(...).paskitGlass(in: .rect(cornerRadius: 16))
Card(...).paskitGlass(.regular.tint(.orange), in: .rect(cornerRadius: 16))
Card(...).paskitGlass(.regular.foreground(.white), in: .capsule)
```

For buttons that should adopt Liquid Glass with a pre-26 fallback:

```swift
Button("Continue") { ... }.paskitGlassButtonStyle()
Button("Dismiss") { ... }.paskitGlassButtonStyle(.clear)
```

Do not apply `PASGlass` to nav bars or toolbars — they adopt Liquid Glass automatically on iOS 26, and `.toolbarBackground(_:for:)` is already cross-version.
