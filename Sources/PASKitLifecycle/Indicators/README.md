# Indicators

Generic, system-styled progress indicators. The fill comes from `.tint`; brand it at the call site.

## API

- `PASProgressRing` — circular progress (clamped 0…1, `size` / `lineWidth` / `trackColor`, optional `@ViewBuilder` center label, `-90°` start + `.round` cap, percentage accessibility, spring on change). The circular sibling of `PASOnboardingProgressBar` (see [`../Onboarding/`](../Onboarding/)).

## Example

```swift
PASProgressRing(progress: 0.75, lineWidth: 6) {
    Text("3/4").font(.caption.bold())
}
.tint(.brand)

PASProgressRing(progress: 0.3, size: 32, lineWidth: 3)   // bare ring, no label
```
