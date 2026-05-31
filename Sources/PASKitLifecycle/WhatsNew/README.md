# WhatsNew

One-shot "what's new in this release" card sheet — present once after a version bump. For a retrospective multi-version log in Settings, see [`../Changelog/`](../Changelog/).

## API

- `WhatsNewView` — the sheet view.
- `WhatsNewCard` — one feature card (SF Symbol + title + subtitle).
- `WhatsNewCardResultBuilder` — declarative card builder (`@resultBuilder`).

## Example

```swift
WhatsNewView(appName: "MyApp", title: "What's New") {
    WhatsNewCard(symbol: "star.fill", title: "Live Activities", subtitle: "Track your streak from the lock screen.")
    WhatsNewCard(symbol: "bolt.fill", title: "Faster Sync", subtitle: "Up to 3x quicker on large libraries.")
} onContinue: { dismiss() }
```

Strings (`appName`, `title`, `footerMessage`, `continueButtonTitle`) are parameters; styling via `.tint`, `.primary`, `.secondary`.
