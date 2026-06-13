//
//  PASDevelopmentMenu.swift
//  PASKitLifecycle
//
//  Container chrome for an app's dev menu: NavigationStack + Form + Done.
//  The sections are the app's vocabulary — toggles, seed/reset buttons,
//  mock-screen links — passed in as plain Form content.
//

import SwiftUI

/// The dev-menu container presented by `pasDevelopmentOverlay`.
///
/// ```swift
/// PASDevelopmentMenu {
///     Section("Runtime state") {
///         Toggle("Premium unlocked", isOn: $state.isPremium)
///     }
///     Section("Persisted state") {
///         Button("Reset to fresh install", role: .destructive) { state.resetAll() }
///     }
/// }
/// ```
public struct PASDevelopmentMenu<Content: View>: View {
    private let title: String
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    public init(title: String = "Development", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        NavigationStack {
            Form {
                content
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
