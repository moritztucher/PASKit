# Update

App Store version check + update-prompt sheet.

## API

- `VersionCheckManager` — `@MainActor public final class`; hits `https://itunes.apple.com/lookup?bundleId=...`, compares against `AppInfo.version` (major.minor only — patch differences ignored).
- `AppUpdateView` — SwiftUI sheet (self-sets `.presentationDetents([.medium])` and shows a drag indicator when dismissible). `forceUpdate: Bool = false` controls dismissibility — reserve `true` for security releases.

## Example

```swift
@State private var update: VersionCheckManager.Result?

var body: some View {
    Content()
        .task { update = await VersionCheckManager().checkIfAppUpdateAvailable() }
        .sheet(item: $update) { AppUpdateView(update: $0) }
}
```
