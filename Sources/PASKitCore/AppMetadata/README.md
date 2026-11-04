# AppMetadata

Static, app-agnostic access to bundle and device metadata.

## API

- `AppInfo` — `version`, `build`, `versionWithBuild`, `displayName`, `bundleIdentifier`.
- `DeviceInfo` — `modelIdentifier` (all platforms); `systemName`, `systemVersion`, `model`, `summary` (iOS-only).
- `PASDistribution` — `.appStore` / `.testFlight` / `.development` / `.unknown`; `isAppStore`, `analyticsValue`.
- `AppInfo.distribution(timeout:)` — async, memoised, never throws; reads StoreKit 2 `AppTransaction`.
- `AppInfo.lastKnownDistribution` — previous resolution for this exact build (hint only; the fresh `distribution()` wins).

## Example

```swift
import PASKitCore

print(AppInfo.versionWithBuild)   // "1.2 (45)"
print(DeviceInfo.modelIdentifier) // "iPhone16,1"

// Gate analytics / crash reporting on App Store installs only.
if await AppInfo.distribution().isAppStore { /* start SDKs (still behind consent) */ }
```
