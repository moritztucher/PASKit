# ADR-0008: `PASKitCrash`, a Sentry facade with a hardcoded privacy floor, not in the umbrella

**Status:** Accepted, drafted and implemented 2026-10-21.

## Context

XueTang needs crash and error reporting before release. No PASKit module covered it. Sentry was
chosen as the vendor (EU region, `sentry-cocoa` 9.x): crash symbolication, app hang and watchdog
termination tracking, and release health in one SDK, with EU data residency.

Four questions had to be settled: where the integration lives, how consent is enforced, which
privacy-relevant options apps may change, and whether the umbrella re-exports it.

## Decision 1: a PASKit module, a thin concrete facade

Every studio app will want crash reporting, and the consent handling and privacy configuration are
identical across apps. That is mechanism, which PASKit owns; DSN, environment, tags and breadcrumb
categories stay app vocabulary. Per build philosophy rule 5 the facade is concrete over `SentrySDK`,
with no swap protocol. The dependency is
`.package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.30.2")`, product `Sentry`
(the pre-built static framework: fastest app start, no source compile under Swift 6 language mode).

## Decision 2: consent by never starting the SDK

Sentry has no "requires consent" mode. So the SDK is never started without consent: the app calls
`PASCrash.shared.start(_:)` only once its consent policy says yes, and `stop()` when consent is
withdrawn. Capture, breadcrumb and tag calls are no-ops while the SDK is not running, so call sites
need no consent check. This is the same rule as PASKitAnalytics in XueTang: no SDK before consent.

Known behaviour: `stop()` closes the SDK, but envelopes already cached on disk (for example a crash
captured before `stop`) are sent on the next `start` only, which means only after renewed consent.

## Decision 3: the privacy floor is hardcoded, not configurable

`sendDefaultPii`, screenshots, view hierarchy, session replay (both sample rates `0`), network
breadcrumbs, failed-request capture, user interaction tracing and Sentry logs are all off, and none
of them is exposed on `PASCrashConfig`. An app cannot turn them on by accident. Network breadcrumbs
are off because URLs can carry query parameters and tokens. Crash handler, app hangs, watchdog
terminations, release health sessions and lifecycle breadcrumbs stay at the SDK defaults.

The options are built in an `internal` `makeOptions(_:)` function so tests assert every flag without
starting the SDK. There is no user-identity API: XueTang sends no user ID, so account deletion never
involves Sentry.

## Decision 4: not re-exported by the umbrella

Same reasoning as ADR-0004 to ADR-0007, with a privacy-label twist. Linking Sentry ships its crash
handler code and its own `PrivacyInfo.xcprivacy` into every consumer. An app that links it then has
to declare crash data in its App Store privacy labels even if it never starts the SDK. Apps opt in
by adding the `PASKitCrash` product explicitly.

## Consequences

- dSYM upload is the app's job: `sentry-cli` in a build phase on Archive builds. Leaving
  `releaseName` at `nil` keeps the SDK default release name that `sentry-cli` uploads match.
- Each app's Sentry project should live in the EU region with *Prevent storing of IP addresses*
  turned on in its security settings.
- App code never imports `Sentry`; every call goes through `PASCrash`.
- Adding user identity, attachments or replay later is a deliberate API change with its own review,
  not a config switch.
