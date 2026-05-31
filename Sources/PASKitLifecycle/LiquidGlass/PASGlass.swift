//
//  PASGlass.swift
//  PASKitLifecycle
//
//  Liquid Glass configuration. Chainable to mirror Apple's
//  `Glass.regular.tint(...)`. `tint` colours the glass material itself;
//  `foreground` colours the wrapped content (text / icons) via
//  `.foregroundStyle`.
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
