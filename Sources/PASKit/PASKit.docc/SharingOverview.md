# Sharing Overview

PASKit's share-card export — SwiftUI→image rendering, Instagram Stories, save-to-Photos, and the system share sheet. The app owns the card designs.

## Overview

`PASKitSharing` owns the mechanism of turning a SwiftUI card into a shareable image and handing it off — to Instagram Stories, the Photos library, or the system share sheet. Apps own the card designs, captions, and fallback policy. Apple frameworks only, no vendor dependency. iOS-only flows are `#if canImport(UIKit)`-gated; macOS compiles with them out.

## Render a card

```swift
import PASKitSharing

let story = PASShareCard.render(
    StoryCard(stats: stats),
    size: CGSize(width: 1080, height: 1920)
)
```

`render` runs an `ImageRenderer` at a canonical size (3× by default; `opaque: false` for transparent stickers). **Card views must use explicit colors** — `.accentColor` / `.tint` don't resolve inside `ImageRenderer`.

## Hand off

```swift
if let story, await PASInstagramStories.share(background: story) == false {
    shareItems = PASShareItems([story, "Day 12 done 💪"])   // Instagram missing → activity sheet
}
if let story { try await PASPhotoLibrary.save(story) }       // Info.plist: NSPhotoLibraryAddUsageDescription
```

`PASInstagramStories.share` returns `false` when Instagram can't open, so the caller owns the fallback. `PASShareItems` + `PASActivitySheet` drive the system share sheet (`.sheet(item:)` or imperative `present`).

## Preview faithfully

`PASScaledCardPreview` renders a card pixel-faithful to the export, and `PASTransparencyCheckerboard` backs transparent stickers — so what you see in a `#Preview` matches what ships.

## Scope

Card designs, captions, CTA chrome, and share-option carousels stay per-app. `PASInstagramStories` and `PASActivitySheet.present` are app-only (unavailable in extensions); for a pre-check Instagram button, list `instagram-stories` in `LSApplicationQueriesSchemes`.
