//
//  PASAuthConfig.swift
//  PASKitAuth
//
//  Configuration handed to `PASAuth.shared.configure(_:)` once at launch.
//

import Foundation

/// Configuration for the Firebase Auth session.
///
/// There is no API key here: Firebase reads its credentials from the bundled
/// `GoogleService-Info.plist`, and `PASAuth` stays inert when that file is
/// absent (see `PASAuth.isConfigured`).
public struct PASAuthConfig: Sendable {

    /// Sign out of any Keychain-resident session on the first launch after a
    /// fresh install.
    ///
    /// iOS clears `UserDefaults` and the app's store on delete-and-reinstall but
    /// **not** the Keychain, and Firebase Auth persists its session there. Left
    /// alone, a reinstalled app silently resurrects the previous account. Leave
    /// this on unless the app deliberately wants a reinstall to resume the old
    /// session. See `PASFreshInstallGuard`.
    public let resetSessionOnFreshInstall: Bool

    /// Create an anonymous account at launch when no session exists, so a stable
    /// `uid` is always available to key documents with. Apps that only ever want
    /// a real signed-in user should leave this off and call
    /// `signInAnonymouslyIfNeeded()` themselves, or not at all.
    public let signInAnonymouslyAtLaunch: Bool

    public init(
        resetSessionOnFreshInstall: Bool = true,
        signInAnonymouslyAtLaunch: Bool = false
    ) {
        self.resetSessionOnFreshInstall = resetSessionOnFreshInstall
        self.signInAnonymouslyAtLaunch = signInAnonymouslyAtLaunch
    }
}
