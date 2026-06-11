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
    /// routing keys the app attached at schedule time. Non-string values
    /// (possible on remote payloads) are dropped.
    public let userInfo: [String: String]

    /// The user tapped the notification body to open the app.
    public var isDefaultTap: Bool {
        actionID == UNNotificationDefaultActionIdentifier
    }

    public init(notificationID: String, actionID: String, userInfo: [String: String]) {
        self.notificationID = notificationID
        self.actionID = actionID
        self.userInfo = userInfo
    }

    init(_ response: UNNotificationResponse) {
        notificationID = response.notification.request.identifier
        actionID = response.actionIdentifier
        var extracted: [String: String] = [:]
        for (key, value) in response.notification.request.content.userInfo {
            if let key = key as? String, let value = value as? String {
                extracted[key] = value
            }
        }
        userInfo = extracted
    }
}
