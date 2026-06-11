//
//  PASNotificationsConfig.swift
//  PASKitNotifications
//
//  Configuration handed to `PASNotifications.shared.configure(_:)` once at
//  launch.
//

import Foundation
import UserNotifications

/// Configuration for the notification-center delegate.
public struct PASNotificationsConfig: Sendable {

    /// How a notification presents while the app is in the foreground.
    /// The system default (without a delegate) is to suppress foreground
    /// notifications entirely; pass `[]` to keep that behaviour.
    public let foregroundPresentation: UNNotificationPresentationOptions

    public init(foregroundPresentation: UNNotificationPresentationOptions = [.banner, .sound]) {
        self.foregroundPresentation = foregroundPresentation
    }
}
