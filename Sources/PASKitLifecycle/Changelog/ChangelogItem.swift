//
//  ChangelogItem.swift
//  PASKitLifecycle
//
//  A single line in a version's changelog. The case drives the row icon —
//  apps choose which bucket each line belongs in.
//

import Foundation

/// A single line in a version's changelog. The kind drives the row icon —
/// apps choose which bucket each line belongs in.
public enum ChangelogItem: Sendable, Hashable {
    case added(String)
    case changed(String)
    case fixed(String)
    case note(String)

    public var text: String {
        switch self {
        case let .added(text), let .changed(text), let .fixed(text), let .note(text):
            return text
        }
    }
}
