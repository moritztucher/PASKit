//
//  PASShareCard.swift
//  PASKitSharing
//
//  SwiftUI → UIImage rendering for share cards. The app owns the card
//  design; PASKit owns the ImageRenderer plumbing (canonical size, 3x
//  scale, transparency for stickers).
//

#if canImport(UIKit)
import SwiftUI
import UIKit

/// Renders a SwiftUI card view into a `UIImage` for sharing.
///
/// ```swift
/// let story   = PASShareCard.render(StoryCard(stats: stats),
///                                   size: CGSize(width: 1080, height: 1920))
/// let sticker = PASShareCard.render(StickerCard(stats: stats),
///                                   size: StickerCard.canonicalSize,
///                                   opaque: false)
/// ```
///
/// - Important: `ImageRenderer` resolves no window environment. Use
///   explicit colors in card views — `Color.accentColor` / `.tint` render
///   as defaults, and dynamic (light/dark) colors resolve via the
///   `colorScheme` parameter, not the device appearance.
@MainActor
public enum PASShareCard {
    /// - Parameters:
    ///   - content: The card view, designed at `size` points.
    ///   - size: Canonical card size in points (e.g. 1080×1920 for an
    ///     Instagram story).
    ///   - scale: Pixel scale. Defaults to 3.
    ///   - opaque: Pass `false` for transparent stickers.
    ///   - colorScheme: Resolves the card's dynamic colors; `nil` leaves
    ///     SwiftUI's default (light).
    public static func render(
        _ content: some View,
        size: CGSize,
        scale: CGFloat = 3,
        opaque: Bool = true,
        colorScheme: ColorScheme? = nil
    ) -> UIImage? {
        var card = AnyView(content.frame(width: size.width, height: size.height))
        if let colorScheme {
            card = AnyView(card.environment(\.colorScheme, colorScheme))
        }
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        renderer.isOpaque = opaque
        return renderer.uiImage
    }
}
#endif
