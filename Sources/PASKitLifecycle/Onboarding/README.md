# Onboarding

Step engine + transition choreography for onboarding flows. PASKit owns the engine; the app owns step vocabulary, step views, and navigation chrome (the chrome diverged across every surveyed app — one had no nav buttons at all).

## API

- `PASOnboardingFlow<Step: Hashable>` — `@Observable @MainActor` index-based engine over a **live step-list closure** (conditional flows stay correct as answers change; static list via a convenience init). `current` / `count` / `isFirst` / `isLast`, `progress` (= `(index+1)/count`), `advance()` / `back()` (bounded), `go(to:)` (jump with direction from index comparison — draft resume), `direction`.
- `PASOnboardingDirection` — `.forward` / `.backward`.
- `View.pasOnboardingTransition(step:direction:animation:)` — `.id(step)` + direction-flipped asymmetric slide + animation.
- `PASOnboardingProgressBar` — slim capsule (track `.quaternary`, fill `.tint`).
- Resume-after-kill pairs with `PASDraft` (PASKitCore): hydrate answers **first**, then `flow.go(to: restoredStep)`.

## Example

```swift
@State private var flow = PASOnboardingFlow(steps: Step.allCases)   // or a closure for conditional steps

VStack(spacing: 0) {
    PASOnboardingProgressBar(progress: flow.progress).tint(.brand)
    stepContent(for: flow.current)
        .pasOnboardingTransition(step: flow.current, direction: flow.direction)
    bottomBar   // app's buttons → flow.advance() / flow.back()
}
```
