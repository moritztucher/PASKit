# PASKitAnalytics

**Status:** Scaffolded — target + PostHog dependency wired (`Sources/PASKitAnalytics/`). Module API not yet written.
**Build trigger:** When the first app needs analytics. Also unblocks XueTang (see below).
**Dependencies:** `PostHog` SDK (`posthog-ios`, from 3.48.3) + `PASKitCore`.

## Purpose

A thin, concrete facade over PostHog. PostHog is the committed studio analytics vendor — this is **not** a vendor-agnostic protocol (one conformer forever is a YAGNI tax). Apps call the PASKit facade, not `PostHogSDK` directly.

## Scope — mechanism only

PASKit owns the generic **mechanism**:
- `configure(apiKey:)` — key injected, not read from Info.plist.
- `identify` / `register` (super properties) / `reset`.
- A generic `capture(event:properties:)`.

Each app owns its **vocabulary** — its typed `captureXxx` methods, as a thin extension over `capture`. Event names and domain types never enter PASKit. (XueTang's `PostHogService` has 35 typed methods that are 100% XueTang vocabulary — those stay in XueTang.)

## Design decisions

- **Concrete facade, no protocol.** Wrapped for ergonomics + one chokepoint, not for swappability.
- **API key injected** via `configure(apiKey:)`. XueTang's `APIKeys.posthogKey` Info.plist reach-out does not travel.
- **Session replay** — a `configure` parameter, **default OFF**. XueTang runs it on globally; replay has cost + privacy weight, opt in per app.
- **DEBUG** — analytics disabled in DEBUG by default (XueTang's `#if !DEBUG` instinct), overridable via an `enabled:` flag.
- **Unified identity** — `identify` consumes the same user ID as `PASKitPurchases.logIn`, so analytics and revenue join on one key.
- **Feature flags / experiments — deferred.** PostHog supports them; no PAS app uses one. Add when an app needs a remote flag.

## Unblocks XueTang

XueTang's `LessonAnalytics.swift` and `QuickReviewAnalytics.swift` are dead `os_log` shims explicitly waiting for a generic `capture(event:properties:)` surface `PostHogService` never grew. `PASKitAnalytics` *is* that surface — so this is the one module where retrofitting XueTang onto PASKit has real return.

## Extraction sources

- `XueTang/XueTangApp/Core/API (External)/PostHog/PostHogService.swift` — extract the ~50 lines of plumbing only (setup, identify, register, reset, release-only guard); leave the 35 typed methods app-side.

## What needs to be done

- [ ] Build the facade — `configure`, `identify`, `register`, `reset`, `capture`.
- [ ] Session-replay + `enabled` config parameters.
- [ ] Wire `identify` to the shared `PASKitPurchases` identity.
