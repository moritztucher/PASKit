//
//  PASAuthUser.swift
//  PASKitAuth
//
//  A `Sendable` snapshot of the signed-in identity. Firebase's own `User` is a
//  live, non-`Sendable` reference type whose properties change under you; this
//  is the value handed to delegate callbacks and returned from sign-in so an
//  app never has to hold — or hop actors with — the SDK object.
//

import Foundation

/// The signed-in identity at a moment in time.
///
/// Snapshots do not update. Read `PASAuth.shared` for live state; take a
/// `PASAuthUser` when you need to carry an identity across an `await`, store it,
/// or compare a before/after (the guest-upgrade callback passes both).
public struct PASAuthUser: Sendable, Equatable, Identifiable {

    /// Firebase UID. Stable for the life of the account — including across an
    /// anonymous-to-Apple upgrade, which is the whole point of linking rather
    /// than signing in fresh.
    public let uid: String

    /// True while this is an anonymous (un-upgraded) account.
    public let isAnonymous: Bool

    /// Display name from the provider. Apple returns a name only on the *first*
    /// authorization ever granted for the app, so this is `nil` far more often
    /// than product copy tends to assume — always have a fallback.
    public let displayName: String?

    /// Provider email, or `nil` for a guest and whenever the user chose to hide it.
    public let email: String?

    /// Provider IDs backing the account (`"apple.com"`, `"firebase"`, …). Empty
    /// for an anonymous account.
    public let providerIDs: [String]

    public var id: String { uid }

    /// True once the account is backed by a real provider.
    public var isLinked: Bool { !isAnonymous }

    public init(
        uid: String,
        isAnonymous: Bool,
        displayName: String? = nil,
        email: String? = nil,
        providerIDs: [String] = []
    ) {
        self.uid = uid
        self.isAnonymous = isAnonymous
        self.displayName = displayName
        self.email = email
        self.providerIDs = providerIDs
    }
}
