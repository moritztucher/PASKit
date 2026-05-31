# Settings

Settings-screen primitives.

## API

- `AppInfoFooter` (iOS-only) — app icon + display name + version. Loads the app's own icon at runtime via `CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconFiles`.

## Example

```swift
Form {
    // … your settings rows …

    Section {
        AppInfoFooter()
    }
}
```
