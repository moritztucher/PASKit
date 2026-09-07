//
//  PASAuthValueTests.swift
//  PASKitAuthTests
//
//  The value types that cross the delegate boundary, and the default delegate
//  conformance apps rely on to implement only the callbacks they care about.
//

import Testing
@testable import PASKitAuth

@Suite("PASAuthUser")
struct PASAuthUserTests {

    @Test("isLinked is the inverse of isAnonymous")
    func linkedMirrorsAnonymous() {
        #expect(PASAuthUser(uid: "u", isAnonymous: false).isLinked)
        #expect(!PASAuthUser(uid: "u", isAnonymous: true).isLinked)
    }

    @Test("id is the uid, so it is Identifiable by account")
    func idIsUID() {
        #expect(PASAuthUser(uid: "abc", isAnonymous: false).id == "abc")
    }

    @Test("Equality covers every field, not just the uid")
    func equalityIsStructural() {
        let base = PASAuthUser(uid: "u", isAnonymous: false, displayName: "A", email: "a@b.c")
        #expect(base == PASAuthUser(uid: "u", isAnonymous: false, displayName: "A", email: "a@b.c"))
        #expect(base != PASAuthUser(uid: "u", isAnonymous: false, displayName: "B", email: "a@b.c"))
        #expect(base != PASAuthUser(uid: "u", isAnonymous: true, displayName: "A", email: "a@b.c"))
    }
}

@Suite("PASAccountDeletionResult")
struct PASAccountDeletionResultTests {

    @Test("requiresRecentLogin is distinct from a failure")
    func recentLoginIsNotFailure() {
        // The whole point of the type: the caller must be able to tell "sign in
        // again and retry" apart from "this went wrong".
        #expect(PASAccountDeletionResult.requiresRecentLogin != .failed("nope"))
        #expect(PASAccountDeletionResult.deleted != .requiresRecentLogin)
    }

    @Test("Failures compare by message")
    func failureCarriesMessage() {
        #expect(PASAccountDeletionResult.failed("a") == .failed("a"))
        #expect(PASAccountDeletionResult.failed("a") != .failed("b"))
    }
}

@Suite("PASAuthDelegate defaults")
@MainActor
struct PASAuthDelegateDefaultTests {

    /// Implements nothing — every callback must come from the protocol
    /// extension, which is what lets an app override only what it needs.
    private final class BareDelegate: PASAuthDelegate {}

    @Test("An empty conformance compiles and vetoes nothing")
    func defaultsAllowDeletion() async {
        let delegate = BareDelegate()
        #expect(await delegate.willDeleteAccount(uid: "u"))
        // The rest are no-ops; calling them proves they exist and are callable.
        await delegate.didSignInAsGuest(uid: "u")
        await delegate.didSignIn(user: PASAuthUser(uid: "u", isAnonymous: false))
        await delegate.didUpgradeGuest(from: "u", to: PASAuthUser(uid: "u", isAnonymous: false))
        await delegate.didSignOut()
        await delegate.didDeleteAccount(uid: "u")
    }
}
