//
//  PASPressableButtonStyle.swift
//  PASKitCore
//
//  Press-scale button interaction — the brand-free mechanism under apps'
//  styled buttons (scale on press + spring, optional haptic on press-down).
//  Visual fills/fonts/radii stay per-app; this is the touch feedback.
//

import SwiftUI

/// A `ButtonStyle` that scales the label down on press and (optionally)
/// fires a haptic on the press-down edge.
///
/// ```swift
/// Button("Start") { … }.buttonStyle(.pasPressable())
/// Button("Log") { … }.buttonStyle(.pasPressable(haptic: .selection,
///                                               isHapticEnabled: settings.hapticsEnabled))
/// ```
public struct PASPressableButtonStyle: ButtonStyle {
    private let pressedScale: CGFloat
    private let haptic: PASHaptic?
    private let isHapticEnabled: Bool

    public init(
        pressedScale: CGFloat = 0.96,
        haptic: PASHaptic? = nil,
        isHapticEnabled: Bool = true
    ) {
        self.pressedScale = pressedScale
        self.haptic = haptic
        self.isHapticEnabled = isHapticEnabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                guard let haptic, isPressed, !wasPressed else { return }
                Haptics.play(haptic, isEnabled: isHapticEnabled)
            }
    }
}

public extension ButtonStyle where Self == PASPressableButtonStyle {
    /// `.buttonStyle(.pasPressable())` — scale + spring, optional press
    /// haptic.
    static func pasPressable(
        pressedScale: CGFloat = 0.96,
        haptic: PASHaptic? = nil,
        isHapticEnabled: Bool = true
    ) -> PASPressableButtonStyle {
        PASPressableButtonStyle(
            pressedScale: pressedScale,
            haptic: haptic,
            isHapticEnabled: isHapticEnabled
        )
    }
}
