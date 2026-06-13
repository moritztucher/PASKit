# PASKitSharing

**Status:** Built — six components.
**Dependencies:** `PASKitCore`. SwiftUI, UIKit (iOS), Photos (iOS), UniformTypeIdentifiers (iOS) — Apple frameworks only.
**Platforms:** iOS 18+, macOS 15+. Everything except the preview helpers is `#if canImport(UIKit)` — the share flows are iPhone-only in practice; macOS builds compile the module with them gated out.

## Purpose

Share-card export: render an app-designed SwiftUI card to an image, hand it to Instagram Stories, save it to Photos, or present the system share sheet. Extracted from two production twins (a 66-day-challenge app and a workout app) that independently built the same pipeline down to identical pasteboard keys and the same 5-minute expiry. PASKit owns the mechanism; the app owns the card designs, captions, and fallback policy.

## Layout

Sources are one public type per file:

```
Sources/PASKitSharing/
├── PASShareCard.swift               SwiftUI → UIImage rendering
├── PASInstagramStories.swift        Stories deep link + pasteboard payload
├── PASPhotoLibrary.swift            add-only permission + save
├── PASShareItems.swift              Identifiable wrapper for .sheet(item:)
├── PASActivitySheet.swift           UIActivityViewController representable + imperative present
├── PASScaledCardPreview.swift       canonical-size card scaled into a preview container
└── PASTransparencyCheckerboard.swift backdrop communicating sticker transparency
```

## Components

### PASShareCard — ✅ built
`render(_:size:scale:opaque:colorScheme:) -> UIImage?` — `ImageRenderer` plumbing: frames the card at its canonical size (e.g. 1080×1920 story), `scale` 3 by default, `isOpaque: false` for transparent stickers, optional `colorScheme` injection (an `ImageRenderer` has no window to inherit appearance from). **Gotcha carried in the doc comment: `Color.accentColor` / `.tint` do not resolve inside `ImageRenderer` — card views must use explicit colors.**

### PASInstagramStories — ✅ built
- `share(background:sticker:sourceApplication:) async -> Bool` — PNG payload onto `UIPasteboard` under `com.instagram.sharedSticker.backgroundImage` / `.stickerImage` with a 5-minute expiry, then opens `instagram-stories://share?source_application=<bundleID>` (default `AppInfo.bundleIdentifier`). Returns `false` when Instagram can't be opened — **the caller owns the fallback policy** (the two source apps fell back differently).
- `copySticker(_:)` — clipboard flow (PNG + 5-minute expiry) for "paste it into your own story"; pair with a confirmation toast/alert.
- `@available(iOSApplicationExtension, unavailable)` — uses `UIApplication.open`.
- Consuming-app Info.plist: `LSApplicationQueriesSchemes` += `instagram-stories` only if the app wants to *pre-check* availability; `share` works without it.

### PASPhotoLibrary — ✅ built
`save(_:) async throws` — `.addOnly` authorization request (`.limited` suffices for adds) then `creationRequestForAsset`. Typed errors: `PASPhotoLibraryError.accessDenied` / `.saveFailed(underlying:)`. **Consuming-app Info.plist must declare `NSPhotoLibraryAddUsageDescription`.**

### PASShareItems + PASActivitySheet — ✅ built
- `PASShareItems` — `Identifiable` items wrapper; `.sheet(item:)` presentation avoids the empty-first-presentation timing issue of `isPresented` + separate state.
- `PASActivitySheet` — `UIViewControllerRepresentable` over `UIActivityViewController` with optional `onComplete`; plus imperative `present(items:onComplete:)` (top-most-VC walk, iPad popover anchored center, extension-unavailable) for contexts already presenting a sheet of their own.

### Preview helpers — ✅ built
- `PASScaledCardPreview` — renders the card at canonical size and scales it to fit the container, so previews are pixel-faithful to `PASShareCard.render` at the same size. `clipsToCard: false` + checkerboard background for stickers.
- `PASTransparencyCheckerboard` — Canvas checkerboard (white 0.06/0.12 squares over half-black) signalling transparency.

## Notes

- Card designs, captions, CTA chrome (e.g. an Instagram-gradient button), and share-option carousels stay per-app.
- The "Saved to Photos" confirmation toast lives in PASKitLifecycle: `View.pasToast` + `PASToast`.

## Remaining

- [ ] Unit tests where practical (error mapping; preview scaling math).
- [ ] Stories background-gradient / content-URL pasteboard keys — add when the first app needs them.
