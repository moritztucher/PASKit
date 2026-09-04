//
//  PASErrorTests.swift
//  PASKitCoreTests
//

import Foundation
import Testing
@testable import PASKitCore

/// `PASError.localizer` is process-global state, and Swift Testing parallelizes
/// suites by default — so this suite must run serialized, and every test that
/// installs a localizer must restore it afterwards.
@Suite("PASError", .serialized)
struct PASErrorTests {

    private static let allCases: [PASError] = [
        .missingCredentials(source: "posthog"),
        .invalidCredentials(source: "posthog"),
        .networkUnreachable,
        .requestFailed(statusCode: 503, body: "oops"),
        .decodingFailed(description: "bad JSON"),
        .rateLimited(retryAfter: 30),
        .cancelled,
        .unexpected(description: "something odd"),
    ]

    @Test("rateLimited formats the retry hint when known")
    func rateLimitedWithRetry() {
        #expect(PASError.rateLimited(retryAfter: 30).developerDescription == "Rate limited; retry after 30s.")
    }

    @Test("rateLimited falls back to a generic hint without a retry time")
    func rateLimitedWithoutRetry() {
        #expect(PASError.rateLimited(retryAfter: nil).developerDescription == "Rate limited.")
    }

    @Test("requestFailed surfaces the status code, not the body")
    func requestFailedStatus() {
        #expect(PASError.requestFailed(statusCode: 503, body: "secret").developerDescription == "Request failed: HTTP 503.")
    }

    @Test("Equatable distinguishes payloads")
    func equatable() {
        #expect(PASError.cancelled == .cancelled)
        #expect(PASError.requestFailed(statusCode: 500, body: "x") != .requestFailed(statusCode: 500, body: "y"))
    }

    @Test("developerDescription equals errorDescription with no localizer installed")
    func developerDescriptionMatchesErrorDescriptionByDefault() {
        PASError.localizer = nil
        for error in Self.allCases {
            #expect(error.errorDescription == error.developerDescription)
        }
    }

    @Test("localizer overrides errorDescription")
    func localizerOverridesErrorDescription() {
        PASError.localizer = { _ in "X" }
        defer { PASError.localizer = nil }
        #expect(PASError.networkUnreachable.errorDescription == "X")
    }

    @Test("localizer overrides localizedDescription through any Error")
    func localizerOverridesLocalizedDescriptionThroughAnyError() {
        PASError.localizer = { _ in "X" }
        defer { PASError.localizer = nil }
        let error: any Error = PASError.cancelled
        #expect(error.localizedDescription == "X")
    }

    @Test("localizer nil-return falls back per case")
    func localizerNilReturnFallsBackPerCase() {
        PASError.localizer = { $0 == .cancelled ? nil : "X" }
        defer { PASError.localizer = nil }
        #expect(PASError.cancelled.errorDescription == "Cancelled.")
        #expect(PASError.networkUnreachable.errorDescription == "X")
    }

    @Test("developerDescription ignores the installed localizer")
    func developerDescriptionIgnoresLocalizer() {
        PASError.localizer = { _ in "X" }
        defer { PASError.localizer = nil }
        #expect(PASError.requestFailed(statusCode: 503, body: nil).developerDescription == "Request failed: HTTP 503.")
    }

    @Test("localizer receives the payload")
    func localizerReceivesPayload() {
        PASError.localizer = { error in
            guard case .rateLimited(let retryAfter) = error else { return nil }
            return "retry \(retryAfter ?? -1)"
        }
        defer { PASError.localizer = nil }
        #expect(PASError.rateLimited(retryAfter: 30).errorDescription == "retry 30.0")
    }
}
