//
//  ChangelogView.swift
//  PASKitLifecycle
//
//  Multi-version changelog list for Settings. Distinct from `WhatsNewView`,
//  which is a single-release card sheet shown once after an update. Apps
//  supply a `[ChangelogEntry]` (newest first); rendering, sectioning and
//  kind icons are PASKit's.
//

import SwiftUI

/// A `List`-backed changelog view. Newest first. Each entry is one section;
/// each item renders the kind icon + text. Icons resolve to SF Symbols and
/// use `.tint` for accent — apps style at the call site.
public struct ChangelogView: View {

    public let entries: [ChangelogEntry]
    public let title: String

    public init(entries: [ChangelogEntry], title: String = "Changelog") {
        self.entries = entries
        self.title = title
    }

    public var body: some View {
        List {
            ForEach(entries) { entry in
                Section {
                    ForEach(Array(entry.items.enumerated()), id: \.offset) { _, item in
                        row(for: item)
                    }
                } header: {
                    header(for: entry)
                }
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func header(for entry: ChangelogEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("v\(entry.version)")
                .font(.headline)
                .foregroundStyle(.tint)
            Spacer()
            if let date = entry.date {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func row(for item: ChangelogItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol(for: item))
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)
                .accessibilityLabel(accessibilityLabel(for: item))
            Text(item.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func symbol(for item: ChangelogItem) -> String {
        switch item {
        case .added: return "plus.circle"
        case .changed: return "arrow.triangle.2.circlepath"
        case .fixed: return "wrench.adjustable"
        case .note: return "circle"
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
