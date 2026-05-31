//
//  WhatsNewCardResultBuilder.swift
//  PASKitLifecycle
//
//  Declarative card-list builder for `WhatsNewView`.
//

import Foundation

/// Declarative card builder for `WhatsNewView`.
@resultBuilder
public struct WhatsNewCardResultBuilder {
    public static func buildBlock(_ components: WhatsNewCard...) -> [WhatsNewCard] {
        Array(components)
    }
}
