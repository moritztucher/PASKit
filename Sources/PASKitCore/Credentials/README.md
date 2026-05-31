# Credentials

Keychain-backed credential storage with per-source service scoping.

## API

- `CredentialVault` — protocol contract.
- `KeychainCredentialVault` — `KeychainAccess`-backed implementation; `baseService` defaults to the bundle id.

## Example

```swift
let vault = KeychainCredentialVault()
try vault.set("token", source: "posthog", key: "apiKey")
let token = try vault.get(source: "posthog", key: "apiKey")
```
