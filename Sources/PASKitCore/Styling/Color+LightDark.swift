//
//  Color+LightDark.swift
//  PASKitCore
//
//  Appearance-resolving Color without an asset catalog. Apps build their
//  semantic color tokens on top; the values stay per-app.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension Color {
    /// A color that resolves to `light` in light appearance and `dark` in
    /// dark appearance — bridged through `UIColor` / `NSColor`, no asset
    /// catalog required.
    ///
    /// ```swift
    /// static let cardBackground = Color(
    ///     light: .white,
    ///     dark: Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    /// )
    /// ```
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}
