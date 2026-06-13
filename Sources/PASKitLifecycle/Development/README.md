# Development

DEBUG-only in-app dev menu — a floating "DEV" capsule and a menu container. Release builds compile the overlay to a no-op; menu contents stay per-app.

## API

- `View.pasDevelopmentOverlay(alignment:menu:)` — floating DEV capsule presenting the menu as a sheet. No-op in release (the modifier body is `self`), but the menu closure must still compile — gate DEBUG-only menu types *inside* the closure.
- `PASDevelopmentMenu(title:content:)` — `NavigationStack` + `Form` + Done container; sections are the app's toggles, demo seeds, resets, and mock-screen links.

## Example

```swift
ContentView().pasDevelopmentOverlay {
    #if DEBUG
    PASDevelopmentMenu {
        Section("Runtime state") { Toggle("Premium", isOn: $state.isPremium) }
        Section("Persisted state") { Button("Reset", role: .destructive) { state.resetAll() } }
    }
    #endif
}
```

TestFlight builds are release config — testers never see the capsule.
