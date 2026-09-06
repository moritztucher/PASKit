//
//  PASAuthNonce.swift
//  PASKitAuth
//
//  Firebase's canonical nonce pair for Sign in with Apple. The raw nonce goes
//  to Firebase and the SHA256 of it goes to Apple; Firebase then checks that the
//  identity token Apple signed carries the hash of the raw value it was given.
//  That is what stops a captured identity token being replayed.
//

import CryptoKit
import Foundation

/// Nonce generation for Sign in with Apple. Internal — apps get a prepared
/// nonce from `PASAuth.prepareAppleSignIn()` rather than making one.
enum PASAuthNonce {

    /// A cryptographically-random string from Apple's documented charset.
    ///
    /// Draws 16 bytes at a time and keeps only those below the charset size, so
    /// every character is uniformly distributed — taking a modulus instead would
    /// bias the low end of the alphabet.
    static func random(length: Int = 32) -> String {
        precondition(length > 0, "Nonce length must be positive.")
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                fatalError("SecRandomCopyBytes failed with status \(status)")
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// Lowercase hex SHA256 — the form Apple's `request.nonce` expects.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
