//
//  PASNotifications.swift
//  PASKitNotifications
//
//  Thin concrete facade over UNUserNotificationCenter — a convenience
//  wrapper, not a vendor abstraction. PASKit owns the mechanism (delegate
//  plumbing, observable authorization state, schedule/cancel primitives,
//  tap routing); each app owns its vocabulary (when to schedule, copy,
//  identifiers, and where a tap navigates).
//

import Foundation
import PASKitCore
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Local-notification facade. `PASNotifications.shared.configure(...)` once
/// at launch (installs the notification-center delegate), then observe
/// `authorizationStatus`, request permission at the app's earned moment, and
/// schedule/cancel through the value-type API. Register `onResponse` to
/// route notification taps — a tap that cold-started the app is buffered and
/// delivered as soon as the handler registers.
///
/// Scheduling and authorization work without `configure`; only foreground
/// presentation and tap routing need the delegate installed.
@MainActor
@Observable
public final class PASNotifications {

    public static let shared = PASNotifications()

    /// Current notification authorization. Refreshed on `configure`, after
    /// `requestAuthorization`, on every foreground return (iOS), and on
    /// demand via `refreshAuthorizationStatus`. Observable — drive
    /// permission UI from it rather than caching a boolean.
    public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    public private(set) var isConfigured = false

    /// Whether notifications can currently be delivered in any form
    /// (full, provisional, or ephemeral authorization).
    public var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    private let log = PASLogger.make(category: "notifications")
    @ObservationIgnored private var bridge: NotificationDelegateBridge?
    @ObservationIgnored private var responseHandler: (@MainActor (PASNotificationResponse) -> Void)?
    @ObservationIgnored private var pendingResponse: PASNotificationResponse?

    private init() {}

    // MARK: - Setup

    /// Install the notification-center delegate (foreground presentation +
    /// tap routing) and start tracking authorization. Call once, early at
    /// launch — before the system can deliver a cold-start tap response.
    /// Subsequent calls log a warning and no-op.
    public func configure(_ config: PASNotificationsConfig = PASNotificationsConfig()) {
        guard !isConfigured else {
            log.warning("PASNotifications.configure called twice — ignoring the second call.")
            return
        }
        let bridge = NotificationDelegateBridge(presentationOptions: config.foregroundPresentation)
        UNUserNotificationCenter.current().delegate = bridge
        self.bridge = bridge
        isConfigured = true
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            bridge,
            selector: #selector(NotificationDelegateBridge.applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
        Task { await refreshAuthorizationStatus() }
        log.info("Notification delegate installed.")
    }

    /// Register the tap-routing handler — called on the main actor whenever
    /// the user acts on a notification. If a response arrived before any
    /// handler was registered (cold-start tap), it is delivered immediately.
    /// The handler maps `userInfo` to the app's own navigation.
    public func onResponse(_ handler: @escaping @MainActor (PASNotificationResponse) -> Void) {
        responseHandler = handler
        if let pending = pendingResponse {
            pendingResponse = nil
            handler(pending)
        }
    }

    // MARK: - Authorization

    /// Prompt for notification permission. Ask at an earned moment (after
    /// the first delight), never at first launch. Returns whether the user
    /// granted; `authorizationStatus` is refreshed either way.
    @discardableResult
    public func requestAuthorization(options: UNAuthorizationOptions = [.alert, .sound, .badge]) async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        await refreshAuthorizationStatus()
        return granted
    }

    /// Re-read authorization from the system. iOS calls this automatically
    /// on foreground return once configured; call manually on macOS or after
    /// returning from the Settings app deep link.
    public func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Scheduling

    /// Schedule a local notification. Re-using an `id` replaces the pending
    /// request with that identifier — schedule idempotently rather than
    /// checking `pendingIDs` first.
    public func schedule(_ request: PASNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        if let subtitle = request.subtitle {
            content.subtitle = subtitle
        }
        if request.sound {
            content.sound = .default
        }
        if let badge = request.badge {
            content.badge = NSNumber(value: badge)
        }
        if !request.userInfo.isEmpty {
            content.userInfo = request.userInfo
        }
        let unRequest = UNNotificationRequest(identifier: request.id, content: content, trigger: request.trigger.unTrigger)
        try await UNUserNotificationCenter.current().add(unRequest)
    }

    /// Cancel pending (not yet delivered) notifications by identifier.
    /// Unknown identifiers are ignored.
    public func cancel(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Cancel every pending notification scheduled by the app.
    public func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Identifiers of all pending (not yet delivered) notifications.
    public func pendingIDs() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    // MARK: - Badge

    /// Set the app icon's badge count. `0` clears the badge.
    public func setBadgeCount(_ count: Int) async throws {
        try await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: - Internal

    /// Delivery point for the delegate bridge. Buffers the response when no
    /// handler is registered yet (cold-start tap before the app wires
    /// `onResponse`).
    func deliver(_ response: PASNotificationResponse) {
        if let handler = responseHandler {
            handler(response)
        } else {
            pendingResponse = response
        }
    }
}
