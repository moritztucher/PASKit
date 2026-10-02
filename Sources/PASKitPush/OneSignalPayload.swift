//
//  OneSignalPayload.swift
//  PASKitPush
//
//  OneSignal nests a notification's custom data under `custom.a` in the
//  APNs payload. Unwrapping it lets a tap on a OneSignal push reach the app's
//  `PASNotifications.onResponse` handler with the same flat routing keys a
//  local notification carries. Deliberately free of the OneSignal SDK so it
//  compiles, and is tested, on the macOS CI host.
//

import Foundation
import PASKitNotifications

enum OneSignalPayload {

    /// The string pairs of OneSignal's `custom.a` ("additional data"), or
    /// `[:]` for a payload OneSignal did not send.
    @Sendable
    static func routingKeys(from userInfo: [AnyHashable: Any]) -> [String: String] {
        guard let custom = userInfo["custom"] as? [AnyHashable: Any],
              let additionalData = custom["a"] as? [AnyHashable: Any]
        else { return [:] }
        return PASNotificationPayload.stringPairs(in: additionalData)
    }
}
