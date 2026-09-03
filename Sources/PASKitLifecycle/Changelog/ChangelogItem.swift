//
//  ChangelogItem.swift
//  PASKitLifecycle
//
//  A single line in a release's changelog. The case drives the row icon —
//  apps choose which bucket each line belongs in.
//

import Foundation

/// A single line in a release's changelog. The kind drives the row icon —
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

    /// Parses a prefix-tagged authoring string, so a release list can stay a
    /// literal array of one-liners:
    ///
    /// | Prefix | Case |
    /// |--------|------|
    /// | `+`    | ``added`` |
    /// | `>`    | ``changed`` |
    /// | `~`    | ``fixed`` |
    /// | `*`    | ``note`` |
    ///
    /// Total, never failing: a string with no recognised prefix becomes a
    /// ``note`` carrying the whole string, so a missing marker degrades to a
    /// plain line rather than dropping content.
    public init(prefixed string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let marker = trimmed.first, "+>~*".contains(marker) else {
            self = .note(trimmed)
            return
        }
        let body = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        switch marker {
        case "+": self = .added(body)
        case ">": self = .changed(body)
        case "~": self = .fixed(body)
        default: self = .note(body)
        }
    }
}
