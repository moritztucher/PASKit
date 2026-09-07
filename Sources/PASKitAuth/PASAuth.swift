//
//  PASAuth.swift
//  PASKitAuth
//
//  Thin concrete facade over Firebase Auth — a convenience wrapper, not a
//  vendor abstraction, the same shape as `PASPurchases` over RevenueCat.
//  PASKit owns the mechanism (nonce handling, guest upgrade, the deletion
//  dance); each app owns its vocabulary (sign-in UI, copy, what a user record
//  means).
//
//  Sign in with Apple only. Google sign-in is deliberately absent — see
//  docs/adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md.
//

import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import Foundation
import PASKitCore

/// Firebase Auth facade. `PASAuth.shared.configure(...)` once at launch, then
/// observe `uid` / `isSignedIn` / `isLinked` for gating, drive Sign in with
/// Apple through `prepareAppleSignIn()` + `signInWithApple(authorization:)`,
/// and implement `PASAuthDelegate` for the points where the app's own data has
/// to move with the session.
///
/// Stays inert without a bundled `GoogleService-Info.plist`: every entry point
/// guards on `isConfigured`, so a build with no Firebase project runs
/// signed-out rather than crashing.
@MainActor
@Observable
public final class PASAuth {

    public static let shared = PASAuth()

    // MARK: - Observable state

    /// The signed-in user's UID, or `nil` when signed out or unconfigured.
    public private(set) var uid: String?

    /// True while the session is an anonymous (un-upgraded) account.
    public private(set) var isAnonymous = false

    /// Display name from the provider. Apple supplies one only on the *first*
    /// authorization ever granted for this app, so expect `nil` routinely.
    public private(set) var displayName: String?

    /// Provider email, or `nil` for a guest and when the user hid it.
    public private(set) var email: String?

    /// Last sign-in failure, developer-facing. Cleared when a fresh attempt
    /// starts. Populated only by the non-throwing `completeAppleSignIn(_:)`
    /// path; the throwing API reports through the thrown error instead.
    public private(set) var lastError: String?

    /// True while a sign-in is in flight. Bind sign-in controls to it — the
    /// native Apple button has no start callback, so the flag is raised in
    /// `prepareAppleSignIn()`, before the system sheet appears.
    public private(set) var isBusy = false

    /// True once Firebase configured. `false` means no bundled plist: the app
    /// runs signed-out and every method here no-ops.
    public private(set) var isConfigured = false

    /// True once the account is backed by a real provider.
    public var isLinked: Bool { uid != nil && !isAnonymous }

    /// True whenever there is any session at all, guest included.
    public var isSignedIn: Bool { uid != nil }

    /// Hooks for moving app data alongside the session. Weak: the delegate is
    /// usually a model object that reaches back into auth, and a strong
    /// reference here would close that cycle.
    public weak var delegate: (any PASAuthDelegate)?

    // MARK: - Private state

    private let log = PASLogger.make(category: "auth")

    /// Raw nonce for the in-flight Apple request, checked against the identity
    /// token Apple returns. See `PASAuthNonce`.
    @ObservationIgnored private var currentNonce: String?

    /// Apple authorization code from the last sign-in, kept for best-effort
    /// token revocation at deletion time (App Store guideline 5.1.1(v)).
    @ObservationIgnored private var lastAppleAuthorizationCode: String?

    private init() {}

    // MARK: - Setup

    /// Configure Firebase Auth. Call once, early at launch, before any UI reads
    /// `uid`. Subsequent calls log a warning and no-op.
    ///
    /// Configuring is conditional on a bundled `GoogleService-Info.plist`: with
    /// no plist this logs and returns, leaving `isConfigured` false, so an app
    /// can ship before its Firebase project exists without a code change at the
    /// call sites.
    public func configure(_ config: PASAuthConfig = PASAuthConfig()) async {
        guard !isConfigured else {
            log.warning("PASAuth.configure called twice — ignoring the second call.")
            return
        }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            log.notice("No GoogleService-Info.plist bundled — auth disabled, app runs signed-out.")
            // Still record the install: there is no session to clear, but the
            // marker keeps a later build that *does* have a plist from firing
            // the guard against everyone at once.
            PASFreshInstallGuard.resetIfFreshInstall(signOut: false)
            return
        }
        // FirebaseApp.configure() is not idempotent — it logs a fatal-looking
        // error on a second call. Guard on the app already existing so an app
        // that configures Firebase itself (for Firestore, say) can still call
        // this.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = true

        // Must run before the first currentUser read, or the stale session is
        // already adopted. Called unconditionally so the install marker is
        // written either way — see PASFreshInstallGuard.
        PASFreshInstallGuard.resetIfFreshInstall(signOut: config.resetSessionOnFreshInstall)

        adopt(Auth.auth().currentUser)
        log.info("Firebase Auth configured.")

        if config.signInAnonymouslyAtLaunch {
            await signInAnonymouslyIfNeeded()
        }
    }

    /// Adopt whatever session Firebase already holds, without signing anyone in.
    ///
    /// `configure(_:)` does this already; call it directly only to re-read the
    /// SDK's state after changing it behind PASKit's back.
    @discardableResult
    public func restoreSession() -> PASAuthUser? {
        guard isConfigured else { return nil }
        adopt(Auth.auth().currentUser)
        guard let user = Auth.auth().currentUser else { return nil }
        return Self.snapshot(of: user)
    }

    // MARK: - Anonymous

    /// Ensure a session exists, creating an anonymous one if needed, and return
    /// its UID.
    ///
    /// An anonymous account gives the app a stable key to write documents under
    /// before the user has committed to signing in; linking later preserves that
    /// UID, so nothing has to be migrated. Returns `nil` when unconfigured or
    /// when account creation fails.
    @discardableResult
    public func signInAnonymouslyIfNeeded() async -> String? {
        guard isConfigured else { return nil }
        if let current = Auth.auth().currentUser {
            adopt(current)
            return current.uid
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            adopt(result.user)
            let uid = result.user.uid
            log.notice("Signed in anonymously.")
            await delegate?.didSignInAsGuest(uid: uid)
            return uid
        } catch {
            log.error("Anonymous sign-in failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Sign in with Apple

    /// Start an Apple sign-in and return the hashed nonce for the request.
    ///
    /// Assign the result to `ASAuthorizationAppleIDRequest.nonce`. Raises
    /// `isBusy` — the native Apple button has no start callback, so this is the
    /// earliest hook, ahead of the user even seeing the sheet.
    ///
    /// Use `prepareAppleRequest(_:)` instead when building the request through
    /// SwiftUI's `SignInWithAppleButton(onRequest:)`.
    @discardableResult
    public func prepareAppleSignIn() -> String {
        lastError = nil
        isBusy = true
        let nonce = PASAuthNonce.random()
        currentNonce = nonce
        return PASAuthNonce.sha256(nonce)
    }

    /// Configure an Apple ID request with the scopes and nonce this facade
    /// expects. Convenience over `prepareAppleSignIn()` for the SwiftUI button.
    public func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let hashedNonce = prepareAppleSignIn()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
    }

    /// Complete Apple sign-in from a successful authorization.
    ///
    /// When the current session is an anonymous guest the Apple identity is
    /// *linked* to it, preserving the UID and anything already keyed to it;
    /// otherwise it signs in fresh. An Apple ID that already owns an account is
    /// recovered into rather than failing.
    ///
    /// Fires `didUpgradeGuest` or `didSignIn` on the delegate accordingly.
    @discardableResult
    public func signInWithApple(authorization: ASAuthorization) async throws -> PASAuthUser {
        defer { isBusy = false; currentNonce = nil }
        guard isConfigured else {
            throw PASError.unexpected(description: "PASAuth.configure(_:) was not called.")
        }
        guard let appleID = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleID.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            log.error("Apple sign-in: no identity token in the authorization.")
            throw PASError.invalidCredentials(source: "Sign in with Apple")
        }
        guard let rawNonce = currentNonce else {
            // prepareAppleSignIn() was never called, or a second authorization
            // arrived after the first consumed the nonce.
            log.error("Apple sign-in: no nonce in flight — call prepareAppleSignIn() first.")
            throw PASError.invalidCredentials(source: "Sign in with Apple")
        }
        lastAppleAuthorizationCode = appleID.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken, rawNonce: rawNonce, fullName: appleID.fullName
        )
        return try await linkOrSignIn(with: credential, fullName: appleID.fullName)
    }

    /// Non-throwing completion for SwiftUI's `SignInWithAppleButton(onCompletion:)`,
    /// which hands back a `Result`.
    ///
    /// Failures land in `lastError` instead of being thrown, and a user-cancelled
    /// sheet is not treated as one. `isBusy` clears on every path, including
    /// cancellation, so a dismissed sheet never leaves the button stuck.
    public func completeAppleSignIn(_ result: Result<ASAuthorization, any Error>) async {
        switch result {
        case .failure(let error):
            isBusy = false
            currentNonce = nil
            if (error as? ASAuthorizationError)?.code != .canceled {
                log.error("Apple sign-in failed: \(error.localizedDescription)")
                lastError = error.localizedDescription
            }
        case .success(let authorization):
            do {
                _ = try await signInWithApple(authorization: authorization)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Upgrade an anonymous guest in place when possible; otherwise sign in
    /// fresh. Recovers from an Apple ID that already owns an account by signing
    /// into that account with the credential Firebase hands back.
    private func linkOrSignIn(
        with credential: AuthCredential,
        fullName: PersonNameComponents?
    ) async throws -> PASAuthUser {
        let wasAnonymousGuest = Auth.auth().currentUser?.isAnonymous ?? false
        let guestUID = wasAnonymousGuest ? Auth.auth().currentUser?.uid : nil
        do {
            if let current = Auth.auth().currentUser, current.isAnonymous {
                let result = try await current.link(with: credential)
                adopt(result.user)
                await updateDisplayName(from: fullName)
                let user = Self.snapshot(of: result.user)
                log.notice("Linked anonymous guest to Apple.")
                if let guestUID {
                    await delegate?.didUpgradeGuest(from: guestUID, to: user)
                }
                return user
            }
            let result = try await Auth.auth().signIn(with: credential)
            adopt(result.user)
            await updateDisplayName(from: fullName)
            let user = Self.snapshot(of: result.user)
            log.notice("Signed in with Apple.")
            await delegate?.didSignIn(user: user)
            return user
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            // This Apple ID already owns an account. Firebase returns a usable
            // credential for it; sign into that rather than failing. Anything
            // the guest accumulated stays local — the app decides whether to
            // reconcile it.
            guard let existing = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential else {
                log.error("Apple ID already in use and no recovery credential was supplied.")
                throw PASError.invalidCredentials(source: "Sign in with Apple")
            }
            let result = try await Auth.auth().signIn(with: existing)
            adopt(result.user)
            let user = Self.snapshot(of: result.user)
            log.notice("Apple ID already in use — signed into the existing account.")
            await delegate?.didSignIn(user: user)
            return user
        }
    }

    /// Apple returns a full name only on the first authorization, so adopt it
    /// onto the Firebase profile whenever it is present. Best-effort: a failure
    /// here must not fail the sign-in.
    private func updateDisplayName(from fullName: PersonNameComponents?) async {
        guard let fullName, let user = Auth.auth().currentUser else { return }
        let formatted = PersonNameComponentsFormatter().string(from: fullName)
        guard !formatted.isEmpty else { return }
        let change = user.createProfileChangeRequest()
        change.displayName = formatted
        do {
            try await change.commitChanges()
            displayName = formatted
        } catch {
            log.error("Setting the display name failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign out

    /// End the session. Fires `didSignOut` on the delegate.
    public func signOut() async {
        guard isConfigured else { return }
        do {
            try Auth.auth().signOut()
            adopt(nil)
            lastAppleAuthorizationCode = nil
            await delegate?.didSignOut()
        } catch {
            log.error("Sign-out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Account deletion

    /// Delete the auth account.
    ///
    /// Ordering matters and is enforced through the delegate: `willDeleteAccount`
    /// runs first and can veto, which is where the app deletes its own *remote*
    /// data — that data is usually readable only while its owner is still
    /// authenticated, so deleting the account first would strand it. Local
    /// cleanup belongs in `didDeleteAccount`, after.
    ///
    /// For an Apple-linked account this also makes a best-effort token
    /// revocation, which App Store guideline 5.1.1(v) requires. Revocation needs
    /// the Apple OAuth code flow configured in the Firebase console *and* an
    /// unexpired authorization code, so it is attempted and logged, never
    /// allowed to block the deletion itself.
    ///
    /// Returns `.requiresRecentLogin` when Firebase wants a fresh sign-in: have
    /// the user re-authenticate and call this again.
    public func deleteAccount() async -> PASAccountDeletionResult {
        guard isConfigured, let user = Auth.auth().currentUser else {
            return .failed("Not signed in.")
        }
        let uid = user.uid

        if await delegate?.willDeleteAccount(uid: uid) == false {
            log.notice("Account deletion vetoed by the delegate.")
            return .failed("Deletion was cancelled by the app.")
        }

        if user.providerData.contains(where: { $0.providerID == "apple.com" }),
           let code = lastAppleAuthorizationCode {
            do {
                try await Auth.auth().revokeToken(withAuthorizationCode: code)
            } catch {
                log.error("Apple token revocation failed (best-effort): \(error.localizedDescription)")
            }
        }

        // Re-fetch rather than holding the non-Sendable `User` across the
        // revoke await above.
        guard let current = Auth.auth().currentUser else {
            return .failed("Not signed in.")
        }
        do {
            try await current.delete()
            adopt(nil)
            lastAppleAuthorizationCode = nil
            log.notice("Deleted the auth account.")
            await delegate?.didDeleteAccount(uid: uid)
            return .deleted
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            log.notice("Account deletion needs a recent login.")
            return .requiresRecentLogin
        } catch {
            log.error("Account deletion failed: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Private

    /// Mirror the Firebase user into the observable state.
    private func adopt(_ user: User?) {
        uid = user?.uid
        isAnonymous = user?.isAnonymous ?? false
        displayName = user?.displayName
        email = user?.email
    }

    private static func snapshot(of user: User) -> PASAuthUser {
        PASAuthUser(
            uid: user.uid,
            isAnonymous: user.isAnonymous,
            displayName: user.displayName,
            email: user.email,
            providerIDs: user.providerData.map(\.providerID)
        )
    }
}
