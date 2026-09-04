//
//  PASHealth+Writing.swift
//  PASKitHealth
//
//  The honest half of the read/write asymmetry this module teaches: writes
//  may be gated on `writeAuthorization` (it is truthful) and do throw —
//  HealthKit reports write failures (including `.errorAuthorizationDenied`)
//  truthfully, unlike reads.
//

import HealthKit

extension PASHealth {

    /// Save one or more `HKObject`s. Throws on failure — most commonly
    /// `HKError.errorAuthorizationDenied` when the app hasn't been granted
    /// write access to the object's type.
    public func save(_ objects: [HKObject]) async throws {
        try await store.save(objects)
    }

    /// Save a point sample (`start == end == date`) for a quantity type —
    /// the shape every simple "log a weight/height/etc." write takes.
    /// Build an `HKQuantitySample` and call `save(_:)` directly for an
    /// interval sample.
    public func saveQuantity(
        _ type: HKQuantityType,
        value: Double,
        unit: HKUnit,
        date: Date,
        metadata: [String: Any]? = nil
    ) async throws {
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date, metadata: metadata)
        try await save([sample])
    }
}
