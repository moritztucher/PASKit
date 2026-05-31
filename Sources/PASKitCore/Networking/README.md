# Networking

The networking seam — callers build `URLRequest`s and call `send`, never touching `URLSession` directly.

## API

- `NetworkService` — protocol contract.
- `URLSessionNetworkService` — default `URLSession`-backed implementation (2xx handling, 429/Retry-After, decode → `PASError`).
- `URLRequest.cURL(pretty:)` — render a request as a paste-ready `curl` command for terminal replay.

## Example

```swift
let service = URLSessionNetworkService()
let user: User = try await service.send(request, as: User.self)

// Debugging — log a failing request and replay it in a terminal:
log.error("\(request.cURL(pretty: true), privacy: .public)")
```
