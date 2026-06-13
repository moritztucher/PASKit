//
//  PASStreakEngine.swift
//  PASKitCore
//
//  Pure streak machine: survival/reset, streak freezes, free-freeze
//  grants, first-activity-today increments. Extracted from a shipped
//  learning app's engine, preserving its ordering rules exactly (consume
//  before grant; at-cap grants skip without advancing the timestamp).
//
//  Operational rule for callers: run `rolledOver` at launch AND on every
//  scenePhase == .active — iOS keeps apps resident for days, so a
//  launch-only rollover leaves streaks stale.
//

import Foundation

/// Streak feature configuration. Defaults disable freezes entirely.
public struct PASStreakConfig: Sendable {
    /// Maximum freezes a user can hold. 0 disables freeze consumption.
    public var freezeCap: Int

    /// Seconds between free freeze grants (rolling); `nil` disables grants.
    public var freeFreezeInterval: TimeInterval?

    public init(freezeCap: Int = 0, freeFreezeInterval: TimeInterval? = nil) {
        self.freezeCap = freezeCap
        self.freeFreezeInterval = freeFreezeInterval
    }
}

/// What a rollover did — drives one-time notices ("streak saved").
public struct PASStreakRolloverOutcome: Equatable, Sendable {
    public var freezeConsumed = false
    public var freezeGranted = false
    public var streakDidReset = false

    public init() {}
}

public enum PASStreakEngine {
    /// Applies the day rollover for `today` in the proven order:
    ///
    /// 1. **Freeze consume** — exactly one missed day, a live streak, and
    ///    inventory. The frozen day counts as covered (`lastActiveDay`
    ///    moves to yesterday), so a repeated rollover can't consume again.
    ///    Multi-day gaps fall through to the plain reset — freezes cover
    ///    one day only.
    /// 2. **Streak roll** — survives while the last active day is today or
    ///    yesterday; any longer gap resets to 0.
    /// 3. **Free grant** — after the consume check so a fresh grant isn't
    ///    immediately spent. At cap the grant is skipped WITHOUT advancing
    ///    the timestamp (the user receives it on the first rollover after
    ///    spending one). A backwards clock never grants.
    public static func rolledOver(
        _ state: PASStreakState,
        today: Date = .now,
        calendar: Calendar = .current,
        config: PASStreakConfig = PASStreakConfig()
    ) -> (state: PASStreakState, outcome: PASStreakRolloverOutcome) {
        var next = state
        var outcome = PASStreakRolloverOutcome()

        if next.streak > 0, next.freezeBalance > 0,
           let lastActive = next.lastActiveDay,
           today.pasDaysSince(lastActive, calendar: calendar) == 2 {
            next.freezeBalance -= 1
            next.lastActiveDay = today.pasAdding(days: -1, calendar: calendar)
                .pasStartOfDay(calendar: calendar)
            outcome.freezeConsumed = true
        }

        let rolled = survivingStreak(
            streak: next.streak,
            lastActiveDay: next.lastActiveDay,
            today: today,
            calendar: calendar
        )
        outcome.streakDidReset = rolled == 0 && next.streak > 0
        next.streak = rolled

        if let interval = config.freeFreezeInterval,
           next.freezeBalance < config.freezeCap,
           freeFreezeDue(lastGrant: next.lastFreezeGrantAt, today: today, interval: interval) {
            next.freezeBalance += 1
            next.lastFreezeGrantAt = today
            outcome.freezeGranted = true
        }

        return (next, outcome)
    }

    /// Records activity for `date`: rolls over first (safe when the caller
    /// hasn't), then — on the first activity of that day — increments the
    /// streak, raises `longestStreak` (raise-only), and stamps
    /// `lastActiveDay`. Repeated activity on the same day returns
    /// `firstActivityToday: false` and changes nothing further.
    ///
    /// Needs the rollover outcome too (freeze notices)? Call `rolledOver`
    /// explicitly first — the internal roll here is a safety net and its
    /// outcome is discarded.
    public static func recordingActivity(
        _ state: PASStreakState,
        at date: Date = .now,
        calendar: Calendar = .current,
        config: PASStreakConfig = PASStreakConfig()
    ) -> (state: PASStreakState, firstActivityToday: Bool) {
        var (next, _) = rolledOver(state, today: date, calendar: calendar, config: config)

        if let lastActive = next.lastActiveDay,
           lastActive.pasIsSameDay(as: date, calendar: calendar) {
            return (next, false)
        }

        next.streak += 1
        next.longestStreak = max(next.longestStreak, next.streak)
        next.lastActiveDay = date.pasStartOfDay(calendar: calendar)
        return (next, true)
    }

    /// Streak survives while the last active day is today or yesterday;
    /// any longer gap (or no activity ever) resets it.
    public static func survivingStreak(
        streak: Int,
        lastActiveDay: Date?,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let lastActiveDay else { return 0 }
        let gap = today.pasDaysSince(lastActiveDay, calendar: calendar)
        return (0...1).contains(gap) ? streak : 0
    }

    /// Rolling cadence; `nil` last grant = first grant due immediately; a
    /// backwards clock (today before the stored grant) is never due.
    static func freeFreezeDue(lastGrant: Date?, today: Date, interval: TimeInterval) -> Bool {
        guard let lastGrant else { return true }
        return today.timeIntervalSince(lastGrant) >= interval
    }
}
