# PASKitAuth

Firebase Auth facade — Sign in with Apple, anonymous accounts, guest linking, and account deletion.

**Product:** `PASKitAuth` — **never part of the `PASKit` umbrella.** Add it explicitly, alongside
the umbrella or on its own. See
[ADR-0005](adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md).

**Vendor:** `firebase-ios-sdk`, `FirebaseAuth` product only.

## Purpose

A thin concrete facade over Firebase Auth, the same shape `PASPurchases` has over RevenueCat: PASKit
owns the mechanism, the app owns the vocabulary. The mechanism is the part every app gets subtly
wrong — nonce generation and validation, upgrading an anonymous guest in place instead of stranding
its data, recovering when an Apple ID already owns an account, and the ordering that account
deletion demands. The vocabulary — sign-in UI, copy, what a user record contains — stays in the app.

Extracted from XueTang's `FirebaseAuthService`, the studio's shipping implementation of these flows.

## Layout

| File | What it holds |
|---|---|
| `PASAuth.swift` | The facade: configure, session, Apple sign-in, sign-out, deletion |
| `PASAuthConfig.swift` | Launch configuration — fresh-install reset, anonymous-at-launch |
| `PASAuthDelegate.swift` | Hooks for moving app data alongside the session; all defaulted |
| `PASAuthUser.swift` | `Sendable` identity snapshot crossing the delegate boundary |
| `PASAccountDeletionResult.swift` | `deleted` / `requiresRecentLogin` / `failed` |
| `PASFreshInstallGuard.swift` | Drops a Keychain session left by a previous install |
| `PASAuthNonce.swift` | Internal — Apple's nonce pair |

## Surface

```swift
@MainActor @Observable public final class PASAuth {
    public static let shared: PASAuth

    // State
    public private(set) var uid: String?
    public private(set) var isAnonymous: Bool
    public private(set) var displayName: String?
    public private(set) var email: String?
    public private(set) var lastError: String?
    public private(set) var isBusy: Bool
    public private(set) var isConfigured: Bool
    public var isLinked: Bool
    public var isSignedIn: Bool
    public weak var delegate: (any PASAuthDelegate)?

    // Lifecycle
    public func configure(_ config: PASAuthConfig = PASAuthConfig()) async
    @discardableResult public func restoreSession() -> PASAuthUser?
    @discardableResult public func signInAnonymouslyIfNeeded() async -> String?

    // Sign in with Apple
    @discardableResult public func prepareAppleSignIn() -> String
    public func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest)
    @discardableResult public func signInWithApple(authorization: ASAuthorization) async throws -> PASAuthUser
    public func completeAppleSignIn(_ result: Result<ASAuthorization, any Error>) async

    // Ending the session
    public func signOut() async
    public func deleteAccount() async -> PASAccountDeletionResult
}
```

## The two Apple entry points

Both exist because the two ways to present Sign in with Apple hand back different things.

`prepareAppleSignIn()` returns the hashed nonce for an `ASAuthorizationAppleIDRequest` you build
yourself, and `signInWithApple(authorization:)` **throws** — use this pair when driving
`ASAuthorizationController` directly.

`prepareAppleRequest(_:)` and `completeAppleSignIn(_:)` are shaped for SwiftUI's
`SignInWithAppleButton(onRequest:onCompletion:)`, which passes a request to configure and returns a
`Result`. The completion variant does not throw; failures land in `lastError`, and a user-cancelled
sheet is not recorded as one.

Either way `isBusy` is raised in the *prepare* step, not the completion. The native Apple button has
no start callback, so building the request is the earliest hook — bind controls to `isBusy` and they
disable before the system sheet appears rather than after it closes.

## Deletion ordering

`deleteAccount()` calls `willDeleteAccount(uid:)` **before** destroying the account, and
`didDeleteAccount(uid:)` after. That ordering is not stylistic: app data in Firestore is normally
readable only while its owner is authenticated, so deleting the auth account first strands it
permanently. Delete remote data in `willDeleteAccount` and return `false` if that fails; wipe local
state in `didDeleteAccount`.

`.requiresRecentLogin` is an outcome, not an error. Firebase refuses to delete an account on a stale
session; the app re-authenticates and calls `deleteAccount()` again. Nothing was destroyed and
nothing is inconsistent.

Apple-linked accounts also get a best-effort token revocation, which App Store guideline 5.1.1(v)
requires. It needs the Apple OAuth code flow configured in the Firebase console *and* an unexpired
authorization code, so it is attempted and logged but never allowed to block the deletion.

## Running without Firebase

With no `GoogleService-Info.plist` bundled, `configure(_:)` logs, leaves `isConfigured` false, and
every method no-ops. The app runs signed-out instead of crashing, so it can ship before its Firebase
project exists. Dropping the plist in is the only switch.

## Design decisions

- **No `PASAuthError`.** Thrown failures are `PASError`, so an app's installed localizer
  ([ADR-0003](adr/ADR-0003-error-copy-is-app-vocabulary.md)) covers auth copy with no extra wiring.
  Outcomes worth branching on are result types instead.
- **`delegate` is weak.** The delegate is normally a model object that reaches back into auth; a
  strong reference would close the cycle.
- **`PASAuthUser` rather than Firebase's `User`.** Firebase's is a live, non-`Sendable` reference
  whose properties change underneath you. Delegate callbacks get an immutable snapshot.
- **Guest upgrade has its own callback.** `didUpgradeGuest` is separate from `didSignIn` because the
  app's response differs: migrate what the guest accumulated, rather than load an existing account.

## Out of scope (v1)

- **Google sign-in.** Deliberate — see
  [ADR-0005](adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md). XueTang cannot migrate onto
  this module until it lands, most likely as a separate `PASKitAuthGoogle` product.
- **Email/password, phone, and other providers.** No consumer.
- **Firestore and Analytics.** Only `FirebaseAuth` is linked; apps declare the rest themselves.

## Tests

`PASKitAuthTests` covers the pure logic — nonce length, charset, distinctness, and SHA256 against a
known vector; the value types crossing the delegate boundary; and that an empty `PASAuthDelegate`
conformance compiles and vetoes nothing. It never touches `Auth.auth()`, which needs a configured
`FirebaseApp` and a real bundle, so it runs on the CI host without a simulator.
