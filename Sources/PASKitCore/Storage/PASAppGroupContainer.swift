//
//  PASAppGroupContainer.swift
//  PASKitCore
//
//  App Group container plumbing — resolve the shared container, build store
//  file URLs in it, and one-time-migrate an existing store (with its sidecar
//  files) from the app's default location so an extension/widget can read it.
//  Store-engine agnostic: the same logic serves Realm, SQLite, a SwiftData
//  store, or a JSON cache.
//

import Foundation

public enum PASAppGroupError: Error, LocalizedError {
    /// The App Group container could not be resolved — almost always a
    /// missing/mismatched App Groups entitlement, not a runtime condition.
    case containerUnavailable(identifier: String)

    public var errorDescription: String? {
        switch self {
        case .containerUnavailable(let identifier):
            return "App Group container '\(identifier)' is unavailable — check the App Groups entitlement on the app and its extensions."
        }
    }
}

/// A shared App Group container for store files read across the app and its
/// extensions (widgets, Live Activities).
///
/// ```swift
/// let container = try PASAppGroupContainer(identifier: "group.studio.pocketapps.cortex")
/// let storeURL = container.url(for: "cortex.realm")
/// try container.migrateStore(
///     from: Realm.Configuration.defaultConfiguration.fileURL!,
///     to: storeURL,
///     sidecarExtensions: ["realm.lock", "realm.note", "realm.management"]
/// )
/// // app then builds its own store config pointed at storeURL
/// ```
public struct PASAppGroupContainer {
    /// Root URL of the shared App Group container.
    public let containerURL: URL

    private let log = PASLogger.make(category: "app-group")

    /// - Throws: `PASAppGroupError.containerUnavailable` when the entitlement
    ///   is missing or the identifier is wrong.
    public init(identifier: String) throws {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            throw PASAppGroupError.containerUnavailable(identifier: identifier)
        }
        self.containerURL = url
    }

    /// URL for a named file inside the container.
    public func url(for fileName: String) -> URL {
        containerURL.appendingPathComponent(fileName)
    }

    /// One-time-migrates a store from `source` into the container at
    /// `destination`, copying the main file and any sidecar files.
    /// Idempotent: copies only when `source` exists and `destination` does
    /// not, so it's safe to call on every launch. A failed sidecar copy is
    /// logged but does not abort the migration (the main file is what
    /// matters); a failed main-file copy throws.
    ///
    /// - Parameters:
    ///   - source: Current store location (e.g. the engine's default URL).
    ///   - destination: Target URL in the container, from `url(for:)`.
    ///   - sidecarExtensions: Extensions of companion files/directories that
    ///     travel with the store — e.g. `["realm.lock", "realm.note",
    ///     "realm.management"]` for Realm, `["sqlite-wal", "sqlite-shm"]`
    ///     for SQLite/SwiftData. Each is resolved by replacing the store's
    ///     extension. `copyItem` handles both files and directories.
    public func migrateStore(
        from source: URL,
        to destination: URL,
        sidecarExtensions: [String] = []
    ) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path),
              !fileManager.fileExists(atPath: destination.path) else {
            return
        }

        log.info("migrating store into App Group container")
        try fileManager.copyItem(at: source, to: destination)

        let base = source.deletingPathExtension()
        let destinationBase = destination.deletingPathExtension()
        for ext in sidecarExtensions {
            let sidecar = base.appendingPathExtension(ext)
            guard fileManager.fileExists(atPath: sidecar.path) else { continue }
            let target = destinationBase.appendingPathExtension(ext)
            do {
                try fileManager.copyItem(at: sidecar, to: target)
            } catch {
                log.error("sidecar copy failed for .\(ext, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
