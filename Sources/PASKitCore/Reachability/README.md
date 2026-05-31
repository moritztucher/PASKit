# Reachability

Network-state observer — drives offline UI and lets callers pause refreshes when offline.

## API

- `NetworkStatus` — `.unknown` / `.online` / `.offline`.
- `Reachability` — protocol contract.
- `NWReachability` — `@MainActor @Observable`, `NWPathMonitor`-backed implementation.

## Example

```swift
@State private var reachability = NWReachability()

var body: some View {
    Content()
        .onAppear { reachability.start() }
        .onDisappear { reachability.stop() }
        // observe reachability.status
}
```
