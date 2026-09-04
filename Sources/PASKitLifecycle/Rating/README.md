# Rating

Two-stage "rate the app" prompt over StoreKit's `requestReview`. Caller supplies the trigger conditions as async closures.

## API

- `View.presentAppRating(initialCondition:askLaterCondition:keys:copy:)` — view modifier.
- `PASAppRatingKeys` — `UserDefaults` keys behind the one-shot state. `.standard` for new apps; pass the keys you already shipped if you're migrating a local rate prompt.
- `PASAppRatingCopy` — alert copy per stage. `.standard` matches PASKit's shipped strings verbatim; strings are shown as-is, so pass `String(localized:)` to localise.

## Example

```swift
ContentView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 }
)
```

Migrating an app that already shipped its own keys and copy:

```swift
ContentView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 },
    keys: PASAppRatingKeys(isCompleted: "isRatingInteractionComplete", isInitialPromptShown: "isInitialPromptComplete"),
    copy: PASAppRatingCopy(initialTitle: "Enjoying \(AppInfo.displayName)?", initialAccept: "Yes, Rate It!")
)
```

The first prompt offers Yes / Ask Later / Never Ask Me Again. After Ask Later, the second prompt offers Yes / Nope. One-shot — once resolved, the modifier stays silent for the life of the install (`@AppStorage`-backed).
