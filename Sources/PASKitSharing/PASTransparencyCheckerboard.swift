//
//  PASTransparencyCheckerboard.swift
//  PASKitSharing
//
//  Checkerboard backdrop that communicates "this sticker is transparent —
//  it will sit on your own content". Place behind a sticker preview.
//

import SwiftUI

/// A subtle checkerboard for transparent-sticker previews.
///
/// ```swift
/// PASScaledCardPreview(cardSize: ..., containerSize: ..., clipsToCard: false) {
///     StickerCard(stats: stats)
/// }
/// .background(PASTransparencyCheckerboard())
/// .clipShape(.rect(cornerRadius: 24))
/// ```
public struct PASTransparencyCheckerboard: View {
    private let square: CGFloat

    /// - Parameter square: Checker square edge in points. Defaults to 14.
    public init(square: CGFloat = 14) {
        self.square = square
    }

    public var body: some View {
        Canvas { context, size in
            let cols = Int((size.width / square).rounded(.up))
            let rows = Int((size.height / square).rounded(.up))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isDark = (row + col).isMultiple(of: 2)
                    let color = Color.white.opacity(isDark ? 0.06 : 0.12)
                    let rect = CGRect(
                        x: CGFloat(col) * square,
                        y: CGFloat(row) * square,
                        width: square,
                        height: square
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .background(Color.black.opacity(0.5))
    }
}
