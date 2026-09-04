//
//  HealthPermissionTests.swift
//  PASKitHealthTests
//
//  Constructing HKObjectType / HKQuantityType / HKCharacteristicType needs no
//  HKHealthStore and no entitlement, so this runs on the bundle-less macOS
//  test host. Never construct PASHealth.shared here — that constructs an
//  HKHealthStore, which the plan explicitly keeps out of unit tests.
//

import HealthKit
import Testing
@testable import PASKitHealth

@Suite("PASHealthPermission")
struct HealthPermissionTests {

    @Test("Equality and hashing are by id only")
    func equalityIsByIDOnly() {
        let a = PASHealthPermission(id: "x", read: HKQuantityType(.bodyMass))
        let b = PASHealthPermission(id: "x", read: HKQuantityType(.height))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("requestsRead / requestsWrite reflect which sides are set")
    func requestsReadWrite() {
        let bodyMass = HKQuantityType(.bodyMass)
        let readOnly = PASHealthPermission(id: "r", read: bodyMass, write: nil)
        let writeOnly = PASHealthPermission(id: "w", read: nil, write: bodyMass)
        let readWrite = PASHealthPermission(id: "rw", read: bodyMass, write: bodyMass)

        #expect(readOnly.requestsRead && !readOnly.requestsWrite)
        #expect(!writeOnly.requestsRead && writeOnly.requestsWrite)
        #expect(readWrite.requestsRead && readWrite.requestsWrite)
    }

    @Test(".quantity yields matching read/write types and defaults id to the identifier's rawValue")
    func quantityConvenience() {
        let readWrite = PASHealthPermission.quantity(.bodyMass)
        #expect(readWrite.id == HKQuantityTypeIdentifier.bodyMass.rawValue)
        #expect(readWrite.readType == HKQuantityType(.bodyMass))
        #expect(readWrite.writeType == HKQuantityType(.bodyMass))

        let readOnly = PASHealthPermission.quantity(.height, access: .read)
        #expect(readOnly.readType != nil)
        #expect(readOnly.writeType == nil)

        let custom = PASHealthPermission.quantity(.bodyMass, permissionID: "weight")
        #expect(custom.id == "weight")
    }

    @Test(".characteristic is read-only with no write type")
    func characteristicConvenience() {
        let dob = PASHealthPermission.characteristic(.dateOfBirth)
        #expect(dob.id == HKCharacteristicTypeIdentifier.dateOfBirth.rawValue)
        #expect(dob.readType != nil)
        #expect(dob.writeType == nil)
    }

    @Test(".workouts defaults to readWrite with id \"workouts\"")
    func workoutsConvenience() {
        let workouts = PASHealthPermission.workouts()
        #expect(workouts.id == "workouts")
        #expect(workouts.requestsRead && workouts.requestsWrite)

        let readOnly = PASHealthPermission.workouts(permissionID: "history", access: .read)
        #expect(readOnly.id == "history")
        #expect(readOnly.requestsRead && !readOnly.requestsWrite)
    }

    @Test("Read/write type-set derivation de-duplicates a shared type across permissions")
    func typeSetDerivationDeduplicates() {
        let bodyMass = HKQuantityType(.bodyMass)
        let permissions = [
            PASHealthPermission(id: "a", read: bodyMass, write: bodyMass),
            PASHealthPermission(id: "b", read: bodyMass, write: nil),
        ]
        #expect(PASHealth.readTypes(from: permissions) == [bodyMass])
        #expect(PASHealth.writeTypes(from: permissions) == [bodyMass])
    }

    @Test("Read/write type-set derivation is empty for an empty permission list")
    func typeSetDerivationEmpty() {
        #expect(PASHealth.readTypes(from: []).isEmpty)
        #expect(PASHealth.writeTypes(from: []).isEmpty)
    }
}
