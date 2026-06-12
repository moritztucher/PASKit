//
//  View+PaskitConcentricClip.swift
//  PASKitLifecycle
//
//  iOS 26 ConcentricRectangle with a pre-26 fallback — sibling of the
//  paskitGlass shims.
//

import SwiftUI

public extension View {
    /// Clips the view to a shape concentric with its container.
    ///
    /// - On iOS/macOS 26+: uses `ConcentricRectangle()`, which auto-derives
    ///   its corner radius from the nearest ancestor's `.containerShape(...)`
    ///   and the inset between the two — so cover images, badges, etc.
    ///   always sit visually concentric with their card no matter how the
    ///   inset or container radius changes.
    /// - Pre-26: falls back to a manual `RoundedRectangle` with the supplied
    ///   `fallbackRadius` (typically `containerRadius − inset`).
    ///
    /// ```swift
    /// CoverImage().paskitConcentricClip(fallbackRadius: 12)
    /// ```
    func paskitConcentricClip(fallbackRadius: CGFloat) -> some View {
        modifier(PASConcentricClip(fallbackRadius: fallbackRadius))
    }
}

private struct PASConcentricClip: ViewModifier {
    let fallbackRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.clipShape(ConcentricRectangle())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: fallbackRadius, style: .continuous))
        }
    }
}
