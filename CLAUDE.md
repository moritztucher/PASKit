# CLAUDE.md — PASKit

Guidance for Claude Code when working in this repository.

## What This Is

PASKit is a modular Swift Package for solo iOS founders and small studios shipping multiple apps. Each app depends only on the modules it needs. Building a capability once here is what makes apps 3, 4, 5 cheap to ship.

Extracted from production apps over 12 months. Public under MIT from v0.1.0.

## For consuming apps

An app that adopts PASKit can wire Claude Code into its surface by adding this line to its own `CLAUDE.md`:

```
@<relative-path>/CLAUDE-INTEGRATION.md
```

For a sibling repo: `@../PASKit/CLAUDE-INTEGRATION.md`. That single import gives the consuming session PASKit's module list, public API surface, conventions, and the build philosophy summary — so it uses PASKit to the full extent instead of reinventing.

When the public surface changes (new module, new API, new convention), update `CLAUDE-INTEGRATION.md` in the same commit. It is the contract apps depend on.

## Modules

Each module has a spec doc in `docs/` — the source of truth for what that module should become. Read the relevant doc before working on a module.

| Module | Spec | Purpose |
|--------|------|---------|
| `PASKitCore` | [docs/PASKitCore.md](docs/PASKitCore.md) | Foundational utilities — networking, logging, reachability, credentials, app metadata. |
| `PASKitLifecycle` | [docs/PASKitLifecycle.md](docs/PASKitLifecycle.md) | App-lifecycle UI — rate prompt, update check, what's-new, feedback, app-info footer. |
| `PASKitAnalytics` | [docs/PASKitAnalytics.md](docs/PASKitAnalytics.md) | PostHog facade — generic capture surface. |
| `PASKitPurchases` | [docs/PASKitPurchases.md](docs/PASKitPurchases.md) | RevenueCat facade — entitlement state, offerings/products, purchase + restore flow, identity. Apps own paywall UI + product/entitlement IDs. |
| `PASKitNotifications` | [docs/PASKitNotifications.md](docs/PASKitNotifications.md) | UNUserNotificationCenter facade — delegate plumbing, observable authorization, schedule/cancel primitives, tap routing. Apps own scheduling policy, copy, and navigation. |
| `PASKitSharing` | [docs/PASKitSharing.md](docs/PASKitSharing.md) | Share-card export — SwiftUI→image rendering, Instagram Stories hand-off, save-to-Photos, activity sheet, preview helpers. Apps own card designs, captions, and fallback policy. |

## Keeping Docs Current (mandatory)

The `docs/*.md` specs are the source of truth for each module. They must never drift from reality.

- When a module's **scope, design, or status** changes — in discussion or in code — update its `docs/<Module>.md` in the **same commit** as the change.
- When a module is **added or removed**, update the module table above in the same commit.
- A code change that contradicts a module's spec is **not done** until the spec is reconciled — fix the code or update the doc, never leave them disagreeing.
- An out-of-date spec is worse than no spec: it misleads the next session. Treat doc drift as a bug.

## Build Philosophy

PASKit is grown deliberately, not scaffolded upfront.

1. **Build on real need.** A module or feature is built when the *first real app* needs that capability — never speculatively. No module exists "for any future app" before one concrete app consumes it.
2. **Design app-agnostic from line one.** Even when extracted from one app, code is written as library code — no app-specific strings, types, colours, or assumptions baked in.
3. **Mechanism, not vocabulary.** PASKit owns the generic mechanism; each app owns its specific vocabulary and config, injected at the call site. (Template: the rate-prompt helper — generic prompt logic in the helper, trigger thresholds supplied by the caller.)
4. **Extract from shipped apps, then generalise.** Prefer lifting proven code from a shipped app over designing in the abstract. Survey the real implementation first.
5. **Wrap third-party SDKs thinly.** RevenueCat and PostHog are wrapped as concrete facades for ergonomics — not behind swap-protocols. PASKit does not pretend it will change vendors.

## Package Structure

One Swift package, one library product per module, so an app imports only what it needs (an app that takes no payment never links RevenueCat). `Package.swift` is added when the first module is built — not before.

## Git

- Remote: `https://github.com/moritztucher/PASKit.git`.
- Work on `develop`; `main` is the release branch.
- Commit only files related to a single concern.

## License

MIT — © 2026 Moritz Tucher. See `LICENSE`.
