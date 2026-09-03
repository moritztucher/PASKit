# WhatsNew

The one-shot "what's new in this release" card sheet, plus the cadence gate that decides when it is due. For the retrospective multi-release log in Settings, see [`../Changelog/`](../Changelog/) — both read the same `[ReleaseNote]`.

## API

- `WhatsNewGate` — decides whether the sheet is due and collects the highlights for every build the user skipped. `UserDefaults`-backed; the key is an init parameter because it is installed-user state.
- `WhatsNewHighlights` — the `.sheet(item:)` presentation value. Carries the cards, so an empty sheet is unrepresentable.
- `WhatsNewView` — the sheet. PASKit owns layout, spacing and the staggered blur-slide entrance; three optional slots take the app's chrome.
- `WhatsNewCard` — one feature card (SF Symbol + title + subtitle).
- `WhatsNewCardResultBuilder` — declarative card builder, for cards written inline.
- `WhatsNewHeaderConfiguration` / `WhatsNewCardConfiguration` / `WhatsNewActionConfiguration` — what the slots receive.

## Example

```swift
@State private var highlights: WhatsNewHighlights?
private let gate = WhatsNewGate()   // pass lastSeenBuildKey: if the app already shipped one

.task {
    let build = WhatsNewGate.currentBuild
    guard hasCompletedOnboarding else { gate.seed(currentBuild: build); return }
    guard let build, let cards = gate.highlightsForLaunch(currentBuild: build, notes: ReleaseNotes.all)
    else { return }
    gate.markPresented(build: build)          // mark even when cards is empty — state must converge
    guard !cards.isEmpty else { return }
    highlights = WhatsNewHighlights(cards: cards)
}
.sheet(item: $highlights) { highlights in
    WhatsNewView(cards: highlights.cards, headerSymbol: "sparkles") { self.highlights = nil }
}
```

## Branding

Layout, spacing and animation are PASKit's — that is the point. Chrome is the app's, through three chainable slots:

```swift
WhatsNewView(cards: highlights.cards) { self.highlights = nil }
    .header { _ in Image(systemName: "dumbbell.fill").foregroundStyle(.brandGradient) }
    .cardContainer { config in BrandCard { config.content } }
    .continueButton { config in BrandButton(config.title, action: config.action) }
    .background { BrandBackground() }
```

Wrap `config.content`; never rebuild it. Accent colour otherwise comes from `.tint`. Symbols render exactly as named — PASKit forces no variant, so author `star.fill` when you want the filled glyph. Strings are rendered verbatim — PASKit ships no string catalog, so pass already-localized text.

## Dismissal

The sheet defaults to `isDismissible: false`: shown once after an update, it should be acknowledged, so the CTA is the only way out. Pass `isDismissible: true` when the user opened it deliberately — a "What's New" row in Settings — where suppressing the standard sheet gesture is only friction. Pair `true` with `.presentationDragIndicator(.visible)`; a visible grabber alongside the default `false` shows a control that does nothing.
