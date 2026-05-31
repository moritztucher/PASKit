# Logging

Thin facade over `os.Logger`. Logs surface in Console.app and the Logging instrument in Instruments.

## API

- `PASLogger.make(category:)` — returns a logger scoped under the app's bundle id (via `AppInfo`) and the given category. No bootstrap step.

## Example

```swift
import PASKitCore

private let log = PASLogger.make(category: "purchases")

log.info("user \(id, privacy: .public) signed in")
log.error("purchase failed: \(error.localizedDescription, privacy: .public)")
```

`os.Logger`'s privacy modifier defaults to `.private` (redacted in release) for `String` and custom types — opt into `.public` only for non-sensitive values.
