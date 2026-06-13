# Toast

Toast / snackbar lifecycle (placement, transition, auto-dismiss with correct re-arm) plus a default content row. The content can be `PASToast` or any app view.

## API

- `View.pasToast(isPresented:duration:alignment:content:)` and `View.pasToast(item:duration:alignment:content:)` — overlay placement (default `.bottom`), slide+fade transition (fade-only under Reduce Motion), auto-dismiss after `duration` (default 4s; `nil` = sticky). Dismiss runs on `.task(id:)`, so a new `item` restarts the timer — the stale-timer bug a bare `Task.sleep` causes can't happen. Use `item:` whenever consecutive triggers change content.
- `PASToast` — default row: optional SF symbol + tint, message, optional trailing action ("Undo"); `.ultraThickMaterial` with a Reduce Transparency solid fallback.

## Example

```swift
.pasToast(isPresented: $showUndo, duration: 5) {
    PASToast(message: "Habit completed", actionTitle: "Undo") { undo() }
}

// Content changes per trigger? Use item: — a new item restarts the timer:
.pasToast(item: $confirmation, duration: 2) {
    PASToast(symbol: "checkmark.circle.fill", symbolTint: .green, message: $0.text)
}
```

Apps with a locked design language pass their own view and share only the lifecycle.
