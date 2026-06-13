//
//  PASStreakState.swift
//  PASKitCore
//
//  Streak state as a plain value — persistence stays app-side (SwiftData,
//  Realm, UserDefaults via @PASDefault/PASDraft all work; it's Codable).
//  All mutation goes through PASStreakEngine's pure functions.
//

import Foundation

public struct PASStreakState: Codable, Equatable, Sendable {
    /// Current consecutive-day streak.
    public var streak: Int

    /// All-time best — raised by the engine, never lowered.
    public var longestStreak: Int

    /// Start-of-day of the last day with activity; `nil` before any.
    public var lastActiveDay: Date?

    /// Streak freezes in inventory (0 when the app doesn't use freezes).
    public var freezeBalance: Int

    /// When the last free freeze was granted; `nil` = first grant due.
    public var lastFreezeGrantAt: Date?

    public init(
        streak: Int = 0,
        longestStreak: Int = 0,
        lastActiveDay: Date? = nil,
        freezeBalance: Int = 0,
        lastFreezeGrantAt: Date? = nil
    ) {
        self.streak = streak
        self.longestStreak = longestStreak
        self.lastActiveDay = lastActiveDay
        self.freezeBalance = freezeBalance
        self.lastFreezeGrantAt = lastFreezeGrantAt
    }
}
