//
//  StreakEngineTests.swift
//  PASKitCoreTests
//
//  Locks down PASStreakEngine's documented ordering rules — the part of
//  PASKit most expensive to get wrong: consume-before-grant, at-cap grants
//  that skip without advancing the timestamp, idempotent re-rolls, and the
//  freeze covering exactly one missed day.
//

import Foundation
import Testing
@testable import PASKitCore

@Suite("PASStreakEngine")
struct StreakEngineTests {

    // Anchor days, UTC noon.
    private let d1 = utcDate(2026, 1, 1)
    private let d2 = utcDate(2026, 1, 2)
    private let d3 = utcDate(2026, 1, 3)
    private let d4 = utcDate(2026, 1, 4)

    private func startOfDay(_ date: Date) -> Date { date.pasStartOfDay(calendar: utcCalendar) }

    // MARK: - recordingActivity

    @Test("First activity starts the streak at 1")
    func firstActivity() {
        let (state, first) = PASStreakEngine.recordingActivity(
            PASStreakState(), at: d1, calendar: utcCalendar
        )
        #expect(first)
        #expect(state.streak == 1)
        #expect(state.longestStreak == 1)
        #expect(state.lastActiveDay == startOfDay(d1))
    }

    @Test("Repeat activity the same day is a no-op")
    func sameDayRepeat() {
        var (state, _) = PASStreakEngine.recordingActivity(PASStreakState(), at: d1, calendar: utcCalendar)
        let (again, first) = PASStreakEngine.recordingActivity(state, at: utcDate(2026, 1, 1, 18), calendar: utcCalendar)
        #expect(!first)
        #expect(again.streak == 1)
        #expect(again.lastActiveDay == startOfDay(d1))
    }

    @Test("Consecutive days increment the streak")
    func consecutiveDays() {
        var state = PASStreakState()
        for day in [d1, d2, d3] {
            (state, _) = PASStreakEngine.recordingActivity(state, at: day, calendar: utcCalendar)
        }
        #expect(state.streak == 3)
        #expect(state.longestStreak == 3)
    }

    @Test("A gap resets the current streak but preserves the longest")
    func gapResetsButKeepsLongest() {
        var state = PASStreakState()
        for day in [d1, d2, d3] {
            (state, _) = PASStreakEngine.recordingActivity(state, at: day, calendar: utcCalendar)
        }
        let (after, first) = PASStreakEngine.recordingActivity(state, at: utcDate(2026, 1, 10), calendar: utcCalendar)
        #expect(first)
        #expect(after.streak == 1)        // reset to 0, then this day's +1
        #expect(after.longestStreak == 3) // raise-only
    }

    // MARK: - survivingStreak

    @Test("Streak survives a gap of 0 or 1 day, resets beyond")
    func survivalBoundaries() {
        #expect(PASStreakEngine.survivingStreak(streak: 5, lastActiveDay: d3, today: d3, calendar: utcCalendar) == 5)
        #expect(PASStreakEngine.survivingStreak(streak: 5, lastActiveDay: d2, today: d3, calendar: utcCalendar) == 5)
        #expect(PASStreakEngine.survivingStreak(streak: 5, lastActiveDay: d1, today: d3, calendar: utcCalendar) == 0)
        #expect(PASStreakEngine.survivingStreak(streak: 5, lastActiveDay: nil, today: d3, calendar: utcCalendar) == 0)
    }

    // MARK: - Freeze consume

    @Test("A freeze covers exactly one missed day and the streak survives")
    func freezeConsumesOneMissedDay() {
        let config = PASStreakConfig(freezeCap: 3)
        let state = PASStreakState(streak: 5, longestStreak: 5, lastActiveDay: startOfDay(d1), freezeBalance: 2)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d3, calendar: utcCalendar, config: config)
        #expect(outcome.freezeConsumed)
        #expect(!outcome.streakDidReset)
        #expect(next.streak == 5)
        #expect(next.freezeBalance == 1)
        #expect(next.lastActiveDay == startOfDay(d2)) // moved to "yesterday"
    }

    @Test("Re-rolling the same day does not consume a second freeze")
    func freezeConsumeIsIdempotent() {
        let config = PASStreakConfig(freezeCap: 3)
        let state = PASStreakState(streak: 5, lastActiveDay: startOfDay(d1), freezeBalance: 2)
        let (once, _) = PASStreakEngine.rolledOver(state, today: d3, calendar: utcCalendar, config: config)
        let (twice, outcome) = PASStreakEngine.rolledOver(once, today: d3, calendar: utcCalendar, config: config)
        #expect(!outcome.freezeConsumed)
        #expect(twice.freezeBalance == 1)
        #expect(twice.streak == 5)
    }

    @Test("A multi-day gap is not coverable by a single freeze and resets")
    func multiDayGapResets() {
        let config = PASStreakConfig(freezeCap: 3)
        let state = PASStreakState(streak: 5, lastActiveDay: startOfDay(d1), freezeBalance: 2)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d4, calendar: utcCalendar, config: config)
        #expect(!outcome.freezeConsumed)
        #expect(outcome.streakDidReset)
        #expect(next.streak == 0)
        #expect(next.freezeBalance == 2) // untouched
    }

    @Test("Without inventory the streak resets even at a one-day gap")
    func noFreezeNoSave() {
        let state = PASStreakState(streak: 5, lastActiveDay: startOfDay(d1), freezeBalance: 0)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d3, calendar: utcCalendar, config: PASStreakConfig(freezeCap: 3))
        #expect(!outcome.freezeConsumed)
        #expect(next.streak == 0)
    }

    // MARK: - Free grant

    @Test("First free grant is due immediately and isn't spent on the same roll")
    func firstGrantDueImmediately() {
        let config = PASStreakConfig(freezeCap: 2, freeFreezeInterval: 60 * 60 * 24 * 7)
        let state = PASStreakState(streak: 1, lastActiveDay: startOfDay(d1), freezeBalance: 0, lastFreezeGrantAt: nil)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d1, calendar: utcCalendar, config: config)
        #expect(outcome.freezeGranted)
        #expect(next.freezeBalance == 1)
        #expect(next.lastFreezeGrantAt == d1)
    }

    @Test("No grant before the interval elapses")
    func grantNotDueYet() {
        let config = PASStreakConfig(freezeCap: 2, freeFreezeInterval: 60 * 60 * 24 * 7)
        let state = PASStreakState(streak: 1, lastActiveDay: startOfDay(d1), freezeBalance: 0, lastFreezeGrantAt: d1)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d2, calendar: utcCalendar, config: config)
        #expect(!outcome.freezeGranted)
        #expect(next.freezeBalance == 0)
    }

    @Test("At cap, a due grant is skipped WITHOUT advancing the timestamp")
    func atCapSkipsWithoutAdvancing() {
        let config = PASStreakConfig(freezeCap: 1, freeFreezeInterval: 1)
        let state = PASStreakState(streak: 1, lastActiveDay: startOfDay(d1), freezeBalance: 1, lastFreezeGrantAt: nil)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d1, calendar: utcCalendar, config: config)
        #expect(!outcome.freezeGranted)
        #expect(next.freezeBalance == 1)
        #expect(next.lastFreezeGrantAt == nil) // user gets it on the first roll after spending one
    }

    @Test("A backwards clock never grants")
    func backwardsClockNeverGrants() {
        let config = PASStreakConfig(freezeCap: 2, freeFreezeInterval: 60)
        let state = PASStreakState(streak: 1, lastActiveDay: startOfDay(d3), freezeBalance: 0, lastFreezeGrantAt: d3)
        let (_, outcome) = PASStreakEngine.rolledOver(state, today: d1, calendar: utcCalendar, config: config)
        #expect(!outcome.freezeGranted)
    }

    @Test("Consume runs before grant: a freshly granted freeze can't save the current gap")
    func consumeBeforeGrant() {
        let config = PASStreakConfig(freezeCap: 2, freeFreezeInterval: 1)
        let state = PASStreakState(streak: 5, lastActiveDay: startOfDay(d1), freezeBalance: 0, lastFreezeGrantAt: nil)
        let (next, outcome) = PASStreakEngine.rolledOver(state, today: d3, calendar: utcCalendar, config: config)
        #expect(!outcome.freezeConsumed) // no inventory at consume time
        #expect(outcome.streakDidReset)
        #expect(next.streak == 0)
        #expect(outcome.freezeGranted)   // granted after, not used to save
        #expect(next.freezeBalance == 1)
    }

    // MARK: - State

    @Test("State round-trips through Codable")
    func stateIsCodable() throws {
        let state = PASStreakState(streak: 3, longestStreak: 7, lastActiveDay: d1, freezeBalance: 2, lastFreezeGrantAt: d1)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PASStreakState.self, from: data)
        #expect(decoded == state)
    }
}
