# ADR-0003 — Error copy is app vocabulary: `PASError.localizer`

**Status:** Accepted — drafted and implemented 2026-09-04.

## Context

`PASError.errorDescription` shipped as a hardcoded English `switch` (action-plan **P6**). A survey
of the three consuming apps (`grep -rn "PASError"`, zero hits in any app) found that no app names,
switches over, or constructs `PASError` — every catch site does the idiomatic thing, `catch { show
(error.localizedDescription) }` on `any Error`. One of those catch sites is live: XueTangV2's
`XTFeedbackSheet.swift:173` renders `error.localizedDescription` in an alert, and Release-build
feedback submission goes through `URLSessionNetworkService` (`FeedbackService.swift:22-25`), which
throws only `PASError`. XueTang ships 7 languages (de/en/es/fr/ja/ko/ru); a feedback-submission
failure showed English `PASError` copy regardless of the user's language. This is not merely a
soft-block on future adopters — it is a live, if narrow, leak in the most-localized app today.

This bounds the fix: it must work at the `error.localizedDescription` call site, because that is
the only pattern in the field. Any design that requires `catch let e as PASError` first fixes
nothing that exists in any app.

## Options considered

**A. Ship a string catalog inside PASKit.** Rejected. Contradicts the one convention every PASKit
view already follows (`CLAUDE-INTEGRATION.md`: "PASKit ships no string catalog, so pass
already-localized text") — `PASAppRatingCopy` and `PASAppFeedbackCopy` both take caller strings for
the same reason: *which* wording a failure deserves, and in what language set, is app policy.
PASKit would also have to track the union of every app's languages forever, and — specific to
XueTang — `Bundle.module` resolves against the process locale, not `XTLocalization.bundle`, so a
mid-session language switch would leave PASKit's errors in the old language: the exact class of bug
this decision exists to avoid.

**B. Drop `LocalizedError`; typed reason only, app switches exhaustively.** Rejected as the sole
change. It makes the observed leak *worse*: a plain `Error` enum's synthesized
`localizedDescription` is `"The operation couldn't be completed. (PASKitCore.PASError error 3.)"` —
an NSError code dump, not even English prose. Every app's `catch { error.localizedDescription }`
site stays exactly as un-localized as today, because the pattern in the field is `any Error`, which
a typed-switch-only design has no lever to reach. Its good idea — "the app owns the words" —
survives in the chosen option: the installed closure *is* the exhaustive switch, run once,
centrally, instead of at every catch site.

**C. Injectable rendering with an English developer-tone default. Chosen.** `PASError.localizer`
is a process-wide, optional `@Sendable (PASError) -> String?` read on every `errorDescription`
access (not captured once), so a runtime bundle/language switch is honoured. With no localizer
installed, `errorDescription` returns `developerDescription` — stable English, developer-tone text
kept for logs and tests. This fixes the actual pattern: once an app installs a localizer, every
`error.localizedDescription` on a `PASError` anywhere in the process returns app copy, without
touching a single catch site.

A copy-struct variant of C (`PASErrorCopy`, mirroring `PASAppRatingCopy`'s shape of plain `String`
fields) was rejected: `PASError` cases carry payloads (`statusCode`, `retryAfter`, `source`), so
struct fields would have to be format templates or closures regardless, and strings captured once
at configure time would freeze the language — wrong for XueTang's runtime bundle switch. A single
closure evaluated per read is simpler and correct where a captured struct is neither.

**D. Global hook vs. a per-call `error.message(using:)` API.** Global hook chosen. A `func
message(copy:)` instance method requires `catch let e as PASError` first — the same dead end as B.
The hook must be process-wide to reach `any Error` call sites that never import `PASKitCore` by
name. Concurrency uses `Synchronization.Mutex` (available at the package's iOS 18 / macOS 15
floor).

## Decision

1. `PASError.localizer: PASErrorLocalizer?` (`@Sendable (PASError) -> String?`), process-wide,
   backed by a `Mutex`. `nil` (default) or a per-case `nil` return falls back to
   `developerDescription`.
2. Fallback strings move to developer tone (`"Missing credentials for \(source)."` rather than
   `"Add credentials for \(source) in Settings to enable it."`) — the v0.4.0 release is already
   breaking, so the fallback is rewritten rather than kept byte-identical. Developer-tone text also
   stops a fallback that still reads as polished user copy from smuggling app vocabulary (a
   "Settings" screen PASKit cannot know exists) back into PASKit, and makes the contract
   self-evident the first time someone sees the text in a UI.
3. A one-shot `PASLogger` warning fires when `errorDescription` is read with no localizer installed
   **and** `Bundle.main.localizations.count > 1` — a nudge for the exact situation that produced the
   XueTang leak, without firing for single-localization apps. At most once per process.

No app names, switches over, or asserts on `PASError`'s strings (verified by grep across all three
app trees), so the fallback rewrite breaks zero call sites; only XueTang's feedback alert is
observably different, and only until it installs the localizer.

## Consequences

- Source- and behaviour-compatible for every existing catch site with no localizer installed:
  `errorDescription` still returns a `String`, just developer-tone rather than user-tone.
- The rule generalizes: any PASKit surface that emits user-visible text ships an English developer
  default and an injectable override, evaluated at render/read time, never captured once at
  configure. `PASAppRatingCopy`, `PASAppFeedbackCopy`, and now `PASError.localizer` are the three
  instances. The next session proposing a PASKit-shipped string catalog should be pointed at this
  ADR rather than re-litigating options A/B/C′/D.
- XueTang still has to do the work: install `PASError.localizer` (with `bundle:
  XTLocalization.bundle`) and add three keys × seven languages before its feedback-failure alert is
  actually localized. Tracked in `docs/audit/action-plan.md` P6.
