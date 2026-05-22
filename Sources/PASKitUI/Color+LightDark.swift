//
//  Color+LightDark.swift
//  PASKitUI
//
//  Appearance-resolving colour utilities.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension Color {

    /// Creates a colour that resolves to `light` in light appearance and `dark`
    /// in dark appearance. Bridges through `UIColor` on iOS and `NSColor` on
    /// macOS — no asset catalog required.
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

    /// Cross-platform tile / card background — mirrors iOS's
    /// `secondarySystemBackground` (#F2F2F7 light / #1C1C1E dark) on every
    /// platform so a card reads the same on iPhone, iPad, and Mac.
    static let tileBackground: Color = Color(
        light: Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255),
        dark: Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    )
}
