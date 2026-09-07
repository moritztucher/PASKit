//
//  PASAuthNonceTests.swift
//  PASKitAuthTests
//
//  Nonce generation and hashing are pure and are the one part of the Apple
//  flow that is security-relevant on its own — a biased or short nonce weakens
//  the replay protection it exists to provide. Never constructs PASAuth.shared
//  here: that reaches for Auth.auth(), which needs a configured FirebaseApp and
//  a real bundle.
//

import CryptoKit
import Foundation
import Testing
@testable import PASKitAuth

@Suite("PASAuthNonce")
struct PASAuthNonceTests {

    /// Apple's documented nonce alphabet.
    private static let charset = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    @Test("Generates the requested length")
    func respectsLength() {
        #expect(PASAuthNonce.random(length: 1).count == 1)
        #expect(PASAuthNonce.random().count == 32)
        #expect(PASAuthNonce.random(length: 200).count == 200)
    }

    @Test("Uses only Apple's charset")
    func staysInCharset() {
        let nonce = PASAuthNonce.random(length: 512)
        #expect(nonce.allSatisfy { Self.charset.contains($0) })
    }

    @Test("Successive nonces differ")
    func isRandom() {
        let nonces = Set((0..<64).map { _ in PASAuthNonce.random() })
        // 64 independent 32-character draws colliding would mean the generator
        // is not random at all; anything less than 64 distinct values is a bug.
        #expect(nonces.count == 64)
    }

    @Test("sha256 matches a known vector and is lowercase hex")
    func hashesToKnownVector() {
        // Canonical SHA256("abc").
        #expect(
            PASAuthNonce.sha256("abc")
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        let hash = PASAuthNonce.sha256(PASAuthNonce.random())
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test("sha256 agrees with CryptoKit for the value Apple is given")
    func hashMatchesCryptoKit() {
        let raw = PASAuthNonce.random()
        let expected = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        #expect(PASAuthNonce.sha256(raw) == expected)
    }
}
