//
//  PASHealth+Reading.swift
//  PASKitHealth
//
//  Reads never gate on authorization and never throw. `nil` / `[]` means
//  "unavailable, denied, or genuinely empty" — HealthKit gives no signal
//  that would let a caller tell those apart, so this facade doesn't
//  pretend to either.
//

import HealthKit

extension PASHealth {

    /// `NSPredicate` excluding samples this app itself wrote. Compose it into
    /// `samples(_:)` predicates when the app also writes the same type, or
    /// its own data comes back to a read as an "import". A no-op to compose
    /// for an app that never writes.
    public var excludingOwnSamples: NSPredicate {
        NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: .default()))
    }

    /// The most recent sample of a quantity type, by `endDate`. Own-source
    /// samples are excluded by default — flip `includeOwnSamples` for an
    /// app that never writes the type (a no-op there) or that wants its own
    /// writes back.
    public func latestQuantitySample(
        _ type: HKQuantityType,
        includeOwnSamples: Bool = false
    ) async -> HKQuantitySample? {
        let filter: NSPredicate? = includeOwnSamples ? nil : excludingOwnSamples
        let predicate = HKSamplePredicate.quantitySample(type: type, predicate: filter)
        return await samples(predicate, limit: 1).first
    }

    /// Convenience over `latestQuantitySample(_:includeOwnSamples:)` that
    /// resolves the value in the given unit.
    public func latestQuantity(
        _ type: HKQuantityType,
        unit: HKUnit,
        includeOwnSamples: Bool = false
    ) async -> Double? {
        await latestQuantitySample(type, includeOwnSamples: includeOwnSamples)?.quantity.doubleValue(for: unit)
    }

    /// Generic sample read over a typed predicate — the escape hatch for
    /// list reads this facade doesn't have vocabulary for (e.g. "strength
    /// workouts since a date"). PASKit holds no activity-type or other
    /// domain vocabulary; compose the predicate (and `excludingOwnSamples`,
    /// if relevant) at the call site.
    public func samples<S: HKSample>(
        _ predicate: HKSamplePredicate<S>,
        sortDescriptors: [SortDescriptor<S>] = [SortDescriptor(\.endDate, order: .reverse)],
        limit: Int? = nil
    ) async -> [S] {
        guard isAvailable else { return [] }
        let descriptor = HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: sortDescriptors, limit: limit)
        do {
            return try await descriptor.result(for: store)
        } catch {
            log.error("PASHealth.samples read failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    /// The user's biological sex, or `nil` when unavailable, denied, or the
    /// user has not set it (`.notSet`) — all three collapse to the same
    /// "nothing to show" value on purpose.
    public func biologicalSex() -> HKBiologicalSex? {
        guard isAvailable else { return nil }
        do {
            let sex = try store.biologicalSex().biologicalSex
            return sex == .notSet ? nil : sex
        } catch {
            log.error("PASHealth.biologicalSex read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The user's date-of-birth components, or `nil` when unavailable,
    /// denied, or unset.
    public func dateOfBirthComponents() -> DateComponents? {
        guard isAvailable else { return nil }
        do {
            return try store.dateOfBirthComponents()
        } catch {
            log.error("PASHealth.dateOfBirthComponents read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
