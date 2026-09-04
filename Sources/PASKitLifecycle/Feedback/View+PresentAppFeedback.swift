//
//  View+PresentAppFeedback.swift
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
    ///   - keys: `UserDefaults` keys backing the one-shot state. Defaults to
    ///     `.standard`. An app that already shipped its own keys **must**
    ///     pass them here, or every installed user sees the prompt replay.
    ///   - copy: Alert copy per stage. Defaults to `.standard` — the copy
    ///     PASKit has always shown. Pass app vocabulary or localised
    ///     strings to personalise it.
    @ViewBuilder
    func presentAppFeedback<Content: View>(
        initialCondition: @escaping () async -> Bool,
        askLaterCondition: @escaping () async -> Bool,
        keys: PASAppFeedbackKeys = .standard,
        copy: PASAppFeedbackCopy = .standard,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            AppFeedbackModifier(
                initialCondition: initialCondition,
                askLaterCondition: askLaterCondition,
                keys: keys,
                copy: copy,
                sheetContent: content
            )
        )
    }
}

private struct AppFeedbackModifier<SheetContent: View>: ViewModifier {
    let initialCondition: () async -> Bool
    let askLaterCondition: () async -> Bool
    let copy: PASAppFeedbackCopy
    @ViewBuilder let sheetContent: () -> SheetContent

    @AppStorage private var isCompleted: Bool
    @AppStorage private var isInitialPromptShown: Bool
    @State private var showAlert = false
    @State private var showSheet = false

    init(
        initialCondition: @escaping () async -> Bool,
        askLaterCondition: @escaping () async -> Bool,
        keys: PASAppFeedbackKeys,
        copy: PASAppFeedbackCopy,
        @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) {
        self.initialCondition = initialCondition
        self.askLaterCondition = askLaterCondition
        self.copy = copy
        self.sheetContent = sheetContent
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
                    isCompleted = true
                    showSheet = true
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
            .sheet(isPresented: $showSheet) {
                sheetContent()
            }
    }
}
