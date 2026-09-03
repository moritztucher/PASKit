//
//  WhatsNewSlots.swift
//  PASKitLifecycle
//
//  The values PASKit hands to a `WhatsNewView` branding slot. Each carries the
//  data the slot needs and, where the slot decorates rather than replaces, the
//  stock content to wrap — so an app supplies chrome without re-laying-out the
//  view.
//

import SwiftUI

/// Handed to ``WhatsNewView/header(_:)``. Replaces the stock header mark.
public struct WhatsNewHeaderConfiguration: Sendable {

    /// The SF Symbol the caller passed as `headerSymbol`, if any.
    public let symbol: String?

    /// The sheet's title, in case the header wants to render it itself.
    public let title: String
}

/// Handed to ``WhatsNewView/cardContainer(_:)``. Decorates the stock card row —
/// wrap ``content``, do not rebuild it.
public struct WhatsNewCardConfiguration {

    /// PASKit's stock card row: symbol tile, title, subtitle.
    public struct Content: View {
        let stock: AnyView
        public var body: some View { stock }
    }

    /// The card being rendered, for containers that vary by content.
    public let card: WhatsNewCard

    /// The stock row to wrap.
    public let content: Content
}

/// Handed to ``WhatsNewView/continueButton(_:)``. Replaces the stock CTA.
public struct WhatsNewActionConfiguration {

    /// The button title the caller passed as `continueButtonTitle`.
    public let title: String

    /// Invoke to dismiss — this is the caller's `onContinue`.
    public let action: () -> Void
}
