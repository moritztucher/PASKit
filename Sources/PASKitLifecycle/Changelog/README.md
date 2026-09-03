# Changelog

The release-note model, and the retrospective multi-release list for Settings — distinct from [`../WhatsNew/`](../WhatsNew/), the one-shot post-update sheet. Both surfaces read the same `[ReleaseNote]`, so a release is authored once.

## API

- `ReleaseNote` — one shipped build in two shapes: the full `items` list this view renders, and the short `highlights` cards `WhatsNewView` shows. `build` is the identity and `WhatsNewGate`'s cadence key, so builds must be unique and strictly increasing.
- `ChangelogItem` — `.added` / `.changed` / `.fixed` / `.note`. Each kind renders its own SF Symbol (`plus.circle.fill`, `arrow.triangle.2.circlepath`, `wrench.adjustable.fill`, `checkmark.circle.fill`) with `.tint` accent. `init(prefixed:)` parses the `+` / `>` / `~` / `*` authoring vocabulary.
- `ChangelogView` — scrolling list, one block per release, newest first in the order supplied. PASKit does not sort.
- `ChangelogEntryConfiguration` — what the `entryContainer` slot receives.

## Example

```swift
enum ReleaseNotes {
    static let all: [ReleaseNote] = [
        ReleaseNote(
            build: 45,
            version: "1.2.0",
            date: "2026-09-02",
            changes: [
                "+ Live Activities on the home screen",
                "~ Fixed a crash on launch under iOS 18.0",
                "* Groundwork for shared plans",
            ],
            highlights: [
                WhatsNewCard(symbol: "bolt.fill", title: "Live Activities", subtitle: "Track your streak from the lock screen."),
            ]
        ),
    ]
}

NavigationLink("What's New") {
    ChangelogView(notes: ReleaseNotes.all)
        .entryContainer { config in BrandCard { config.content } }
        .background { BrandBackground() }
}
```

The newest release gets a "Latest" badge; pass `latestBadgeTitle: nil` to hide it. Dates are stored as `Date` and rendered localized — the `date:` string convenience parses ISO `"yyyy-MM-dd"` and degrades to no date rather than trapping.
