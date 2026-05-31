# Haptics

System haptic primitives with a caller-supplied enabled gate. iOS-only at the hardware level; macOS compiles to a no-op.

## API

- `PASHaptic` — primitive enum (`.light` / `.medium` / `.heavy` / `.rigid` / `.soft` / `.success` / `.warning` / `.error` / `.selection`).
- `Haptics.play(_:isEnabled:)` — one-call playback. Caller supplies the enabled gate (typically a user preference).
- `View.hapticOnTap(_:isEnabled:action:)` — SwiftUI sugar that fires the haptic on tap and runs the action.

PASKit ships no semantic aliases (no `.delete`, no `.habitCompleted`) — vocabulary stays in the app.

## Example

```swift
Haptics.play(.success, isEnabled: settings.hapticsEnabled)

Text("Mark Done")
    .hapticOnTap(.success) { markDone() }
```

See [`NOTES.md`](NOTES.md) for implementation notes.
