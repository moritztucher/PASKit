# Changelog

Multi-version changelog list for Settings — distinct from [`../WhatsNew/`](../WhatsNew/) (one-shot post-update sheet).

## API

- `ChangelogView` — the list view; section header = `v{version}` + optional formatted date.
- `ChangelogEntry` — one released version's record (`version`, `date`, `[ChangelogItem]`).
- `ChangelogItem` — `.added` / `.changed` / `.fixed` / `.note`. Each kind renders a different SF Symbol (`plus.circle`, `arrow.triangle.2.circlepath`, `wrench.adjustable`, `circle`) with `.tint` accent.

## Example

```swift
NavigationLink("Changelog") {
    ChangelogView(entries: [
        ChangelogEntry(version: "1.2.0", date: .now, items: [
            .added("Live Activities on the home screen"),
            .changed("Faster sync"),
            .fixed("Crash on launch under iOS 18.0"),
        ]),
        ChangelogEntry(version: "1.1.0", items: [
            .added("Widget"),
            .note("First public beta."),
        ]),
    ])
}
```

Entries are rendered newest-first in the order supplied — PASKit does not sort.
