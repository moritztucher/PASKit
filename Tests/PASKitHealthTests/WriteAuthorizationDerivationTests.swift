//
//  WriteAuthorizationDerivationTests.swift
//  PASKitHealthTests
//

import HealthKit
import Testing
@testable import PASKitHealth

@Suite("PASHealthWriteAuthorization")
struct WriteAuthorizationDerivationTests {

    @Test("Unavailable device is always denied, regardless of statuses")
    func unavailableIsAlwaysDenied() {
        #expect(PASHealthWriteAuthorization.derive(from: [.sharingAuthorized], isAvailable: false) == .denied)
        #expect(PASHealthWriteAuthorization.derive(from: [], isAvailable: false) == .denied)
        #expect(PASHealthWriteAuthorization.derive(from: [.sharingDenied], isAvailable: false) == .denied)
    }

    @Test("Empty statuses (a read-only app) are not determined")
    func emptyStatusesAreNotDetermined() {
        #expect(PASHealthWriteAuthorization.derive(from: [], isAvailable: true) == .notDetermined)
    }

    @Test("All notDetermined stays notDetermined")
    func allNotDetermined() {
        #expect(PASHealthWriteAuthorization.derive(from: [.notDetermined, .notDetermined], isAvailable: true) == .notDetermined)
    }

    @Test("Undetermined beats denied")
    func undeterminedBeatsDenied() {
        #expect(PASHealthWriteAuthorization.derive(from: [.sharingDenied, .notDetermined], isAvailable: true) == .notDetermined)
    }

    @Test("Any authorized type yields granted")
    func anyAuthorizedYieldsGranted() {
        #expect(PASHealthWriteAuthorization.derive(from: [.sharingDenied, .sharingAuthorized], isAvailable: true) == .granted)
        #expect(PASHealthWriteAuthorization.derive(from: [.notDetermined, .sharingAuthorized], isAvailable: true) == .granted)
    }

    @Test("All denied yields denied")
    func allDeniedYieldsDenied() {
        #expect(PASHealthWriteAuthorization.derive(from: [.sharingDenied, .sharingDenied], isAvailable: true) == .denied)
    }
}
