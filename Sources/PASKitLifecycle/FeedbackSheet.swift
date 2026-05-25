//
//  FeedbackSheet.swift
//  PASKitLifecycle
//
//  In-app feedback form. PASKit owns the form UI; the app owns the transport
//  via the `onSubmit` closure (email, HTTP, webhook, etc.). Adaptive layout —
//  two-pane on regular width / macOS, stacked on compact.
//

import SwiftUI

public struct FeedbackPayload: Sendable, Equatable {
    public let category: String
    public let name: String
    public let email: String
    public let message: String

    public init(category: String, name: String, email: String, message: String) {
        self.category = category
        self.name = name
        self.email = email
        self.message = message
    }
}

public struct FeedbackSheet: View {

    public let title: String
    public let subtitle: String
    public let heroSymbol: String
    public let categories: [String]
    public let onSubmit: @Sendable (FeedbackPayload) async throws -> Void

    public init(
        title: String = "We'd Love Your Feedback",
        subtitle: String = "Help us improve by sharing your thoughts, reporting bugs, or requesting new features.",
        heroSymbol: String = "lifepreserver",
        categories: [String] = ["General", "Feature Request", "Bug Report"],
        onSubmit: @escaping @Sendable (FeedbackPayload) async throws -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.heroSymbol = heroSymbol
        self.categories = categories
        self.onSubmit = onSubmit
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
            Image(systemName: heroSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
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

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Send")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
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
