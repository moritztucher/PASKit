//
//  View+PASOnboardingTransition.swift
//  PASKitLifecycle
//
//  The step-change choreography every onboarding container hand-rolls:
//  identity keyed to the current step, asymmetric slide whose edges flip
//  with the navigation direction, and the matching animation.
//

import SwiftUI

public extension View {
    /// Applies onboarding step-transition choreography to the step content.
    ///
    /// ```swift
    /// stepContent(for: flow.current)
    ///     .pasOnboardingTransition(step: flow.current, direction: flow.direction)
    /// ```
    ///
    /// Pass the app's motion token as `animation` to match its design
    /// language; the default is a 0.35s ease-in-out.
    func pasOnboardingTransition(
        step: some Hashable,
        direction: PASOnboardingDirection,
        animation: Animation = .easeInOut(duration: 0.35)
    ) -> some View {
        self
            .transition(.asymmetric(
                insertion: .move(edge: direction == .forward ? .trailing : .leading)
                    .combined(with: .opacity),
                removal: .move(edge: direction == .forward ? .leading : .trailing)
                    .combined(with: .opacity)
            ))
            .animation(animation, value: step)
            .id(step)
    }
}
