# Haptics — notes

Internal notes / things to revisit. Not user-facing — see the DocC catalog for usage.

## `View.hapticOnTap` vs. `.sensoryFeedback`

**Noted 2026-05-31.**

PASKit's `View.hapticOnTap` uses `.simultaneousGesture(TapGesture)` — workable, but iOS 17+ ships `.sensoryFeedback(_:trigger:)` as the proper SwiftUI-native haptic primitive (trigger-driven, declarative).

PASKit's wrapper is more ergonomic for the "haptic + action" combo but trades SwiftUI purity for one-call convenience. Worth a look when we revisit Haptics — not a bug, more an "are we using the right Apple-blessed API."
