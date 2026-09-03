//
//  WhatsNewHighlights.swift
//  PASKitLifecycle
//
//  The presentation value for the What's New sheet.
//

import Foundation

/// One presentation's worth of ``WhatsNewCard``s, so a caller can drive the sheet
/// with `.sheet(item:)` instead of `.sheet(isPresented:)` plus a separate
/// `[WhatsNewCard]` state.
///
/// That split shipped an empty sheet in the app this was extracted from: SwiftUI
/// captured the cards array for the sheet's content before the same-transaction
/// write that filled it landed, so the sheet presented with `[]` and rendered only
/// its header and Continue button. Carrying the cards *as* the presentation value
/// makes that ordering unrepresentable — which is why this type exists at all.
public struct WhatsNewHighlights: Identifiable, Sendable {

    public let id = UUID()
    public let cards: [WhatsNewCard]

    public init(cards: [WhatsNewCard]) {
        self.cards = cards
    }
}
