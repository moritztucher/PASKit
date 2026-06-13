//
//  PASDurationFormat.swift
//  PASKitCore
//
//  The two duration shapes apps hand-roll because Foundation's styles
//  don't produce them cleanly: compact ("1h 03m") for stats labels and
//  clock ("1:04:12") for timers.
//

import Foundation

/// Compact, human-readable durations.
public enum PASDurationFormat {
    /// `"42s"`, `"4m 12s"`, `"1h 03m"`. Negative inputs clamp to `"0s"`.
    public static func compact(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    /// `"0:42"`, `"4:12"`, `"1:04:12"` — timer/stopwatch shape. Negative
    /// inputs clamp to `"0:00"`.
    public static func clock(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    public static func compact(seconds: Int) -> String {
        compact(seconds: TimeInterval(seconds))
    }

    public static func clock(seconds: Int) -> String {
        clock(seconds: TimeInterval(seconds))
    }
}
