//
//  AppFeedbackHelper.swift
//  PASKitLifecycle
//
//  Two-stage give-us-feedback prompt. Same shape as `presentAppRating` — the
//  caller supplies trigger conditions as async closures, and accepting opens
//  the supplied sheet content (e.g. `FeedbackSheet`). The destination view is
//  injected so apps can present `FeedbackSheet` from PASKit or any custom
//  feedback view of their own.
//

import SwiftUI

public extension View {
    /// Attaches a two-stage feedback prompt. The first prompt offers
    /// *Yes*, *Ask Later*, or *Never Ask Me Again*. After *Ask Later*, the
    /// second prompt offers *Yes* or *Nope*. Accepting presents the supplied
    /// `content` as a sheet — typically a `FeedbackSheet`. One-shot — once
    /// resolved, the modifier stays silent for the life of the install.
    ///
    /// - Parameters:
    ///   - initialCondition: Evaluated on appear before the first prompt.
    ///     Return `true` to show the initial alert.
    ///   - askLaterCondition: Evaluated on appear after *Ask Later*. Return
    ///     `true` to show the second alert.
    ///   - content: The sheet to present on accept. Usually `FeedbackSheet(...)`.
    @ViewBuilder
    func presentAppFeedback<Content: View>(
        initialCondition: @escaping () async -> Bool,
        askLaterCondition: @escaping () async -> Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            AppFeedbackModifier(
                initialCondition: initialCondition,
                askLaterCondition: askLaterCondition,
                sheetContent: content
            )
        )
    }
}

private struct AppFeedbackModifier<SheetContent: View>: ViewModifier {
    let initialCondition: () async -> Bool
    let askLaterCondition: () async -> Bool
    @ViewBuilder let sheetContent: () -> SheetContent

    @AppStorage("paskit.appFeedback.isComplete") private var isCompleted = false
    @AppStorage("paskit.appFeedback.isInitialPromptShown") private var isInitialPromptShown = false
    @State private var showAlert = false
    @State private var showSheet = false

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
            .alert("Got a moment to share feedback?", isPresented: $showAlert) {
                Button(isInitialPromptShown ? "Yes!" : "Yes, Continue!") {
                    isCompleted = true
                    showSheet = true
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
            .sheet(isPresented: $showSheet) {
                sheetContent()
            }
    }
}
