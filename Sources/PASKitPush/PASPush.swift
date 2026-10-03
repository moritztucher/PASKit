//
//  PASPush.swift
//  PASKitPush
//
//  Thin concrete facade over the OneSignal SDK — a convenience wrapper, not
//  a vendor abstraction, the same shape as `PASPurchases` over RevenueCat.
//  PASKit owns the mechanism (consent gating, identity, subscription state,
//  coexistence with PASNotifications); each app owns its vocabulary (tags,
//  payload routing keys, when consent is given).
//
//  Taps and foreground presentation stay with PASNotifications. OneSignal
//  wraps whichever UNUserNotificationCenter delegate is installed and
//  forwards every response — its own included — to it, so this facade
//  registers no click listener: OneSignal taps reach the app's single
//  `PASNotifications.onResponse` handler, with OneSignal's custom data
//  unwrapped into flat routing keys. See
//  docs/adr/ADR-0006-paskitpush-onesignal.md.
//

#if os(iOS)
import Foundation
import OneSignalFramework
import PASKitCore
import PASKitNotifications

private let log = PASLogger.make(category: "push")

/// OneSignal facade. `PASPush.shared.configure(...)` once at launch, right
/// after `PASNotifications.shared.configure()`, then give consent, log the
/// user in, and register once notification permission is granted.
@MainActor
@Observable
public final class PASPush {

    public static let shared = PASPush()

    // MARK: - Observable state

    /// `configure(_:)` has run.
    public private(set) var isConfigured = false

    /// The app has allowed the SDK to talk to OneSignal. Always `true` when
    /// configured with `requiresConsent: false`.
    public private(set) var hasConsent = false

    /// The device's push subscription is opted in: a token is registered,
    /// permission is granted and the app has not called `optOut()`.
    public private(set) var isOptedIn = false

    /// OneSignal's id for this device's push subscription, once created.
    public private(set) var subscriptionID: String?

    /// The external user id passed to `login(userID:)`, if any.
    public private(set) var userID: String?

    // MARK: - Private

    @ObservationIgnored private var subscriptionObserver: SubscriptionObserver?

    private init() {}

    // MARK: - Setup

    /// Initialise OneSignal. Call once, early at launch, after
    /// `PASNotifications.shared.configure()` — the SDK then wraps that
    /// delegate rather than installing its own. With `requiresConsent`
    /// (the default) no data is sent until `setConsent(true)`.
    public func configure(_ config: PASPushConfig) {
        guard !isConfigured else {
            log.warning("PASPush.configure called twice — ignoring the second call.")
            return
        }
        if !PASNotifications.shared.isConfigured {
            log.warning("PASPush configured before PASNotifications — call PASNotifications.shared.configure() first.")
        }
        PASNotificationPayload.registerUnwrapper(OneSignalPayload.routingKeys)
        if config.verboseLogging {
            OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        }
        OneSignal.setConsentRequired(config.requiresConsent)
        OneSignal.initialize(config.appID, withLaunchOptions: nil)

        let observer = SubscriptionObserver()
        OneSignal.User.pushSubscription.addObserver(observer)
        subscriptionObserver = observer

        hasConsent = !config.requiresConsent
        isConfigured = true
        refreshSubscription()
        log.info("OneSignal initialised (consent required: \(config.requiresConsent, privacy: .public)).")
    }

    // MARK: - Consent

    /// Grant or revoke consent for the SDK to send data to OneSignal. The
    /// app decides what counts as consent (a privacy toggle, the
    /// notification-permission grant, …).
    public func setConsent(_ given: Bool) {
        guard isConfigured else { return }
        OneSignal.setConsentGiven(given)
        hasConsent = given
    }

    // MARK: - Registration

    /// Register the push token with OneSignal when notification permission
    /// is already granted. Never shows the system prompt — ask for
    /// permission through `PASNotifications.requestAuthorization()`, then
    /// call this. Safe to call on every launch and foreground return.
    public func registerIfAuthorized() {
        guard isConfigured, hasConsent, PASNotifications.shared.isAuthorized else { return }
        OneSignal.Notifications.requestPermission({ _ in
            Task { @MainActor in PASPush.shared.refreshSubscription() }
        }, fallbackToSettings: false)
    }

    /// Resume push delivery after `optOut()`.
    public func optIn() {
        guard isConfigured else { return }
        OneSignal.User.pushSubscription.optIn()
    }

    /// Stop push delivery to this device without touching the OS
    /// permission — the in-app "push notifications off" switch.
    public func optOut() {
        guard isConfigured else { return }
        OneSignal.User.pushSubscription.optOut()
    }

    // MARK: - Identity

    /// Attach this device to the app's user. Pass the same id given to
    /// `PASPurchases.logIn` and `PASAnalytics.identify` so the three join.
    public func login(userID: String) {
        guard isConfigured else { return }
        OneSignal.login(userID)
        self.userID = userID
    }

    /// Detach the device from the user (sign-out, account deletion). The
    /// OneSignal user record itself is deleted server-side, through
    /// OneSignal's REST API — the SDK cannot delete it.
    public func logout() {
        guard isConfigured else { return }
        OneSignal.logout()
        userID = nil
    }

    // MARK: - Tags

    /// Set segmentation tags on the current user. Keys are app vocabulary.
    public func addTags(_ tags: [String: String]) {
        guard isConfigured else { return }
        OneSignal.User.addTags(tags)
    }

    /// Remove segmentation tags from the current user.
    public func removeTags(_ keys: [String]) {
        guard isConfigured else { return }
        OneSignal.User.removeTags(keys)
    }

    // MARK: - Internal

    func refreshSubscription() {
        guard isConfigured else { return }
        apply(optedIn: OneSignal.User.pushSubscription.optedIn, id: OneSignal.User.pushSubscription.id)
    }

    func apply(optedIn: Bool, id: String?) {
        isOptedIn = optedIn
        subscriptionID = id
    }
}

/// OneSignal calls observers off the main actor — extract Sendable values,
/// then hop.
private final class SubscriptionObserver: NSObject, OSPushSubscriptionObserver {
    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        let optedIn = state.current.optedIn
        let id = state.current.id
        Task { @MainActor in
            PASPush.shared.apply(optedIn: optedIn, id: id)
        }
    }
}
#endif
