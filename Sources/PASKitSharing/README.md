# PASKitSharing

Share-card export. PASKit owns the mechanism (SwiftUI→image render, Instagram Stories hand-off, save-to-Photos, the system share sheet); apps own the card designs, captions, and fallback policy. Apple frameworks only — no vendor dependency. iOS-only flows are `#if canImport(UIKit)`-gated; macOS compiles with them out.

## API

- `PASShareCard.render(_:size:scale:opaque:colorScheme:)` — SwiftUI card → `UIImage` (`ImageRenderer` at canonical size, 3x default; `opaque: false` for transparent stickers). **Card views must use explicit colors** — `.accentColor` / `.tint` don't resolve inside `ImageRenderer`.
- `PASInstagramStories.share(background:sticker:sourceApplication:)` — Stories pasteboard payload (5-min expiry) + `instagram-stories://` deep link; returns `false` when Instagram can't open (caller owns the fallback). `copySticker(_:)` for the paste-it-yourself flow.
- `PASPhotoLibrary.save(_:)` — add-only authorization + save; typed `PASPhotoLibraryError`.
- `PASShareItems` + `PASActivitySheet` — `.sheet(item:)` share sheet, plus imperative `PASActivitySheet.present(items:onComplete:)`.
- `PASScaledCardPreview` + `PASTransparencyCheckerboard` — previews pixel-faithful to the render; checkerboard for transparent stickers.

## Example

```swift
import PASKitSharing

let story = PASShareCard.render(StoryCard(stats: stats), size: CGSize(width: 1080, height: 1920))
if let story, await PASInstagramStories.share(background: story) == false {
    shareItems = PASShareItems([story, "Day 12 done 💪"])   // Instagram missing → activity sheet
}
if let story { try await PASPhotoLibrary.save(story) }       // Info.plist: NSPhotoLibraryAddUsageDescription
```

## Notes

- Card designs, captions, CTA chrome, and share-option carousels stay per-app.
- `PASInstagramStories` and `PASActivitySheet.present` are app-only (unavailable in extensions). For a pre-check Instagram button, list `instagram-stories` in `LSApplicationQueriesSchemes`.
