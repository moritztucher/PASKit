//
//  PASInstagramStories.swift
//  PASKitSharing
//
//  Instagram Stories hand-off: image(s) onto the pasteboard under
//  Instagram's sharedSticker keys with a 5-minute expiry, then the
//  instagram-stories:// deep link. The caller owns the fallback policy
//  when Instagram is not installed.
//

#if canImport(UIKit)
import PASKitCore
import UIKit
import UniformTypeIdentifiers

/// Shares rendered cards into Instagram Stories.
///
/// ```swift
/// if await PASInstagramStories.share(background: storyImage) == false {
///     // Instagram unavailable — fall back, e.g. to PASActivitySheet.
/// }
/// ```
///
/// - Important: App-only (uses `UIApplication.open`). To *check*
///   availability before showing an Instagram button, an app must list
///   `instagram-stories` under `LSApplicationQueriesSchemes`; `share`
///   itself works without it and simply returns `false` when the open
///   fails.
@available(iOSApplicationExtension, unavailable)
@MainActor
public enum PASInstagramStories {
    private static let expiry: TimeInterval = 300

    /// Opens Instagram's story composer with the given images.
    ///
    /// - Parameters:
    ///   - background: Full-bleed story background (typically 1080×1920).
    ///   - sticker: Transparent overlay the user places on their own
    ///     content. Pass either or both.
    ///   - sourceApplication: Defaults to the app's bundle identifier.
    /// - Returns: `false` when no image was supplied or Instagram could
    ///   not be opened — the caller decides the fallback.
    @discardableResult
    public static func share(
        background: UIImage? = nil,
        sticker: UIImage? = nil,
        sourceApplication: String? = nil
    ) async -> Bool {
        var item: [String: Any] = [:]
        if let data = background?.pngData() {
            item["com.instagram.sharedSticker.backgroundImage"] = data
        }
        if let data = sticker?.pngData() {
            item["com.instagram.sharedSticker.stickerImage"] = data
        }
        guard !item.isEmpty else { return false }

        let source = sourceApplication ?? AppInfo.bundleIdentifier
        guard let url = URL(string: "instagram-stories://share?source_application=\(source)") else {
            return false
        }

        UIPasteboard.general.setItems(
            [item],
            options: [.expirationDate: Date().addingTimeInterval(expiry)]
        )

        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Copies a sticker image to the clipboard (5-minute expiry) for the
    /// "paste it into your own story" flow. Pair with a confirmation
    /// alert/toast so the user knows what happened.
    public static func copySticker(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        UIPasteboard.general.setItems(
            [[UTType.png.identifier: data]],
            options: [.expirationDate: Date().addingTimeInterval(expiry)]
        )
    }
}
#endif
