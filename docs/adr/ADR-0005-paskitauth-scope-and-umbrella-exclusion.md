# ADR-0005 — `PASKitAuth`: Apple-only scope, and not re-exported by the `PASKit` umbrella

**Status:** Accepted — drafted and implemented 2026-09-06.

## Context

`PASKitAuth` is the Firebase Auth facade named in
[`docs/audit/xuetangv2-extract-to-paskit.md`](../audit/xuetangv2-extract-to-paskit.md) row 5, whose
stated trigger was *"extract when a second app needs accounts."* Protocoll66 is that second app: it
was built against `PASBasePackage`, a local Swift package referenced by relative path
(`../PASBasePackage`), which resolves on its author's laptop and on no CI machine. Its
`AuthenticationManager` covers Sign in with Apple, session restore, and account deletion.

The donor implementation is XueTang's `FirebaseAuthService` (351 lines), which is the studio's only
shipping auth code and covers Apple, Google, anonymous accounts, guest linking, and deletion.

Two questions had to be settled before the module could land: which providers it carries, and
whether the umbrella re-exports it.

## Decision 1 — Apple only; no Google sign-in

**`PASKitAuth` ships Sign in with Apple, anonymous accounts, guest linking, and deletion. Google
sign-in is deliberately left out of v1.**

Carrying Google would mean a hard `GoogleSignIn-iOS` dependency for every consumer of the module.
The app driving the extraction offers Apple only, so the entire Google surface — the SDK, the
`GIDSignIn.handleURL` plumbing, the reversed-client-ID URL scheme in `Info.plist`, the
`topViewController()` window-scene walk — would be dead weight in the one app that adopts it. That
is the same objection ADR-0004 raised against putting `PASKitHealth` in the umbrella: an app should
not link and configure a vendor SDK for a capability it does not offer.

It also runs against the repo's own stated method — *"prefer lifting proven code over designing in
the abstract"* (`BuildPhilosophy`). Google is proven in XueTang, but XueTang is not adopting
`PASKitAuth` in this change, so lifting it now would ship an untested-in-place API with no consumer
to hold it honest.

The cost is explicit: **XueTang cannot migrate onto `PASKitAuth` as it stands**, because it would
lose Google sign-in. Adding it is the natural next increment, and the shape is already clear — a
separate `PASKitAuthGoogle` product, so the dependency stays opt-in the way `PASKitHealth` is.
That is deferred to the change that actually migrates XueTang, where a real consumer can verify it.

## Decision 2 — not re-exported by the `PASKit` umbrella

**`PASKitAuth` joins `PASKitHealth` as a module the umbrella does not re-export.** Apps that use
accounts add the `PASKitAuth` product explicitly.

The mechanics are the same as ADR-0004. SwiftPM statically links a library product into the
consuming binary, so umbrella membership is not free: every umbrella consumer would link the
Firebase iOS SDK — a large dependency with its own transitive graph (gRPC, abseil, nanopb) — and
pay its resolve and build cost, whether or not the app has accounts. Two of the three current
consuming apps (WorkoutApp, CoupleCalorieTracker) are account-less and offline by design.

Firebase also fails differently from an unused framework: `FirebaseApp.configure()` expects a
bundled `GoogleService-Info.plist`, and an app that has no Firebase project has no plist to bundle.
`PASAuth` handles that case deliberately — with no plist it logs, leaves `isConfigured` false, and
every method no-ops, so an account-less app that took the umbrella would not *break*. But it would
carry a Firebase SDK it never configures, which is a cost with no matching benefit.

This makes the umbrella's exclusion list two entries long rather than one. That is a real erosion
of "the umbrella re-exports everything," and worth naming: the rule that actually holds is
narrower — **the umbrella re-exports every module that does not force a vendor SDK or a
platform capability onto apps that do not use it.** ADR-0004 and this ADR are the same rule applied
twice, not two exceptions.

## Consequences

- Apps take `.product(name: "PASKitAuth", package: "PASKit")` explicitly, alongside the umbrella or
  alone.
- `Package.swift` gains `firebase-ios-sdk`, pinned `from: "11.15.0"` — the major XueTang ships the
  donor against, so the behaviour inherited here is verified somewhere real. Only the `FirebaseAuth`
  product is taken; an app wanting Firestore or Analytics declares those itself.
- Resolving PASKit now fetches Firebase for every consumer even though only `PASKitAuth` links it.
  That is a resolve-time cost, not a link-time one, and it is the price of a single-package repo.
- `PASAuthError` was not introduced. Thrown failures use `PASError` per
  [ADR-0003](ADR-0003-error-copy-is-app-vocabulary.md), so app-installed copy applies to auth
  failures with no extra wiring; outcomes an app must branch on — `requiresRecentLogin` above all —
  are modelled as `PASAccountDeletionResult` values rather than errors.
