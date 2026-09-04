//
//  PASHealthWriteAuthorization.swift
//  PASKitHealth
//

import HealthKit

/// Aggregate of the app's *write* (sharing) authorization across every
/// configured permission that requests a write type. Write status is the
/// only authorization HealthKit reports honestly; there is deliberately no
/// read counterpart — a denied read looks identical to no data, so PASKit
/// never claims to know it.
public enum PASHealthWriteAuthorization: Sendable, Hashable {
    /// No write type has been decided yet — or the app requests no write
    /// types at all (a read-only app never observes anything else).
    case notDetermined
    /// At least one requested write type is authorized.
    case granted
    /// Every requested write type is denied, or Health data is unavailable
    /// on this device.
    case denied

    /// Pure derivation, exposed for testing. Empty input (no configured write
    /// types) → `.notDetermined`; an unavailable device → `.denied`
    /// regardless of `statuses`.
    static func derive(from statuses: [HKAuthorizationStatus], isAvailable: Bool) -> Self {
        guard isAvailable else { return .denied }
        guard !statuses.isEmpty else { return .notDetermined }
        if statuses.contains(.sharingAuthorized) { return .granted }
        if statuses.contains(.notDetermined) { return .notDetermined }
        return .denied
    }
}
