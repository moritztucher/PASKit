//
//  Font+PASScaled.swift
//  PASKitCore
//
//  System font at a custom point size that still tracks Dynamic Type.
//  `Font.system(size:)` is fixed; sizes with no matching text style scale
//  via UIFontMetrics anchored to the nearest style. Point sizes are
//  unchanged at the default (Large) text-size setting.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public extension Font {
    /// A Dynamic-Type-scaling system font at a custom point size.
    ///
    /// ```swift
    /// Text("Streak").font(.pasScaled(28, relativeTo: .title, weight: .heavy))
    /// Text("042").font(.pasScaled(60, relativeTo: .largeTitle, design: .monospaced))
    /// ```
    ///
    /// On macOS (no `UIFontMetrics`) this returns a fixed-size system font.
    static func pasScaled(
        _ size: CGFloat,
        relativeTo style: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        #if canImport(UIKit)
        var uiFont = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        if let uiDesign = uiDesign(design),
           let descriptor = uiFont.fontDescriptor.withDesign(uiDesign) {
            uiFont = UIFont(descriptor: descriptor, size: size)
        }
        return Font(UIFontMetrics(forTextStyle: uiTextStyle(style)).scaledFont(for: uiFont))
        #else
        return .system(size: size, weight: weight, design: design)
        #endif
    }
}

#if canImport(UIKit)
private func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .ultraLight: .ultraLight
    case .thin: .thin
    case .light: .light
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    case .heavy: .heavy
    case .black: .black
    default: .regular
    }
}

private func uiDesign(_ design: Font.Design) -> UIFontDescriptor.SystemDesign? {
    switch design {
    case .default: nil
    case .monospaced: .monospaced
    case .rounded: .rounded
    case .serif: .serif
    @unknown default: nil
    }
}

private func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
    switch style {
    case .largeTitle: .largeTitle
    case .title: .title1
    case .title2: .title2
    case .title3: .title3
    case .headline: .headline
    case .subheadline: .subheadline
    case .body: .body
    case .callout: .callout
    case .footnote: .footnote
    case .caption: .caption1
    case .caption2: .caption2
    default: .body
    }
}
#endif
