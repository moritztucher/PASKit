//
//  PASNotificationRequest.swift
//  PASKitNotifications
//
//  Sendable value types describing a local notification — what to show and
//  when to fire. Mapped to UNNotificationRequest at the schedule call.
//

import Foundation
import UserNotifications

/// A local notification to schedule via `PASNotifications.schedule(_:)`.
///
/// `id` is the app's stable handle: scheduling with an existing `id`
/// replaces the pending request, and `cancel(ids:)` addresses it. Keep
/// identifiers in the app's vocabulary (e.g. `"streak-protection"`), not
/// random UUIDs, so they can be cancelled and replaced deterministically.
public struct PASNotificationRequest: Sendable {

    public var id: String
    public var title: String
    public var body: String
    public var subtitle: String?

    /// Play the default notification sound. `false` delivers silently.
    public var sound: Bool

    /// Badge count to set on delivery. `nil` leaves the badge untouched.
    public var badge: Int?

    /// App-defined routing payload, echoed back in
    /// `PASNotificationResponse.userInfo` when the user acts on the
    /// notification. String-to-string by design — keep it to small routing
    /// keys (e.g. `["destination": "path"]`), not state.
    public var userInfo: [String: String]

    public var trigger: PASNotificationTrigger

    public init(
        id: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        sound: Bool = true,
        badge: Int? = nil,
        userInfo: [String: String] = [:],
        trigger: PASNotificationTrigger
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.sound = sound
        self.badge = badge
        self.userInfo = userInfo
        self.trigger = trigger
    }
}

/// When a scheduled notification fires.
public enum PASNotificationTrigger: Sendable {

    /// Fire after a delay in seconds. Repeating intervals must be at least
    /// 60 seconds (system rule).
    case interval(TimeInterval, repeats: Bool)

    /// Fire when the date components next match — e.g.
    /// `DateComponents(hour: 20)` with `repeats: true` is "daily at 8pm
    /// local time".
    case calendar(DateComponents, repeats: Bool)

    /// Fire once at an absolute date (sugar over `.calendar`).
    public static func at(_ date: Date) -> PASNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return .calendar(components, repeats: false)
    }

    /// Fire every day at a wall-clock time (sugar over a repeating
    /// `.calendar`) — the daily-reminder case.
    public static func dailyAt(hour: Int, minute: Int = 0) -> PASNotificationTrigger {
        .calendar(DateComponents(hour: hour, minute: minute), repeats: true)
    }

    /// Fire every day at the hour/minute of `date` — pass the user's picked
    /// reminder time straight through without extracting components yourself.
    public static func dailyAt(_ date: Date, calendar: Calendar = .current) -> PASNotificationTrigger {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return .calendar(
            DateComponents(hour: components.hour ?? 0, minute: components.minute ?? 0),
            repeats: true
        )
    }

    var unTrigger: UNNotificationTrigger {
        switch self {
        case let .interval(seconds, repeats):
            UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: repeats)
        case let .calendar(components, repeats):
            UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        }
    }
}
