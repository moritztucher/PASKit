//
//  ChangelogView.swift
//  PASKitLifecycle
//
//  The retrospective multi-release changelog, for a Settings sub-screen. Distinct
//  from `WhatsNewView`, which is the one-shot card sheet shown once after an
//  update — both read the same `[ReleaseNote]`. Apps supply the releases (newest
//  first); layout, sectioning and kind icons are PASKit's, with one slot for the
//  app's own card surface.
//

import SwiftUI

/// A scrolling changelog. One block per release, newest first, in the order
/// supplied — PASKit does not sort.
///
/// ```swift
/// NavigationLink("What's New") {
///     ChangelogView(notes: ReleaseNotes.all)
///         .entryContainer { config in BrandCard { config.content } }
/// }
/// ```
///
/// Accent colour comes from `.tint`; the app owns the background, applied at the
/// call site with `.background { }`.
public struct ChangelogView: View {

    // MARK: - Content

    private let notes: [ReleaseNote]
    private let title: String
    private let latestBadgeTitle: String?

    // MARK: - Branding Slot

    private var entrySlot: ((ChangelogEntryConfiguration) -> AnyView)?

    // MARK: - Initialization

    /// - Parameters:
    ///   - notes: The releases, newest build first.
    ///   - title: Navigation title. Already localized.
    ///   - latestBadgeTitle: Badge shown beside the first release. `nil` hides it.
    public init(
        notes: [ReleaseNote],
        title: String = "What's New",
        latestBadgeTitle: String? = "Latest"
    ) {
        self.notes = notes
        self.title = title
        self.latestBadgeTitle = latestBadgeTitle
    }

    // MARK: - Slot

    /// Wraps each stock release block in the app's own card surface. Wrap
    /// `configuration.content`; do not rebuild it.
    public func entryContainer<Content: View>(
        @ViewBuilder _ builder: @escaping (ChangelogEntryConfiguration) -> Content
    ) -> ChangelogView {
        var copy = self
        copy.entrySlot = { AnyView(builder($0)) }
        return copy
    }

    // MARK: - Body

    public var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 16) {
                ForEach(notes) { note in
                    entry(for: note)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Entry

    @ViewBuilder
    private func entry(for note: ReleaseNote) -> some View {
        let isLatest = note == notes.first
        let configuration = ChangelogEntryConfiguration(
            note: note,
            isLatest: isLatest,
            content: .init(stock: AnyView(stockEntry(note, isLatest: isLatest)))
        )
        if let entrySlot {
            entrySlot(configuration)
        } else {
            configuration.content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: .rect(cornerRadius: 16, style: .continuous))
        }
    }

    private func stockEntry(_ note: ReleaseNote, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(for: note, isLatest: isLatest)
            ForEach(Array(note.items.enumerated()), id: \.offset) { _, item in
                row(for: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header(for note: ReleaseNote, isLatest: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(note.displayVersion)
                .font(.headline)

            if isLatest, let latestBadgeTitle {
                Text(latestBadgeTitle)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint, in: .capsule)
                    .foregroundStyle(.background)
            }

            Spacer(minLength: 8)

            if let date = note.date {
                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(for item: ChangelogItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol(for: item))
                .font(.caption)
                .foregroundStyle(.tint)
                .frame(width: 18, alignment: .center)
                .padding(.top, 3)
                .accessibilityLabel(accessibilityLabel(for: item))
            Text(item.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func symbol(for item: ChangelogItem) -> String {
        switch item {
        case .added: return "plus.circle.fill"
        case .changed: return "arrow.triangle.2.circlepath"
        case .fixed: return "wrench.adjustable.fill"
        case .note: return "checkmark.circle.fill"
        }
    }

    private func accessibilityLabel(for item: ChangelogItem) -> String {
        switch item {
        case .added: return "Added"
        case .changed: return "Changed"
        case .fixed: return "Fixed"
        case .note: return "Note"
        }
    }
}
