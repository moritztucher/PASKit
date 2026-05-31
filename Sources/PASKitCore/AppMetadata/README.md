# AppMetadata

Static, app-agnostic access to bundle and device metadata.

## API

- `AppInfo` — `version`, `build`, `versionWithBuild`, `displayName`, `bundleIdentifier`.
- `DeviceInfo` — `modelIdentifier` (all platforms); `systemName`, `systemVersion`, `model`, `summary` (iOS-only).

## Example

```swift
import PASKitCore

print(AppInfo.versionWithBuild)   // "1.2 (45)"
print(DeviceInfo.modelIdentifier) // "iPhone16,1"
```
