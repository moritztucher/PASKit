//
//  NotificationDelegateBridge.swift
//  PASKitNotifications
//
//  Internal UNUserNotificationCenterDelegate. UNUserNotificationCenter
//  holds its delegate weakly and calls it on arbitrary threads — this
//  bridge is retained by `PASNotifications`, answers foreground
//  presentation synchronously, and hops extracted Sendable values to the
//  main actor for tap routing.
//

import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

final class NotificationDelegateBridge: NSObject, UNUserNotificationCenterDelegate {

    private let presentationOptions: UNNotificationPresentationOptions

    init(presentationOptions: UNNotificationPresentationOptions) {
        self.presentationOptions = presentationOptions
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(presentationOptions)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let extracted = PASNotificationResponse(response)
        Task { @MainActor in
            PASNotifications.shared.deliver(extracted)
        }
        completionHandler()
    }

    #if canImport(UIKit)
    @objc func applicationWillEnterForeground() {
        Task { @MainActor in
            await PASNotifications.shared.refreshAuthorizationStatus()
        }
    }
    #endif
}
