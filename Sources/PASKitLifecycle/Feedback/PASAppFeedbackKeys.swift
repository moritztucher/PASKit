//
//  PASAppFeedbackKeys.swift
//  PASKitLifecycle
//
//  UserDefaults keys behind presentAppFeedback — installed-user state, so an
//  app that already shipped a feedback prompt must pass the keys it shipped
//  with.
//

import Foundation

/// `UserDefaults` keys behind `presentAppFeedback`. Installed-user state: an
/// app that already shipped a feedback prompt must pass the keys it shipped
/// with, or every user who resolved the prompt sees it again. New apps take
/// `.standard` and never change it.
public struct PASAppFeedbackKeys: Equatable, Sendable {
    /// `Bool` — the interaction is resolved (accepted, declined, or never-ask).
    public var isCompleted: String
    /// `Bool` — the first prompt was answered "Ask Later".
    public var isInitialPromptShown: String

    public init(isCompleted: String, isInitialPromptShown: String) {
        self.isCompleted = isCompleted
        self.isInitialPromptShown = isInitialPromptShown
    }

    /// The keys PASKit has used since the modifier shipped.
    public static let standard = PASAppFeedbackKeys(
        isCompleted: "paskit.appFeedback.isComplete",
        isInitialPromptShown: "paskit.appFeedback.isInitialPromptShown"
    )
}
