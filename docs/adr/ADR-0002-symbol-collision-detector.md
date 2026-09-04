# ADR-0002 — PASKit symbol-collision detector

**Status:** Accepted — drafted and implemented 2026-09-04.

## Context

Every app that adopted PASKit has, at least once, reimplemented something PASKit already ships —
and every instance was a **name collision with a shipped PASKit symbol**, not a coincidence:

- WorkoutApp declares `View.presentAppRating(initialCondition:askLaterCondition:)` in
  `AppRatingModifier.swift`, a file that `import`s PASKit. Swift resolves an unqualified name
  against the current module before an imported one, so the app has been silently running its own
  copy since the file started importing PASKit — the call site looks identical either way.
- XueTangV2 declares its own `AppInfo` (`Core/Configuration/AppInfo.swift`), shadowing
  PASKitCore's `AppInfo` for `version`/`build` while adding app-owned fields PASKit doesn't carry
  (`supportEmail`, `termsURL`, …).
- XueTangV2 declares `extension Animation { func respectingReducedMotion(_:) }` in `Theme.swift` —
  byte-identical to `PASKitCore`'s. Not caught by the audit that found the first two; found by this
  tool's own dry run.

Documentation (`CLAUDE-INTEGRATION.md` §7, "don't reinvent what PASKit owns") has failed to
prevent this three times. A mechanical check was proposed as action-plan **P8**.

## Decision

**1. Extract PASKit's public surface with a regex + brace-depth parser over `Sources/`, not a
compiler-backed route.** `swift symbolgraph-extract` and `swift package dump-symbol-graph` both
need a full macOS build of PASKit **and** its dependencies (RevenueCat, PostHog, KeychainAccess);
`dump-symbol-graph` failed outright under the machine's Xcode-beta toolchain during evaluation. A
build requirement is disqualifying for a check that must run in an app repo without Xcode, on
every push, in well under a second, and locally with no setup. The detector needs *names*, not
types — a superset (e.g. an API gated behind `#if canImport(UIKit)`) is an acceptable
over-approximation; false negatives from a stale symbol list are not, since the surface is
re-derived from source on every run instead of hand-maintained.

**2. The tool lives in PASKit (`Scripts/check-collisions.py`), not in the shared CI repo
(`ios-ci`) or duplicated per app.** The surface it parses is PASKit's own, so PASKit's CI can
self-test the parser against its own sources (`--self-check`) — the one place a parser regression
can be caught before it ships to every app. Local runs need no PAT or second private clone:
`python3 ../PASKit/Scripts/check-collisions.py <app-root>`, using the sibling checkout every app
already assumes (`@../PASKit/CLAUDE-INTEGRATION.md`). `ios-ci` carries only the thin reusable
workflow (checkout PASKit at the app's pin → run the script → annotate) — the same ~30 lines for
every app, which is what a shared CI repo is for.

**3. Rules compare by name, not by semantic equivalence.** A local top-level type or extension
member whose name (and, for functions/inits, whose argument-label sequence) matches a symbol
PASKit exports from a module the scanning root imports is a collision. Two severities:
   - **error** — a pure duplicate, a partial overlap (app-owned extras alongside PASKit-shadowing
     members), or an extension member whose labels equal or are a *prefix of* PASKit's (the
     `presentAppRating` shape: a shorter local signature can resolve against a longer PASKit one
     whose extra trailing labels have defaults — the exact danger that made this necessary).
   - **warning** — same type name, disjoint members ("name-only"); forces qualification but isn't
     a duplicate.

   Disjoint-label extension members (e.g. a local `Color.init(hex:)` next to PASKit's
   `Color.init(light:dark:)`) are **not** reported at all — they're legitimate, unambiguous Swift
   overloads with no call site that could resolve to either. An earlier version of this rule
   flagged any same-named extension member regardless of label overlap; it produced exactly one
   false positive in CoupleCalorieTracker (`Color.init(hex:)`) during verification, which is what
   surfaced the gap.

**4. Explicitly out of scope: semantic duplicates under a different name.**
`CLLDesign/PressScaleButtonStyle` versus PASKit's `PASPressableButtonStyle` is not a name
collision — different identifiers, same idea — and is invisible to this tool by construction. The
original P8 text ("would have caught all four") is corrected in `docs/audit/action-plan.md`: the
detector catches name collisions; a semantic-duplicate sweep is separate, unautomated work.

**5. Bootstrap in fail mode from the first commit, with a seeded, justified allowlist — never
warn-only.** A warning nobody is forced to act on is documentation with a different font, and
documentation is the thing that already failed three times. `.paskit-collisions-allow` seeds one
entry per known, deliberate collision (WorkoutApp's rating modifier, XueTangV2's `AppInfo` and
`Animation.respectingReducedMotion`), each citing the audit finding or the tool's own dry run.
**Every entry requires a justification after `--`; one without it fails the run with exit 2** —
enforced, not requested. A stale entry (nothing matched it) warns instead of erroring, so the
allowlist self-cleans as the underlying duplication is fixed.

**6. Release-ordering constraint: the reusable CI workflow checks out PASKit at the *app's pinned
revision*, so an app's pin must be at or after the release that first contains `Scripts/`.** All
three apps currently resolve PASKit `0.3.2` (pre-dates this tool). Until PASKit ships a release
containing `Scripts/check-collisions.py` and the apps repin to it, each app's caller workflow pins
`paskit-ref: develop` explicitly (the reusable workflow's escape hatch for exactly this case) —
tracked with a `TODO` to drop that override once the apps repin to the release that ships this
tool.

## Consequences

- No PASKit public-API change requires updating a symbol list anywhere — the surface is derived
  from `Sources/` every run. A parser that stops understanding a new declaration shape is the only
  failure mode, and PASKit's own CI (`--self-check` + `Scripts/tests/`) catches that before it
  reaches any app.
- CI for the check runs on `ubuntu-latest` in every app (no Xcode, no self-hosted Mac mini needed),
  in parallel with the existing build/test jobs.
- The three known collisions stay in place, deliberately, until their blocking work lands
  (PASKit's Rating module accepting a persisted-key override for WorkoutApp; a human decision on
  renaming XueTangV2's `AppInfo`; a follow-up PR deleting XueTangV2's duplicate
  `Animation.respectingReducedMotion`). This ADR does not fix them.
- `CLLDesign/PressScaleButtonStyle` remains an open, unautomated finding — a reading pass, not a
  CI gate, is the follow-up there.
