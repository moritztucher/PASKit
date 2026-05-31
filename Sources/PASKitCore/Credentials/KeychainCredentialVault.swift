//
//  KeychainCredentialVault.swift
//  PASKitCore
//
//  `CredentialVault` backed by KeychainAccess, scoped per source. Each source
//  gets its own Keychain service name (`<base>.<source>`) so one source's
//  credentials never collide with another's. Items are marked synchronizable
//  so they ride iCloud Keychain across the user's devices.
//

import Foundation
import KeychainAccess

public struct KeychainCredentialVault: CredentialVault {
    /// Base prefix for the keychain service name. Per-source vaults append the
    /// source id, e.g. `studio.pocketapps.myapp.posthog`. Defaults to the app's
    /// bundle identifier.
    private let baseService: String

    public init(baseService: String = AppInfo.bundleIdentifier) {
        self.baseService = baseService
    }

    public func get(source: String, key: String) throws -> String? {
        try keychain(for: source).get(key)
    }

    public func set(_ value: String, source: String, key: String) throws {
        try keychain(for: source).set(value, key: key)
    }

    public func remove(source: String, key: String) throws {
        try keychain(for: source).remove(key)
    }

    public func removeAll(source: String) throws {
        try keychain(for: source).removeAll()
    }

    private func keychain(for source: String) -> Keychain {
        // `.whenUnlocked` (not `…ThisDeviceOnly`) is required for iCloud
        // Keychain sync — otherwise `synchronizable(true)` is silently a no-op.
        Keychain(service: "\(baseService).\(source)")
            .accessibility(.whenUnlocked)
            .synchronizable(true)
    }
}
