//
//  Animation+ReducedMotion.swift
//  PASKitCore
//
//  Reduce-Motion-aware animation. Token values and motion vocabulary stay
//  per-app; the accessibility mechanism lives here.
//

import SwiftUI

public extension Animation {
    /// `nil` when Reduce Motion is on, otherwise `self` — for call sites
    /// that already read `@Environment(\.accessibilityReduceMotion)`:
    ///
    /// ```swift
    /// withAnimation(.easeOut(duration: 0.25).respectingReducedMotion(reduceMotion)) { … }
    /// ```
    func respectingReducedMotion(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}

public extension View {
    /// `animation(_:value:)` that honors Reduce Motion by itself.
    ///
    /// ```swift
    /// CardView().pasAnimation(.spring, value: isExpanded)
    /// CardView().pasAnimation(.spring, reducedMotion: .easeInOut(duration: 0.2), value: isExpanded)
    /// ```
    ///
    /// - Parameters:
    ///   - animation: Used when Reduce Motion is off.
    ///   - reducedMotion: Substitute when Reduce Motion is on. Defaults to
    ///     `nil` (changes snap); pass a short ease for a gentler swap.
    ///   - value: The equatable value to monitor, as in `animation(_:value:)`.
    func pasAnimation<V: Equatable>(
        _ animation: Animation,
        reducedMotion: Animation? = nil,
        value: V
    ) -> some View {
        modifier(PASReducedMotionAnimation(animation: animation, reducedMotion: reducedMotion, value: value))
    }
}

private struct PASReducedMotionAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let reducedMotion: Animation?
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? reducedMotion : animation, value: value)
    }
}
