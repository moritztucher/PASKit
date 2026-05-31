//
//  View+HapticOnTap.swift
//  PASKitCore
//
//  SwiftUI sugar — fire a haptic on tap, then run the action. Avoids wiring
//  every tappable row through `Haptics.play` by hand.
//

import SwiftUI

public extension View {
    /// Plays a haptic on tap, then runs `action`. Use for buttons and
    /// tappable rows that should feel tactile without wiring every
    /// callsite through `Haptics.play` manually.
    ///
    /// - Parameters:
    ///   - haptic: Primitive to play. Default `.light`.
    ///   - isEnabled: Call-site gate. Default `true`.
    ///   - action: The tap action.
    func hapticOnTap(
        _ haptic: PASHaptic = .light,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                Haptics.play(haptic, isEnabled: isEnabled)
                action()
            }
        )
    }
}
