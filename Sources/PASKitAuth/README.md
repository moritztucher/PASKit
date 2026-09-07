# PASKitAuth

Firebase Auth facade — Sign in with Apple, anonymous accounts, guest linking, deletion.

Full documentation: [docs/PASKitAuth.md](../../docs/PASKitAuth.md).
Scope and umbrella rationale: [ADR-0005](../../docs/adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md).

**Not part of the `PASKit` umbrella.** Add the product explicitly.

## API

`PASAuth.shared` — `configure(_:)`, `restoreSession()`, `signInAnonymouslyIfNeeded()`,
`prepareAppleSignIn()` / `prepareAppleRequest(_:)`, `signInWithApple(authorization:)` /
`completeAppleSignIn(_:)`, `signOut()`, `deleteAccount()`. Observable `uid` / `isAnonymous` /
`isLinked` / `isSignedIn` / `isBusy` / `isConfigured` / `lastError`.

`PASAuthDelegate` — `didSignInAsGuest` / `didSignIn` / `didUpgradeGuest` / `didSignOut` /
`willDeleteAccount` / `didDeleteAccount`. Every method is defaulted; implement only what you act on.

## Example

```swift
// Launch
PASAuth.shared.delegate = userStore
await PASAuth.shared.configure(PASAuthConfig(signInAnonymouslyAtLaunch: true))

// Sign in with Apple, driving ASAuthorizationController yourself
let request = ASAuthorizationAppleIDProvider().createRequest()
request.requestedScopes = [.fullName, .email]
request.nonce = PASAuth.shared.prepareAppleSignIn()
// … present, then in the delegate callback:
let user = try await PASAuth.shared.signInWithApple(authorization: authorization)

// Or with SwiftUI's button
SignInWithAppleButton(
    onRequest: { PASAuth.shared.prepareAppleRequest($0) },
    onCompletion: { result in Task { await PASAuth.shared.completeAppleSignIn(result) } }
)
.disabled(PASAuth.shared.isBusy)

// Deletion — remote cleanup happens in willDeleteAccount, before the account goes
switch await PASAuth.shared.deleteAccount() {
case .deleted:             appState.showOnboarding = true
case .requiresRecentLogin: await reauthenticateThenRetry()
case .failed(let reason):  log.error("\(reason)")
}
```

## Notes

- Needs a bundled `GoogleService-Info.plist`. Without one the module no-ops and the app runs
  signed-out — deliberate, so an app can ship before its Firebase project exists.
- The app must enable the **Sign in with Apple** capability and, for deletion, configure Apple's
  OAuth code flow in the Firebase console if it wants token revocation to actually take.
- `delegate` is weak. Hold the delegate somewhere else.
