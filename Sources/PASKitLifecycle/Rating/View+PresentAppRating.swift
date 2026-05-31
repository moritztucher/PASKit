//
//  AppRatingHelper.swift
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
    @ViewBuilder
    func presentAppRating(
        initialCondition: @escaping () async -> Bool,
        askLaterCondition: @escaping () async -> Bool
    ) -> some View {
        modifier(
            AppRatingModifier(
                initialCondition: initialCondition,
                askLaterCondition: askLaterCondition
            )
        )
    }
}

private struct AppRatingModifier: ViewModifier {
    let initialCondition: () async -> Bool
    let askLaterCondition: () async -> Bool

    @Environment(\.requestReview) private var requestReview
    @AppStorage("paskit.appRating.isComplete") private var isCompleted = false
    @AppStorage("paskit.appRating.isInitialPromptShown") private var isInitialPromptShown = false
    @State private var showAlert = false

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
            .alert("Would you like to rate the app?", isPresented: $showAlert) {
                Button(isInitialPromptShown ? "Yes!" : "Yes, Continue!") {
                    requestReview()
                    isCompleted = true
                }
                .keyboardShortcut(.defaultAction)

                if isInitialPromptShown {
                    Button("Nope", role: .cancel) {
                        isCompleted = true
                    }
                } else {
                    Button("Ask Later", role: .cancel) {
                        isInitialPromptShown = true
                    }
                    Button("Never Ask Me Again", role: .destructive) {
                        isCompleted = true
                    }
                }
            }
    }
}
