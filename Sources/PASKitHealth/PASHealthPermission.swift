//
//  PASHealthPermission.swift
//  PASKitHealth
//

import HealthKit

/// One HealthKit type the app requests. Drives the authorization request
/// and, through `PASHealth.writeAuthorization(for:)`, the only status
/// HealthKit will honestly report. Labels and icons are the app's
/// vocabulary — key your own enum by `id`, PASKit ships no strings.
public struct PASHealthPermission: Identifiable, Hashable, Sendable {
    public let id: String
    /// Type requested for reading, or `nil` for write-only (e.g. a derived
    /// value the app only pushes).
    public let readType: HKObjectType?
    /// Type requested for writing, or `nil` for read-only.
    public let writeType: HKSampleType?

    public init(id: String, read: HKObjectType? = nil, write: HKSampleType? = nil) {
        self.id = id
        self.readType = read
        self.writeType = write
    }

    public var requestsRead: Bool { readType != nil }
    public var requestsWrite: Bool { writeType != nil }

    // Equality/identity is by `id` only — two permissions naming the same
    // type set under different types are still "the same permission" to a
    // status lookup keyed by id.
    public static func == (lhs: PASHealthPermission, rhs: PASHealthPermission) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Which side(s) of a HealthKit type a permission requests.
public enum PASHealthAccess: Sendable {
    case read, write, readWrite
}

extension PASHealthPermission {
    /// Read and/or write of one quantity type. `permissionID` defaults to
    /// the identifier's `rawValue` (e.g. `"HKQuantityTypeIdentifierBodyMass"`).
    public static func quantity(
        _ identifier: HKQuantityTypeIdentifier,
        permissionID: String? = nil,
        access: PASHealthAccess = .readWrite
    ) -> PASHealthPermission {
        let type = HKQuantityType(identifier)
        let id = permissionID ?? identifier.rawValue
        switch access {
        case .read: return PASHealthPermission(id: id, read: type, write: nil)
        case .write: return PASHealthPermission(id: id, read: nil, write: type)
        case .readWrite: return PASHealthPermission(id: id, read: type, write: type)
        }
    }

    /// Read-only characteristic (sex, date of birth, blood type, …).
    /// Characteristics have no write side, so `access` is not a parameter.
    public static func characteristic(
        _ identifier: HKCharacteristicTypeIdentifier,
        permissionID: String? = nil
    ) -> PASHealthPermission {
        let type = HKCharacteristicType(identifier)
        return PASHealthPermission(id: permissionID ?? identifier.rawValue, read: type, write: nil)
    }

    /// Workouts. `HKWorkoutType` is both an `HKObjectType` (read) and an
    /// `HKSampleType` (write), so both sides use the same type.
    public static func workouts(
        permissionID: String = "workouts",
        access: PASHealthAccess = .readWrite
    ) -> PASHealthPermission {
        let type = HKObjectType.workoutType()
        switch access {
        case .read: return PASHealthPermission(id: permissionID, read: type, write: nil)
        case .write: return PASHealthPermission(id: permissionID, read: nil, write: type)
        case .readWrite: return PASHealthPermission(id: permissionID, read: type, write: type)
        }
    }
}
