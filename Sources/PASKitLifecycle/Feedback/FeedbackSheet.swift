//
//  FeedbackSheet.swift
//  PASKitLifecycle
//
//  In-app feedback form. PASKit owns the form UI; the app owns the transport
//  via the `onSubmit` closure (email, HTTP, webhook, etc.). Adaptive layout —
//  two-pane on regular width / macOS, stacked on compact.
//

import SwiftUI

public struct FeedbackSheet: View {

    public let title: String
    public let subtitle: String
    public let heroSymbol: String?
    public let categories: [String]
    public let showsCloseButton: Bool
    public let onSubmit: @Sendable (FeedbackPayload) async throws -> Void

    /// - Parameters:
    ///   - heroSymbol: SF Symbol above the title. `nil` hides the symbol
    ///     (title and subtitle remain).
    ///   - initialName: Prefill for the name field — pass the known user
    ///     name so returning users don't retype it.
    ///   - initialEmail: Prefill for the email field — pass the account
    ///     email when the user is signed in.
    ///   - showsCloseButton: Adds an ⓧ dismiss button top-trailing and
    ///     drops the redundant Cancel button on compact layouts. Off by
    ///     default (macOS windows have their own close affordance).
    public init(
        title: String = "We'd Love Your Feedback",
        subtitle: String = "Help us improve by sharing your thoughts, reporting bugs, or requesting new features.",
        heroSymbol: String? = "lifepreserver",
        categories: [String] = ["General", "Feature Request", "Bug Report"],
        initialName: String = "",
        initialEmail: String = "",
        showsCloseButton: Bool = false,
        onSubmit: @escaping @Sendable (FeedbackPayload) async throws -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.heroSymbol = heroSymbol
        self.categories = categories
        self.showsCloseButton = showsCloseButton
        self.onSubmit = onSubmit
        _name = State(initialValue: initialName)
        _email = State(initialValue: initialEmail)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String = ""
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var submitError: String?

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }
#else
    private var isWide: Bool { true }
#endif

    public var body: some View {
        Group {
            if isWide {
                HStack(spacing: 0) {
                    hero
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                    Divider()
                    form
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        hero
                        form
                    }
                    .padding()
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                closeButton
            }
        }
        .onAppear {
            if selectedCategory.isEmpty {
                selectedCategory = categories.first ?? ""
            }
        }
        .alert(
            "Couldn't send feedback",
            isPresented: Binding(
                get: { submitError != nil },
                set: { if !$0 { submitError = nil } }
            ),
            presenting: submitError
        ) { _ in
            Button("OK", role: .cancel) { submitError = nil }
        } message: { error in
            Text(error)
        }
    }

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: 16) {
            if let heroSymbol {
                Image(systemName: heroSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .padding()
    }

    @ViewBuilder
    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            if categories.count > 1 {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            labeledField("Name") {
                TextField("", text: $name)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textContentType(.name)
                #endif
            }

            labeledField("Email (Optional)") {
                TextField("", text: $email)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                #endif
            }

            labeledField("What feedback do you have?") {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.thinMaterial, in: .rect(cornerRadius: 8))
                    if message.isEmpty {
                        Text("Please describe your feedback…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            }

            if isWide {
                HStack {
                    Button("Cancel", role: .cancel) { dismiss() }
                    Spacer()
                    submitButton
                }
            } else {
                VStack(spacing: 12) {
                    submitButton
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    if !showsCloseButton {
                        Button("Cancel", role: .cancel) { dismiss() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Send")
                }
            }
            .frame(maxWidth: isWide ? nil : .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSubmit)
        .keyboardShortcut(.defaultAction)
    }

    private var canSubmit: Bool {
        !isSubmitting &&
            !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func labeledField<Field: View>(
        _ label: String,
        @ViewBuilder field: () -> Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            field()
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let payload = FeedbackPayload(
            category: selectedCategory,
            name: name,
            email: email,
            message: message
        )
        do {
            try await onSubmit(payload)
            dismiss()
        } catch {
            submitError = error.localizedDescription
        }
    }
}
