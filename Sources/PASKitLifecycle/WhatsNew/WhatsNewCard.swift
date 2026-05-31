//
//  WhatsNewCard.swift
//  PASKitLifecycle
//
//  A single feature card in a `WhatsNewView`. `symbol` is an SF Symbol name.
//

import Foundation

/// One feature card in a `WhatsNewView`. `symbol` is an SF Symbol name.
public struct WhatsNewCard: Identifiable, Sendable {
    public var id = UUID().uuidString
    public let symbol: String
    public let title: String
    public let subtitle: String

    public init(symbol: String, title: String, subtitle: String) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
    }
}
