# Rating

Two-stage "rate the app" prompt over StoreKit's `requestReview`. Caller supplies the trigger conditions as async closures.

## API

- `View.presentAppRating(initialCondition:askLaterCondition:)` — view modifier.

## Example

```swift
ContentView().presentAppRating(
    initialCondition: { await sessions.count >= 7 },
    askLaterCondition: { await sessions.count >= 14 }
)
```

The first prompt offers Yes / Ask Later / Never Ask Me Again. After Ask Later, the second prompt offers Yes / Nope. One-shot — once resolved, the modifier stays silent for the life of the install (`@AppStorage`-backed).
