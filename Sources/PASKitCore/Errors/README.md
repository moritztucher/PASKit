# Errors

Shared error domain used across PASKit modules.

## API

- `PASError` — `.missingCredentials(source:)`, `.invalidCredentials(source:)`, `.networkUnreachable`, `.requestFailed(statusCode:body:)`, `.decodingFailed(description:)`, `.rateLimited(retryAfter:)`, `.cancelled`, `.unexpected(description:)`.
- `PASError.localizer` — process-wide, optional `PASErrorLocalizer` (`@Sendable (PASError) -> String?`). Set once at launch; every `errorDescription` / `localizedDescription` read afterwards runs through it. Read per call, so a `String(localized:bundle:)` body follows a runtime bundle/language switch.
- `PASError.developerDescription` — PASKit's English, developer-facing text. Never localized; what `errorDescription` returns when `localizer` is unset or returns `nil` for that case.

## Example

```swift
do {
    let user: User = try await service.send(request, as: User.self)
} catch PASError.networkUnreachable {
    showOfflineUI()
} catch PASError.rateLimited(let retryAfter) {
    schedule(retryAfter: retryAfter ?? 60)
}
```

At launch, install app copy so `error.localizedDescription` reads correctly wherever it's caught:

```swift
PASError.localizer = { error in
    switch error {
    case .networkUnreachable:
        String(localized: "No internet connection.")
    case .rateLimited:
        String(localized: "Too many requests. Please try again shortly.")
    default:
        nil   // fall back to developerDescription
    }
}
```
