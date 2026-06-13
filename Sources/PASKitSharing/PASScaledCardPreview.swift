//
//  PASScaledCardPreview.swift
//  PASKitSharing
//
//  Shows a share card at its canonical design size, scaled to fit a
//  preview container — so the preview is pixel-faithful to what
//  PASShareCard.render produces at the same size.
//

import SwiftUI

/// A share-card preview scaled from canonical size into a container.
///
/// ```swift
/// GeometryReader { geo in
///     PASScaledCardPreview(cardSize: CGSize(width: 1080, height: 1920),
///                          containerSize: geo.size) {
///         StoryCard(stats: stats)
///     }
/// }
/// ```
public struct PASScaledCardPreview<Card: View>: View {
    private let cardSize: CGSize
    private let containerSize: CGSize
    private let clipsToCard: Bool
    private let cornerRadius: CGFloat
    private let card: Card

    /// - Parameters:
    ///   - cardSize: The canonical design size (pass the same size to
    ///     `PASShareCard.render`).
    ///   - containerSize: Available preview space (e.g. from a
    ///     `GeometryReader`).
    ///   - clipsToCard: Rounds the preview to `cornerRadius`. Pass `false`
    ///     for transparent stickers shown over `PASTransparencyCheckerboard`.
    ///   - cornerRadius: Preview clip radius. Defaults to 24.
    public init(
        cardSize: CGSize,
        containerSize: CGSize,
        clipsToCard: Bool = true,
        cornerRadius: CGFloat = 24,
        @ViewBuilder card: () -> Card
    ) {
        self.cardSize = cardSize
        self.containerSize = containerSize
        self.clipsToCard = clipsToCard
        self.cornerRadius = cornerRadius
        self.card = card()
    }

    public var body: some View {
        let scale = min(
            containerSize.width / max(cardSize.width, 1),
            containerSize.height / max(cardSize.height, 1)
        )
        let displaySize = CGSize(width: cardSize.width * scale, height: cardSize.height * scale)

        VStack {
            Spacer(minLength: 0)
            card
                .frame(width: cardSize.width, height: cardSize.height)
                .scaleEffect(scale, anchor: .center)
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(clipsToCard
                    ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
                    : AnyShape(Rectangle()))
            Spacer(minLength: 0)
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
}
