# Loading

Loading-state overlay over a dimmed backdrop with a fade transition. Blocks underlying interaction while presented.

## API

- `View.loading(isPresented:message:)` — system-default `ProgressView` + optional caption.
- `View.loading(isPresented:content:)` — custom view (branded animation, determinate progress, app-icon ring).
- `DefaultLoadingView` — the default presentation, exposed so apps that want it with extra decoration can compose it directly.

## Example

```swift
// System default:
ContentView().loading(isPresented: $isLoading, message: "Signing in…")

// Branded:
ContentView().loading(isPresented: $isLoading) {
    MyBrandedLoadingView(progress: progress)
}
```

PASKit owns the mechanism (dim backdrop, fade transition, interaction-block); apps own the visual treatment via the `content:` variant.
