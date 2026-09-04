//
//  PASNotificationSound.swift
//  PASKitNotifications
//
//  The sound a local notification plays on delivery. Boolean-literal
//  compatible so existing `sound: true` / `sound: false` call sites keep
//  compiling unchanged.
//

import UserNotifications

/// The sound a local notification plays on delivery.
///
/// Boolean literals still work for the two common cases — `sound: true`
/// is `.default`, `sound: false` is `.silent` — so existing call sites
/// compile unchanged. Prefer the named cases in new code.
public enum PASNotificationSound: Equatable, Sendable, ExpressibleByBooleanLiteral {
    /// Deliver silently.
    case silent
    /// The system default alert sound.
    case `default`
    /// A bundled custom sound: an `aiff` / `wav` / `caf` file of ≤ 30 s in
    /// the app's main bundle, referenced by filename with extension —
    /// e.g. `.named("rest_complete.wav")`. Longer or missing files fall
    /// back to the system default at delivery time (system behaviour).
    case named(String)

    public init(booleanLiteral value: Bool) {
        self = value ? .default : .silent
    }

    /// `UNMutableNotificationContent.sound` value; `nil` = silent.
    var unSound: UNNotificationSound? {
        switch self {
        case .silent: nil
        case .default: .default
        case let .named(name): UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
        }
    }
}
