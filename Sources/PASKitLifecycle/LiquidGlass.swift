//
//  LiquidGlass.swift
//  PASKitLifecycle
//
//  iOS 26 Liquid Glass with a pre-26 fallback. PASKit ships `paskitGlass(_:in:)`
//  for surfaces (cards, sheet content, custom backgrounds) and
//  `paskitGlassButtonStyle(_:)` for buttons. Apple's nav bar / tab bar /
//  toolbar adopt Liquid Glass automatically on iOS 26 and `.toolbarBackground`
//  / `.toolbarForegroundStyle` are cross-version — PASKit deliberately does
//  not wrap those.
//

import SwiftUI

/// Glass configuration. Chainable to mirror Apple's `Glass.regular.tint(...)`.
/// `tint` colours the glass material itself; `foreground` colours the wrapped
/// content (text / icons) via `.foregroundStyle`.
public struct PASGlass: Sendable {

    let backgroundTint: Color?
    let foregroundTint: Color?

    private init(backgroundTint: Color?, foregroundTint: Color?) {
        self.backgroundTint = backgroundTint
        self.foregroundTint = foregroundTint
    }

    public static let regular = PASGlass(backgroundTint: nil, foregroundTint: nil)

    /// Tint the glass background material.
    public func tint(_ color: Color) -> PASGlass {
        PASGlass(backgroundTint: color, foregroundTint: foregroundTint)
    }

    /// Tint the wrapped content (text / icons).
    public func foreground(_ color: Color) -> PASGlass {
        PASGlass(backgroundTint: backgroundTint, foregroundTint: color)
    }
}

/// Variants for `paskitGlassButtonStyle`. Maps to Apple's `.glass` button
/// style on iOS 26+; pre-26 falls back to `.borderedProminent` / `.bordered`.
public enum PASGlassButtonVariant: Sendable {
    case regular
    case clear
}

public extension View {

    /// Applies Liquid Glass on iOS/macOS 26+; falls back to `.regularMaterial`
    /// (with optional tint overlay) on earlier OSes. For surfaces — cards,
    /// sheet content, custom backgrounds. Do not apply to nav bars or
    /// toolbars; those manage their own glass on iOS 26.
    func paskitGlass(_ glass: PASGlass = .regular, in shape: some Shape = .rect) -> some View {
        modifier(PASKitGlassModifier(glass: glass, shape: shape))
    }

    /// Applies Apple's Liquid Glass button style on iOS/macOS 26+; falls back
    /// to `.borderedProminent` (regular) / `.bordered` (clear) on earlier OSes.
    @ViewBuilder
    func paskitGlassButtonStyle(_ variant: PASGlassButtonVariant = .regular) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            switch variant {
            case .regular: buttonStyle(.glass)
            case .clear: buttonStyle(.glass(.clear))
            }
        } else {
            switch variant {
            case .regular: buttonStyle(.borderedProminent)
            case .clear: buttonStyle(.bordered)
            }
        }
    }
}

private struct PASKitGlassModifier<S: Shape>: ViewModifier {

    let glass: PASGlass
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            tinted(content).glassEffect(appleGlass, in: shape)
        } else {
            tinted(content).background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let bg = glass.backgroundTint {
                        shape.fill(bg.opacity(0.15))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tinted(_ content: Content) -> some View {
        if let fg = glass.foregroundTint {
            content.foregroundStyle(fg)
        } else {
            content
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var appleGlass: Glass {
        var g = Glass.regular
        if let bg = glass.backgroundTint {
            g = g.tint(bg)
        }
        return g
    }
}
