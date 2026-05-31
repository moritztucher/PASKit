# Errors

Shared error domain used across PASKit modules.

## API

- `PASError` — `.networkUnreachable`, `.requestFailed(statusCode:body:)`, `.rateLimited(retryAfter:)`, `.decodingFailed(description:)`, `.cancelled`, `.unexpected(description:)`.

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
