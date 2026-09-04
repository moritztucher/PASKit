//
//  PASAppRatingCopy.swift
//  PASKitLifecycle
//
//  Alert copy for presentAppRating — injectable so apps can localise or
//  personalise it without PASKit growing a string catalog.
//

import Foundation

/// Alert copy for `presentAppRating`, per stage. Strings are shown verbatim;
/// build them with `String(localized:bundle:)` and app vocabulary
/// (`"Enjoying \(AppInfo.displayName)?"`) at the call site.
public struct PASAppRatingCopy: Equatable, Sendable {
    // Stage 1 — Yes / Ask Later / Never
    public var initialTitle: String
    public var initialMessage: String?
    public var initialAccept: String
    public var askLater: String
    public var neverAsk: String
    // Stage 2 (after Ask Later) — Yes / Nope
    public var followUpTitle: String
    public var followUpMessage: String?
    public var followUpAccept: String
    public var followUpDecline: String

    public init(
        initialTitle: String = "Would you like to rate the app?",
        initialMessage: String? = nil,
        initialAccept: String = "Yes, Continue!",
        askLater: String = "Ask Later",
        neverAsk: String = "Never Ask Me Again",
        followUpTitle: String = "Would you like to rate the app?",
        followUpMessage: String? = nil,
        followUpAccept: String = "Yes!",
        followUpDecline: String = "Nope"
    ) {
        self.initialTitle = initialTitle
        self.initialMessage = initialMessage
        self.initialAccept = initialAccept
        self.askLater = askLater
        self.neverAsk = neverAsk
        self.followUpTitle = followUpTitle
        self.followUpMessage = followUpMessage
        self.followUpAccept = followUpAccept
        self.followUpDecline = followUpDecline
    }

    /// The copy PASKit has shipped since v0.1 — unchanged defaults.
    public static let standard = PASAppRatingCopy()
}
