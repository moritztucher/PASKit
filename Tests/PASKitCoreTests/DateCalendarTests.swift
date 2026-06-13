//
//  DateCalendarTests.swift
//  PASKitCoreTests
//
//  Day/week math — especially the cross-midnight day count where the
//  off-by-one bugs live.
//

import Foundation
import Testing
@testable import PASKitCore

@Suite("Date+PASCalendar")
struct DateCalendarTests {

    @Test("startOfDay zeroes the clock; endOfDay is 23:59:59 of the same day")
    func startAndEndOfDay() {
        let noon = utcDate(2026, 3, 15, 12, 30)
        let start = noon.pasStartOfDay(calendar: utcCalendar)
        #expect(utcCalendar.component(.hour, from: start) == 0)
        #expect(utcCalendar.component(.minute, from: start) == 0)

        let end = noon.pasEndOfDay(calendar: utcCalendar)
        #expect(noon.pasIsSameDay(as: end, calendar: utcCalendar))
        #expect(end.timeIntervalSince(start) == 86_399)
    }

    @Test("isSameDay ignores clock time")
    func isSameDay() {
        #expect(utcDate(2026, 1, 1, 0, 1).pasIsSameDay(as: utcDate(2026, 1, 1, 23, 59), calendar: utcCalendar))
        #expect(!utcDate(2026, 1, 1, 23, 59).pasIsSameDay(as: utcDate(2026, 1, 2, 0, 1), calendar: utcCalendar))
    }

    @Test("daysSince counts calendar days across midnight, not elapsed hours")
    func daysSinceCrossMidnight() {
        let late = utcDate(2026, 1, 1, 23, 59)
        let early = utcDate(2026, 1, 2, 0, 1) // two minutes later, but next day
        #expect(early.pasDaysSince(late, calendar: utcCalendar) == 1)
        #expect(late.pasDaysSince(early, calendar: utcCalendar) == -1)
        #expect(late.pasDaysSince(late, calendar: utcCalendar) == 0)
    }

    @Test("adding days preserves clock time and rolls the month")
    func addingDays() {
        let next = utcDate(2026, 1, 31, 9, 15).pasAdding(days: 1, calendar: utcCalendar)
        #expect(utcCalendar.component(.month, from: next) == 2)
        #expect(utcCalendar.component(.day, from: next) == 1)
        #expect(utcCalendar.component(.hour, from: next) == 9)
    }

    @Test("isSameWeek groups by week, not by 7-day windows")
    func isSameWeek() {
        let tuesday = utcDate(2026, 1, 6)
        let thursday = utcDate(2026, 1, 8)   // same Mon–Sun week
        let nextTuesday = utcDate(2026, 1, 13)
        #expect(tuesday.pasIsSameWeek(as: thursday, calendar: utcCalendar))
        #expect(!tuesday.pasIsSameWeek(as: nextTuesday, calendar: utcCalendar))
    }

    @Test("startOfWeek lands on the calendar's firstWeekday")
    func startOfWeekHonorsFirstWeekday() {
        let thursday = utcDate(2026, 1, 8, 15)
        let weekStart = thursday.pasStartOfWeek(calendar: utcCalendar)
        #expect(utcCalendar.component(.weekday, from: weekStart) == utcCalendar.firstWeekday) // Monday
        #expect(utcCalendar.component(.day, from: weekStart) == 5) // Mon 2026-01-05
        #expect(weekStart <= thursday)
        #expect(thursday.pasIsSameWeek(as: weekStart, calendar: utcCalendar))
    }

    @Test("hoursUntilMidnight is whole hours, 0 within the last hour")
    func hoursUntilMidnight() {
        #expect(utcDate(2026, 1, 1, 20, 0).pasHoursUntilMidnight(calendar: utcCalendar) == 4)
        #expect(utcDate(2026, 1, 1, 23, 30).pasHoursUntilMidnight(calendar: utcCalendar) == 0)
        #expect(utcDate(2026, 1, 1, 0, 0).pasHoursUntilMidnight(calendar: utcCalendar) == 24)
    }
}
