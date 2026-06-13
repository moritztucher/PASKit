//
//  TestSupport.swift
//  PASKitCoreTests
//
//  Deterministic calendar + date helpers. A fixed UTC Gregorian calendar
//  keeps day/week math identical on every CI runner regardless of the
//  host timezone or locale.
//

import Foundation

/// Fixed UTC Gregorian calendar, week starting Monday — deterministic
/// across CI timezones.
let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2 // Monday
    return calendar
}()

/// Build a date in `utcCalendar` from explicit components — no ambiguity.
func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
