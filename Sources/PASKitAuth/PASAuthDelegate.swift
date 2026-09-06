//
//  PASAuthDelegate.swift
//  PASKitAuth
//
//  Callbacks for the moments where an app has to move its own data alongside
//  the auth session — the only part of authentication PASKit cannot own,
//  because it is entirely about the app's model.
//

import Foundation

/// Persistence hooks fired around auth state changes.
///
/// Every method has a default no-op implementation, so conform and implement
/// only the events the app actually acts on. Callbacks run on the main actor,
/// after `PASAuth`'s own observable state has been updated — read
/// `PASAuth.shared` inside one and it is already current.
///
/// Set via `PASAuth.shared.delegate`, which is **weak**: the delegate is
/// typically a model object that itself reaches back into auth, and a strong
/// reference here would close that cycle.
@MainActor
public protocol PASAuthDelegate: AnyObject {

    /// A fresh anonymous account was created, or an existing one adopted at
    /// launch. The `uid` is stable until the account is deleted — an upgrade to
    /// a real provider preserves it.
    func didSignInAsGuest(uid: String) async

    /// The user signed in to an account. Fires for a straight sign-in and for a
    /// sign-in to an account that already existed for this Apple ID — but *not*
    /// for a guest upgrade, which has its own callback because the app usually
    /// needs to migrate rather than load.
    func didSignIn(user: PASAuthUser) async

    /// An anonymous guest was linked to a real provider in place. `guestUID` and
    /// `user.uid` are the same value; both are passed so the callback reads
    /// unambiguously and stays correct if that ever stops being true.
    func didUpgradeGuest(from guestUID: String, to user: PASAuthUser) async

    /// The session ended. Clear anything derived from the signed-in identity.
    func didSignOut() async

    /// Called before the auth account is destroyed. Return `false` to abort —
    /// use it to delete the app's own remote data first, and to refuse deletion
    /// if that cleanup fails, so an account is never orphaned from its data.
    func willDeleteAccount(uid: String) async -> Bool

    /// The auth account is gone. Wipe local state.
    func didDeleteAccount(uid: String) async
}

public extension PASAuthDelegate {
    func didSignInAsGuest(uid: String) async {}
    func didSignIn(user: PASAuthUser) async {}
    func didUpgradeGuest(from guestUID: String, to user: PASAuthUser) async {}
    func didSignOut() async {}
    func willDeleteAccount(uid: String) async -> Bool { true }
    func didDeleteAccount(uid: String) async {}
}
