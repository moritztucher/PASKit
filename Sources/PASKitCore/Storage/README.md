# Storage

App Group container plumbing — store-engine-agnostic (Realm, SQLite, SwiftData, JSON cache). PASKit takes **no persistence dependency**; the store's config/schema/migration stays in the app.

## API

- `PASAppGroupContainer(identifier:)` — resolves a shared App Group container; throws `PASAppGroupError.containerUnavailable` when the entitlement is missing.
- `url(for:)` — build a store-file URL inside the container.
- `migrateStore(from:to:sidecarExtensions:)` — one-time-copy an existing store + its sidecar files/directories into the container. Idempotent (only when source exists and destination doesn't); a failed sidecar copy logs and continues, a failed main copy throws.

## Example

```swift
let container = try PASAppGroupContainer(identifier: "group.studio.pocketapps.app")
let storeURL = container.url(for: "app.store")
try container.migrateStore(
    from: existingDefaultStoreURL, to: storeURL,
    sidecarExtensions: ["sqlite-wal", "sqlite-shm"]   // Realm: ["realm.lock","realm.note","realm.management"]
)
// then point your own Configuration / ModelContainer at storeURL
```

The app and its widget/extension must use the **same** App Group identifier — a mismatch silently breaks sharing.
