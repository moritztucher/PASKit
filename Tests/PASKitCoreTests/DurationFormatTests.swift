//
//  DurationFormatTests.swift
//  PASKitCoreTests
//

import Foundation
import Testing
@testable import PASKitCore

@Suite("PASDurationFormat")
struct DurationFormatTests {

    @Test("compact renders s / m s / h m", arguments: [
        (0, "0s"),
        (42, "42s"),
        (59, "59s"),
        (60, "1m 0s"),
        (252, "4m 12s"),
        (3_600, "1h 00m"),
        (3_780, "1h 03m"),
    ])
    func compact(seconds: Int, expected: String) {
        #expect(PASDurationFormat.compact(seconds: seconds) == expected)
    }

    @Test("clock renders m:ss / h:mm:ss", arguments: [
        (0, "0:00"),
        (42, "0:42"),
        (252, "4:12"),
        (3_600, "1:00:00"),
        (3_852, "1:04:12"),
    ])
    func clock(seconds: Int, expected: String) {
        #expect(PASDurationFormat.clock(seconds: seconds) == expected)
    }

    @Test("negative inputs clamp to zero")
    func negativeClamps() {
        #expect(PASDurationFormat.compact(seconds: -5) == "0s")
        #expect(PASDurationFormat.clock(seconds: -1) == "0:00")
    }

    @Test("fractional seconds round to the nearest second")
    func roundsToNearestSecond() {
        #expect(PASDurationFormat.compact(seconds: 41.6) == "42s")
        #expect(PASDurationFormat.clock(seconds: 41.4) == "0:41")
    }
}
