//
//  ChangelogSlots.swift
//  PASKitLifecycle
//
//  The value PASKit hands to `ChangelogView`'s branding slot.
//

import SwiftUI

/// Handed to ``ChangelogView/entryContainer(_:)``. Decorates one release's stock
/// block — wrap ``content``, do not rebuild it.
public struct ChangelogEntryConfiguration {

    /// PASKit's stock release block: version header, optional "Latest" badge and
    /// date, then one row per change.
    public struct Content: View {
        let stock: AnyView
        public var body: some View { stock }
    }

    /// The release being rendered, for containers that vary by content.
    public let note: ReleaseNote

    /// Whether this is the newest release in the list.
    public let isLatest: Bool

    /// The stock block to wrap.
    public let content: Content
}
