# Settings

Observable, UserDefaults-backed app preferences — one line per setting, no key enum or write-through boilerplate. Persistence stays local; the keys and defaults are the app's vocabulary.

## API

- `PASSettingsStore` — `@Observable open class` base. Subclass and declare settings. Holds the injected `UserDefaults` (`.standard`, or a suite for App Groups / tests); `removeValue(forKey:)` resets a setting to its declared default.
- `@PASDefault("key")` — write-through property wrapper on a `PASSettingsStore` subclass. The declared value is the fallback; optionals store `nil` as key absence.
- `UserDefaultsStorable` — round-trip protocol. Conformances: `Bool`, `Int`, `Double`, `String`, `Date`, `Data`, `URL`, `Optional`; `RawRepresentable` enums via an empty extension.
- `PASDraft<Value: Codable>` — one JSON-encoded in-progress value under a key (`save` / `load` / `clear`) — the "resume after kill" box for onboarding/forms.

## Example

```swift
@MainActor
final class SettingsStore: PASSettingsStore {
    @PASDefault("settings.hapticsEnabled") var hapticsEnabled = true
    @PASDefault("settings.weightUnit")     var weightUnit: WeightUnit =
        Locale.current.measurementSystem == .metric ? .kg : .lb
    @PASDefault("settings.customRest")     var customRest: Int?   // nil = key absent
}
extension WeightUnit: UserDefaultsStorable {}
```

Observation is per-store. App Group sharing / tests: `SettingsStore(defaults: UserDefaults(suiteName: "group.…")!)`. No swift-syntax macro — the cost is per-store (not per-key) invalidation, imperceptible at settings-store scale.
