//
//  PASNotificationResponse.swift
//  PASKitNotifications
//
//  Sendable value extracted from UNNotificationResponse when the user acts
//  on a notification — what `onResponse` handlers receive.
//

import Foundation
import UserNotifications

/// The user's action on a delivered notification (local or remote).
public struct PASNotificationResponse: Sendable {

    /// Identifier of the notification the user acted on — the `id` the app
    /// passed in `PASNotificationRequest`.
    public let notificationID: String

    /// The action taken — `UNNotificationDefaultActionIdentifier` for a
    /// plain tap, `UNNotificationDismissActionIdentifier` for a dismissal,
    /// or a custom action identifier.
    public let actionID: String

    /// String pairs from the notification's `userInfo` payload — the
    /// routing keys the app attached at schedule time, or sent in a remote
    /// payload (unwrapped from a provider's envelope when a provider module
    /// registered one via `PASNotificationPayload`). Non-string values are
    /// dropped.
    public let userInfo: [String: String]

    /// The notification arrived as a remote push rather than being
    /// scheduled locally.
    public let isRemote: Bool

    /// The user tapped the notification body to open the app.
    public var isDefaultTap: Bool {
        actionID == UNNotificationDefaultActionIdentifier
    }

    public init(notificationID: String, actionID: String, userInfo: [String: String], isRemote: Bool = false) {
        self.notificationID = notificationID
        self.actionID = actionID
        self.userInfo = userInfo
        self.isRemote = isRemote
    }

    init(_ response: UNNotificationResponse) {
        notificationID = response.notification.request.identifier
        actionID = response.actionIdentifier
        userInfo = PASNotificationPayload.routingKeys(from: response.notification.request.content.userInfo)
        isRemote = response.notification.request.trigger is UNPushNotificationTrigger
    }
}
