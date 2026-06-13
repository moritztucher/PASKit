//
//  Date+PASCalendar.swift
//  PASKitCore
//
//  Calendar math for day gating, streaks, and rollovers — the
//  startOfDay-normalized helpers every app re-derives (and where the
//  off-by-one bugs live). Plain date-to-string formatting is deliberately
//  not wrapped: use `formatted(.dateTime…)` / `RelativeDateTimeFormatter`.
//

import Foundation

public extension Date {
    /// Midnight at the start of this date's day.
    func pasStartOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    /// One second before the next midnight (23:59:59).
    func pasEndOfDay(calendar: Calendar = .current) -> Date {
        let start = pasStartOfDay(calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? self
    }

    /// Whether both dates fall on the same calendar day.
    func pasIsSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }

    /// Whole calendar days from `other` to `self` — both ends normalized
    /// to start-of-day first, so 23:59 → 00:01 across midnight counts as
    /// one day regardless of clock time. Negative when `self` is earlier.
    func pasDaysSince(_ other: Date, calendar: Calendar = .current) -> Int {
        let start = other.pasStartOfDay(calendar: calendar)
        let end = pasStartOfDay(calendar: calendar)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// The date shifted by whole days (clock time preserved).
    func pasAdding(days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Whether both dates fall in the same week (`weekOfYear` granularity).
    /// Use this for weekly-counter resets instead of comparing stored
    /// week-start dates for equality — a timezone or `firstWeekday` change
    /// shifts the computed instant, and exact equality would spuriously
    /// reset the counter mid-week.
    func pasIsSameWeek(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, equalTo: other, toGranularity: .weekOfYear)
    }

    /// Start of the week containing this date, honoring the calendar's
    /// `firstWeekday` — the week-rollover anchor.
    func pasStartOfWeek(calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Whole hours from this instant until the next midnight — "4 hours
    /// left to keep your streak". 0 at most one hour before midnight.
    func pasHoursUntilMidnight(calendar: Calendar = .current) -> Int {
        let start = pasStartOfDay(calendar: calendar)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return max(0, Int(midnight.timeIntervalSince(self) / 3600))
    }
}
