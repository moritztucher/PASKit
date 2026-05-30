# Build Philosophy

How PASKit grows, and how to think about adding to it.

## Overview

PASKit was extracted from production apps over twelve months. Five rules shape what earns a place — and what doesn't.

### 1. Build on real need

A module or feature is built when the *first real app* needs that capability — never speculatively. No module exists "for any future app" before one concrete app consumes it. PASKitPurchases is planned for v0.2.0 because the apps that need it aren't shipped yet.

### 2. Design app-agnostic from line one

Even when code is extracted from one app, it's written as library code — no app-specific strings, types, colours, or assumptions baked in. `WhatsNewView` takes the app name as a parameter; `FeedbackSheet` takes the categories and `onSubmit` transport.

### 3. Mechanism, not vocabulary

PASKit owns the generic mechanism; each app owns its specific vocabulary and config, injected at the call site. The rate-prompt helper supplies the two-stage alert flow; the app supplies the session-count thresholds. `PASAnalytics` ships `.capture(_:properties:)`; the app extends it with the typed event helpers.

### 4. Extract from shipped apps, then generalise

Prefer lifting proven code over designing in the abstract. The shimmer modifier, the multi-version changelog shape, the haptic primitives — all extracted from apps that actually shipped them. Speculative API design produces speculative-fit API.

### 5. Wrap third-party SDKs thinly

RevenueCat and PostHog are wrapped as concrete facades for ergonomics — not behind swap-protocols. PASKit does not pretend it will change vendors. `PASAnalytics` is a thin facade over `PostHogSDK`; if PostHog adds a method tomorrow, the app can reach `PostHogSDK.shared` directly without waiting for PASKit to mirror.

## What this means for contributors

Before opening a PR that adds something to PASKit:

1. Name the consuming app(s) that need it today.
2. Show how the API stays neutral when a second app adopts it with different vocabulary.
3. Update the relevant `docs/<Module>.md` spec in the same change.

A capability that only one app will ever use should live in that app, not here.
