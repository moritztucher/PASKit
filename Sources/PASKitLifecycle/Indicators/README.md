# Indicators

Generic, system-styled progress indicators. The fill comes from `.tint`; brand it at the call site.

## API

- `PASProgressRing` — circular progress (clamped 0…1, `size` / `lineWidth` / `trackColor`, optional `@ViewBuilder` center label, `-90°` start + `.round` cap, percentage accessibility, spring on change — Reduce Motion-aware, snaps instead). The circular sibling of `PASProgressBar`.
- `PASProgressBar` — slim capsule bar (clamped 0…1, `height` default 4, track `.quaternary`, fill `.tint`, percentage accessibility, ease on change — Reduce Motion-aware). Renamed from `PASOnboardingProgressBar`; the old name survives as a deprecated typealias.

## Example

```swift
PASProgressRing(progress: 0.75, lineWidth: 6) {
    Text("3/4").font(.caption.bold())
}
.tint(.brand)

PASProgressRing(progress: 0.3, size: 32, lineWidth: 3)   // bare ring, no label

PASProgressBar(progress: flow.progress)
    .tint(.brand)
```
