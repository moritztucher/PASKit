# Scripts

Repository tooling. Not shipped in any product; not part of PASKit's public API.

## `check-collisions.py`

Detects app declarations that collide with PASKit's public surface.

Every case of an app reimplementing something PASKit already ships — found across three apps by
the [consolidation audits](../docs/audit/) — was a **name collision with a shipped PASKit symbol**.
The dangerous shape is a local `extension View { func presentAppRating(…) }` in a file that
imports PASKit: Swift resolves same-module declarations first, so the app silently runs its own
copy and the call site looks identical either way.

Documentation failed to prevent this three times, so this makes it mechanical.

### Usage

```sh
python3 Scripts/check-collisions.py <app-root> [<app-root> …]
```

PASKit's surface is parsed from `Sources/` at run time, so there is no symbol list to maintain —
it cannot drift from the package. Only modules the scanned root actually imports are checked, and
roots that do not use PASKit are skipped.

Useful flags:

| Flag | Purpose |
|------|---------|
| `--paskit-rev REV` | Parse the surface from PASKit at a specific revision — use the app's pinned revision, not whatever is checked out locally |
| `--allowlist PATH` | Deliberate, justified exceptions (default: `.paskit-collisions-allow` in the scanned root) |
| `--format github` | Emit GitHub Actions annotations |
| `--self-check` | Verify the parser against PASKit's own sources |
| `--dump-surface [FILE]` | Print the parsed public surface |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | No collisions, or all of them allowlisted |
| `1` | At least one collision |
| `2` | Malformed allowlist — an entry without a justification |

### Allowlist format

One entry per line, and **a justification is mandatory** — an entry without one fails the run with
exit 2, so an exception always records why it exists:

```
extension View.presentAppRating -- shipped its own UserDefaults keys; blocked on PASKit key override
type AppInfo -- holds app-owned support/legal URLs PASKit has no equivalent for
```

### What it does not catch

Name collisions only. A semantic duplicate under a *different* name is invisible to it —
`CLLDesign`'s `PressScaleButtonStyle` versus PASKit's `PASPressableButtonStyle` is the known
example. Finding that class of duplication still needs a reading pass.
