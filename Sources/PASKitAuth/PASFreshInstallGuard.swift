//
//  PASFreshInstallGuard.swift
//  PASKitAuth
//
//  iOS wipes UserDefaults and the app's store on delete-and-reinstall, but the
//  Keychain survives — and Firebase Auth persists its session there. Left
//  untouched, a reinstalled app silently resurrects the previous account
//  (anonymous or linked) and, for a linked one, pulls its cloud data back down.
//  For most apps that contradicts the expectation that a reinstall is a clean
//  slate.
//

import FirebaseAuth
import Foundation
import PASKitCore

/// Clears a Keychain-resident auth session left behind by a previous install.
///
/// `PASAuth.configure(_:)` runs this automatically unless the config turns it
/// off; it is public so an app with its own launch ordering can call it
/// directly. Idempotent — the marker it writes makes every later launch a no-op.
public enum PASFreshInstallGuard {

    private static let log = PASLogger.make(category: "auth-fresh-install")
    private static let markerKey = "com.pocketapps.paskit.auth.installMarker"

    /// True once this install has been seen before.
    public static var hasRunForThisInstall: Bool {
        UserDefaults.standard.bool(forKey: markerKey)
    }

    /// Mark this install as seen, signing out of any carried-over session first.
    ///
    /// Call after Firebase is configured and **before** anything reads
    /// `Auth.auth().currentUser`, or the stale session will already have been
    /// adopted.
    ///
    /// The marker is written on the first launch of an install whether or not
    /// `signOut` is set. That is deliberate: an app that ships with the reset
    /// disabled and enables it in a later version would otherwise fire the guard
    /// against its whole existing user base at once, signing everyone out. Always
    /// call this — pass `signOut: false` to record the install without touching
    /// the session.
    ///
    /// - Parameter signOut: Whether to drop a session left by a previous install.
    @MainActor
    public static func resetIfFreshInstall(signOut: Bool) {
        guard !hasRunForThisInstall else { return }
        defer { UserDefaults.standard.set(true, forKey: markerKey) }
        guard signOut else {
            log.debug("Fresh install recorded; session reset is disabled.")
            return
        }
        do {
            try Auth.auth().signOut()
            log.notice("Fresh install — cleared a carried-over auth session.")
        } catch {
            // No current user is the normal case, not a failure.
            log.debug("Fresh-install sign-out no-op: \(error.localizedDescription)")
        }
    }
}
