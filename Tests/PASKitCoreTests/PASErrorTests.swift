//
//  PASErrorTests.swift
//  PASKitCoreTests
//

import Foundation
import Testing
@testable import PASKitCore

@Suite("PASError")
struct PASErrorTests {

    @Test("rateLimited formats the retry hint when known")
    func rateLimitedWithRetry() {
        #expect(PASError.rateLimited(retryAfter: 30).errorDescription == "Rate limited — try again in 30s.")
    }

    @Test("rateLimited falls back to a generic hint without a retry time")
    func rateLimitedWithoutRetry() {
        #expect(PASError.rateLimited(retryAfter: nil).errorDescription == "Rate limited — try again shortly.")
    }

    @Test("requestFailed surfaces the status code")
    func requestFailedStatus() {
        #expect(PASError.requestFailed(statusCode: 503, body: nil).errorDescription == "Request failed with status 503.")
    }

    @Test("Equatable distinguishes payloads")
    func equatable() {
        #expect(PASError.cancelled == .cancelled)
        #expect(PASError.requestFailed(statusCode: 500, body: "x") != .requestFailed(statusCode: 500, body: "y"))
    }
}
