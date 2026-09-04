//
//  View+PresentAppRating.swift
//  PASKitLifecycle
//
//  Two-stage rate-the-app prompt over StoreKit. Caller supplies the trigger
//  conditions as async closures (e.g. "has the user completed N sessions").
//

import StoreKit
import SwiftUI

public extension View {
    /// Attaches a two-stage rate-the-app prompt. The first prompt offers
    /// *Yes*, *Ask Later*, or *Never Ask Me Again*. After *Ask Later*, the
    /// second prompt offers *Yes* or *Nope*. The interaction is one-shot —
    /// once resolved, the modifier stays silent for the life of the install.
    ///
    /// - Parameters:
    ///   - initialCondition: Evaluated on appear before the first prompt.
    ///     Return `true` to show the initial alert.
    ///   - askLaterCondition: Evaluated on appear after *Ask Later*. Return
    ///     `true` to show the second alert.
    ///   - keys: `UserDefaults` keys backing the one-shot state. Defaults to
    ///     `.standard`. An app that already shipped its own keys **must**
    ///     pass them here, or every installed user sees the prompt replay.
    ///   - copy: Alert copy per stage. Defaults to `.standard` — the copy
    ///     PASKit has always shown. Pass app vocabulary (e.g. the app name)
    ///     or localised strings to personalise it.
    @ViewBuilder
    func presentAppRating(
        initialCondition: @escaping () async -> Bool,
        askLaterCondition: @escaping () async -> Bool,
        keys: PASAppRatingKeys = .standard,
        copy: PASAppRatingCopy = .standard
    ) -> some View {
        modifier(
            AppRatingModifier(
                initialCondition: initialCondition,
                askLaterCondition: askLaterCondition,
                keys: keys,
                copy: copy
            )
        )
    }
}

private struct AppRatingModifier: ViewModifier {
    let initialCondition: () async -> Bool
    let askLaterCondition: () async -> Bool
    let copy: PASAppRatingCopy

    @Environment(\.requestReview) private var requestReview
    @AppStorage private var isCompleted: Bool
    @AppStorage private var isInitialPromptShown: Bool
    @State private var showAlert = false

    init(
        initialCondition: @escaping () async -> Bool,
        askLaterCondition: @escaping () async -> Bool,
        keys: PASAppRatingKeys,
        copy: PASAppRatingCopy
    ) {
        self.initialCondition = initialCondition
        self.askLaterCondition = askLaterCondition
        self.copy = copy
        _isCompleted = AppStorage(wrappedValue: false, keys.isCompleted)
        _isInitialPromptShown = AppStorage(wrappedValue: false, keys.isInitialPromptShown)
    }

    func body(content: Content) -> some View {
        content
            .task {
                guard !isCompleted else { return }
                let condition = isInitialPromptShown
                    ? await askLaterCondition()
                    : await initialCondition()
                if condition {
                    showAlert = true
                }
            }
            .alert(
                isInitialPromptShown ? copy.followUpTitle : copy.initialTitle,
                isPresented: $showAlert
            ) {
                Button(isInitialPromptShown ? copy.followUpAccept : copy.initialAccept) {
                    requestReview()
                    isCompleted = true
                }
                .keyboardShortcut(.defaultAction)

                if isInitialPromptShown {
                    Button(copy.followUpDecline, role: .cancel) {
                        isCompleted = true
                    }
                } else {
                    Button(copy.askLater, role: .cancel) {
                        isInitialPromptShown = true
                    }
                    Button(copy.neverAsk, role: .destructive) {
                        isCompleted = true
                    }
                }
            } message: {
                if let message = isInitialPromptShown ? copy.followUpMessage : copy.initialMessage {
                    Text(message)
                }
            }
    }
}
