# Auth Overview

PASKit's Firebase Auth facade — Sign in with Apple, anonymous accounts, guest linking, and the
ordering account deletion demands. Not part of the `PASKit` umbrella; link the product explicitly.

## Overview

`PASKitAuth` is a thin concrete facade over Firebase Auth, the same shape ``PASKitPurchases`` has
over RevenueCat. It was extracted from the studio's one shipping auth implementation when a second
app needed accounts. PASKit owns the mechanism — nonce generation and validation, upgrading an
anonymous guest in place rather than stranding its data, recovering when an Apple ID already owns an
account, best-effort Apple token revocation at deletion. Each app owns its vocabulary: the sign-in
UI, the copy, and what a user record means.

**Not re-exported by the `PASKit` umbrella.** It links the Firebase iOS SDK and its transitive graph
into any binary that takes it, and expects a bundled `GoogleService-Info.plist` that an account-less
app has no reason to carry — so apps with accounts add the product explicitly:

```swift
.product(name: "PASKitAuth", package: "PASKit")
```

Sign in with Apple only. Google sign-in is deliberately absent from v1 — see
`docs/adr/ADR-0005-paskitauth-scope-and-umbrella-exclusion.md`.

## Configure at launch

The delegate is **weak**, so hold it somewhere that outlives the call.

```swift
PASAuth.shared.delegate = userStore
await PASAuth.shared.configure(PASAuthConfig(signInAnonymouslyAtLaunch: true))
```

Without a bundled plist this logs, leaves `isConfigured` false, and every method no-ops — the app
runs signed-out rather than crashing, so it can ship before its Firebase project exists.

## Two ways in

`prepareAppleSignIn()` returns the hashed nonce for a request you build yourself, and
`signInWithApple(authorization:)` throws — the pair for `ASAuthorizationController`.
`prepareAppleRequest(_:)` and `completeAppleSignIn(_:)` are shaped for SwiftUI's
`SignInWithAppleButton`, and the completion form reports through `lastError` instead of throwing.

`isBusy` is raised when the request is *prepared*, not when it completes: the native Apple button
has no start callback, so building the request is the earliest hook. Bind controls to it and they
disable before the system sheet appears.

## Guests are upgraded, not replaced

An anonymous account gives the app a stable uid to key documents with before the user commits to
signing in. Linking Apple to that account preserves the uid, so nothing has to be migrated — which
is why ``PASAuthDelegate`` reports it as `didUpgradeGuest(from:to:)` rather than `didSignIn`: the
app's response is usually to reconcile, not to load.

## Deleting an account

```swift
switch await PASAuth.shared.deleteAccount() {
case .deleted:             appState.showOnboarding = true
case .requiresRecentLogin: await reauthenticateThenRetry()
case .failed(let reason):  log.error("\(reason)")
}
```

`willDeleteAccount(uid:)` runs **before** the account is destroyed and can veto by returning
`false`. That is where remote data goes: it is normally readable only while its owner is still
authenticated, so deleting the account first strands it. Local cleanup belongs in
`didDeleteAccount(uid:)`.

`.requiresRecentLogin` is an outcome, not a failure — Firebase refuses to delete on a stale session.
Re-authenticate and call again; nothing was destroyed.
