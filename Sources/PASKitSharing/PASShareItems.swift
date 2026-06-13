//
//  PASShareItems.swift
//  PASKitSharing
//
//  Identifiable wrapper for activity items so `.sheet(item:)` presents
//  reliably — setting the optional in the same update that computes the
//  items avoids the empty-first-presentation timing issue of
//  `.sheet(isPresented:)` + separate state.
//

import Foundation

/// Activity items for `.sheet(item:)` presentation of `PASActivitySheet`.
///
/// ```swift
/// @State private var shareItems: PASShareItems?
/// // ...
/// shareItems = PASShareItems([image, caption])
/// // .sheet(item: $shareItems) { PASActivitySheet(items: $0.items) }
/// ```
public struct PASShareItems: Identifiable {
    public let id = UUID()
    public let items: [Any]

    public init(_ items: [Any]) {
        self.items = items
    }
}
