//
//  Theme.swift
//  PASKitUI
//
//  Design tokens — spacing, corner radius, screen-edge padding.
//

import SwiftUI

public enum Theme {

    /// Spacing scale, in points.
    public enum Spacing {
        public static let extraSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let extraLarge: CGFloat = 32
    }

    /// Corner-radius scale.
    public enum CornerRadius {
        public static let card: CGFloat = 16
    }

    /// Per-platform screen-edge padding.
    public enum ScreenEdge {
        public static let iOS: CGFloat = 16
        public static let macOS: CGFloat = 20

        public static var platform: CGFloat {
            #if os(macOS)
            macOS
            #else
            iOS
            #endif
        }
    }
}
