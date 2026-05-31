//
//  ChangelogEntry.swift
//  PASKitLifecycle
//
//  One released version's changelog — what `ChangelogView` consumes.
//

import Foundation

/// One released version's changelog. `id` defaults to `version`, so versions
/// must be unique within a `ChangelogView`.
public struct ChangelogEntry: Identifiable, Sendable, Hashable {

    public let id: String
    public let version: String
    public let date: Date?
    public let items: [ChangelogItem]

    public init(version: String, date: Date? = nil, items: [ChangelogItem]) {
        self.id = version
        self.version = version
        self.date = date
        self.items = items
    }
}
