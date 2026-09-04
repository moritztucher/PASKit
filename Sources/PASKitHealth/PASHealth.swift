//
//  PASHealth.swift
//  PASKitHealth
//
//  Thin concrete facade over HKHealthStore — a convenience wrapper, not a
//  vendor abstraction. PASKit owns the mechanism (single store, descriptor-
//  driven authorization, honest write status, foreground refresh); each app
//  owns its vocabulary (which types it reads/writes, labels, icons, copy).
//
//  The read-authorization contract, read this before using the module:
//  HealthKit never tells an app whether a *read* grant was denied — a
//  denied read looks identical to no data. There is therefore no read
//  status anywhere on this type, on purpose. Reads return `nil` / `[]` for
//  "unavailable, denied, or empty" and the caller cannot and must not try
//  to tell those apart. Only *write* (sharing) authorization is reported
//  honestly, and only writes throw.
//

import HealthKit
import PASKitCore
#if canImport(UIKit)
import UIKit
#endif

/// HealthKit facade. Configure once at launch with every type the app will
/// ever request, then read the observable `writeAuthorization` to drive UI
/// and call the read/write methods directly — reads are never gated on
/// authorization because HealthKit gives no honest signal to gate on.
@MainActor
@Observable
public final class PASHealth {

    public static let shared = PASHealth()

    /// The app's single `HKHealthStore`. Exposed for HealthKit APIs this
    /// facade does not wrap (`HKWorkoutBuilder`, `HKStatisticsQueryDescriptor`,
    /// observer queries, …) — never create a second store; HealthKit expects
    /// exactly one per process.
    nonisolated public let store = HKHealthStore()

    /// Whether Health data is available on this device at all (`false` on a
    /// device without Health support, e.g. some iPads, and always `false` on
    /// the plain macOS test host). Every read and write is already guarded on
    /// this internally — callers do not need their own check before calling
    /// them, only before deciding whether to show Health-related UI at all.
    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Every type declared via `configure(permissions:)`.
    public private(set) var permissions: [PASHealthPermission] = []
    public private(set) var isConfigured = false

    /// Observable aggregate of *write* (sharing) authorization across every
    /// configured permission that requests a write type. Refreshed after
    /// `configure`, after `requestAuthorization`, on every iOS foreground
    /// return, and via `refreshWriteAuthorization()`. There is no read
    /// counterpart — see the type-level doc comment.
    public private(set) var writeAuthorization: PASHealthWriteAuthorization = .notDetermined

    let log = PASLogger.make(category: "health")
    @ObservationIgnored private var foregroundObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Configuration

    /// Declare every HealthKit type the app will ever request. Call once,
    /// early at launch. Idempotent — a second call logs a warning and no-ops,
    /// matching `PASNotifications.configure` / `PASPurchases.configure`.
    public func configure(permissions: [PASHealthPermission]) {
        guard !isConfigured else {
            log.warning("PASHealth.configure called twice — ignoring the second call.")
            return
        }
        self.permissions = permissions
        isConfigured = true
        refreshWriteAuthorization()
        #if canImport(UIKit)
        subscribeToForegroundRefresh()
        #endif
    }

    // MARK: - Authorization

    /// Presents the system permission sheet for the configured types (the
    /// system shows it at most once per type set — a second call is a no-op
    /// from the user's perspective if nothing changed). Never throws: a
    /// failure here is a developer error (Health unavailable, missing
    /// entitlement), not a user decision, and is logged via `PASLogger`.
    /// Refreshes `writeAuthorization` afterwards regardless of outcome.
    /// No-op with a warning when unconfigured or unavailable.
    public func requestAuthorization() async {
        guard isConfigured else {
            log.warning("PASHealth.requestAuthorization called before configure(permissions:) — ignoring.")
            return
        }
        guard isAvailable else {
            log.warning("PASHealth.requestAuthorization called but Health data is unavailable on this device.")
            refreshWriteAuthorization()
            return
        }
        do {
            try await store.requestAuthorization(toShare: writeTypeSet, read: readTypeSet)
        } catch {
            log.error("PASHealth.requestAuthorization failed: \(String(describing: error), privacy: .public)")
        }
        refreshWriteAuthorization()
    }

    /// Whether the system sheet still needs to be shown for the configured
    /// set — the one pre-prompt signal HealthKit gives that also covers
    /// read-only types. Use it to choose "Connect Apple Health" versus
    /// "Import from Apple Health" copy. `.unknown` when unavailable or
    /// unconfigured.
    public func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        guard isConfigured, isAvailable else { return .unknown }
        do {
            return try await store.statusForAuthorizationRequest(toShare: writeTypeSet, read: readTypeSet)
        } catch {
            log.error("PASHealth.authorizationRequestStatus failed: \(String(describing: error), privacy: .public)")
            return .unknown
        }
    }

    /// Honest per-type write status. `nil` when the permission requests no
    /// write type, or Health is unavailable — there is no truthful value to
    /// return in either case, and there is no read equivalent.
    public func writeAuthorization(for permission: PASHealthPermission) -> HKAuthorizationStatus? {
        guard let writeType = permission.writeType, isAvailable else { return nil }
        return store.authorizationStatus(for: writeType)
    }

    /// Re-derive `writeAuthorization` from the current per-type statuses.
    /// Called automatically after `configure`, `requestAuthorization`, and on
    /// iOS foreground return; call it directly if you need it sooner.
    public func refreshWriteAuthorization() {
        guard isConfigured else {
            writeAuthorization = .notDetermined
            return
        }
        let statuses = permissions.compactMap(\.writeType).map { store.authorizationStatus(for: $0) }
        writeAuthorization = .derive(from: statuses, isAvailable: isAvailable)
    }

    private var readTypeSet: Set<HKObjectType> { Self.readTypes(from: permissions) }
    private var writeTypeSet: Set<HKSampleType> { Self.writeTypes(from: permissions) }

    /// De-duplicated read/write type sets for a permission list — the same
    /// derivation `requestAuthorization`/`authorizationRequestStatus` use.
    /// Pure and static (touches no `HKHealthStore`) so it's testable without
    /// constructing `PASHealth.shared`.
    nonisolated static func readTypes(from permissions: [PASHealthPermission]) -> Set<HKObjectType> {
        Set(permissions.compactMap(\.readType))
    }

    nonisolated static func writeTypes(from permissions: [PASHealthPermission]) -> Set<HKSampleType> {
        Set(permissions.compactMap(\.writeType))
    }

    #if canImport(UIKit)
    private func subscribeToForegroundRefresh() {
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshWriteAuthorization()
            }
        }
    }
    #endif
}
