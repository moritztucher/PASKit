//
//  CredentialVault.swift
//  PASKitCore
//
//  Keychain abstraction for API keys / OAuth tokens. Items are scoped by a
//  `source` string and a `key` string. `KeychainCredentialVault` is the default
//  implementation.
//

import Foundation

public protocol CredentialVault: Sendable {
    /// Read a stored credential. Returns nil when no value exists.
    func get(source: String, key: String) throws -> String?

    /// Store (or overwrite) a credential.
    func set(_ value: String, source: String, key: String) throws

    /// Remove a single credential.
    func remove(source: String, key: String) throws

    /// Remove every credential for a source.
    func removeAll(source: String) throws
}
