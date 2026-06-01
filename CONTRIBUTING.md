# Contributing

Thanks for helping improve PASKit — a modular Swift Package for solo iOS founders and small studios. This guide covers how to propose changes: branch flow, commit format, and what a good PR looks like.

## Branch flow

- **Work on `develop`.** Branch off `develop` for your change.
- **All PRs target `develop`.** `main` is the release branch — protected, and only updated via maintainer release PRs (`develop → main`). If you open a PR from the GitHub website, check the base branch dropdown reads `develop`, not `main`.

## Commit messages

PASKit uses [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`.

```
feat(core): add URLRequest.cURL helper
fix(lifecycle): guard against double rate-prompt presentation
docs(analytics): document the event surface
ci: pin macOS runners to latest-stable Xcode
refactor: bucket sources by topic, one public type per file
```

- **type** — one of `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.
- **scope** *(optional)* — the module or area touched: `core`, `lifecycle`, `analytics`, `docs`, etc.
- **summary** — imperative, lower-case, no trailing period.
- One logical change per commit. Commit only files related to a single concern.
- When a module's **scope, design, or status** changes, update its `docs/<Module>.md` in the **same commit**. When the **public surface** changes (new module, new API, new convention), update `CLAUDE-INTEGRATION.md` in the same commit — it is the contract apps depend on.

## Building & testing

```bash
swift build
swift test
```

- Swift 6 toolchain, iOS 18+ / macOS 15+.
- SwiftLint runs as a build-tool plugin — keep the build warning-clean.
- CI builds on macOS and an iOS simulator and runs the test suite; make sure both `swift build` and `swift test` pass locally before opening a PR.

## Pull requests

- **Title:** Conventional Commit form — `type(scope): summary`, same as commits.
- **Body:** what changed and *why*; link any related issue (`Closes #12`).
- Keep the PR focused — one feature or fix. Build green and tests passing before opening.
- Update docs in the same PR when behaviour or the public surface changes (`docs/<Module>.md`, `CLAUDE-INTEGRATION.md`, DocC articles as relevant).

Significant design decisions are recorded in the repo's docs; follow the existing module structure and keep each public type in its own file.
