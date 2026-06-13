//
//  PASHapticSequence.swift
//  PASKitCore
//
//  Multi-step haptic patterns — the Task.sleep chains apps hand-write for
//  celebrations and timer alerts, as data. PASKit owns the player and the
//  proven preset shapes; what an app *means* by a pattern stays per-app.
//

import Foundation

/// A timed sequence of haptic primitives.
///
/// ```swift
/// Haptics.play(.celebration, isEnabled: settings.hapticsEnabled)
/// Haptics.play(PASHapticSequence([
///     .init(.soft, delay: 0), .init(.success, delay: 0.2),
/// ]))
/// ```
public struct PASHapticSequence: Sendable {
    /// One step: the primitive to play and the pause before it fires.
    public struct Step: Sendable {
        public let haptic: PASHaptic
        public let delay: TimeInterval

        /// - Parameters:
        ///   - haptic: The primitive to play.
        ///   - delay: Seconds to wait before this step (0 fires immediately
        ///     after the previous step).
        public init(_ haptic: PASHaptic, delay: TimeInterval) {
            self.haptic = haptic
            self.delay = max(0, delay)
        }
    }

    public let steps: [Step]

    public init(_ steps: [Step]) {
        self.steps = steps
    }

    // MARK: - Presets (timings lifted from shipped apps)

    /// Completed action: medium impact, then success. (habit-app timing)
    public static let celebration = PASHapticSequence([
        Step(.medium, delay: 0),
        Step(.success, delay: 0.1),
    ])

    /// Significant achievement, 3-beat: heavy → success → light.
    public static let milestone = PASHapticSequence([
        Step(.heavy, delay: 0),
        Step(.success, delay: 0.12),
        Step(.light, delay: 0.1),
    ])

    /// Major milestone, rising intensity: light → medium → heavy → success.
    public static let levelUp = PASHapticSequence([
        Step(.light, delay: 0),
        Step(.medium, delay: 0.08),
        Step(.heavy, delay: 0.08),
        Step(.success, delay: 0.1),
    ])

    /// Timer finished: three heavy pulses 350 ms apart. (workout-app timing)
    public static let triplePulse = PASHapticSequence([
        Step(.heavy, delay: 0),
        Step(.heavy, delay: 0.35),
        Step(.heavy, delay: 0.35),
    ])
}

public extension Haptics {
    /// Plays the sequence's steps in order, sleeping each step's delay
    /// first. Fire-and-forget; iOS only — no-op on macOS or when
    /// `isEnabled` is `false`. Sequences are sub-second by design; there is
    /// no cancellation until a real app needs one.
    static func play(_ sequence: PASHapticSequence, isEnabled: Bool = true) {
        guard isEnabled else { return }
        Task { @MainActor in
            for step in sequence.steps {
                if step.delay > 0 {
                    try? await Task.sleep(for: .seconds(step.delay))
                }
                play(step.haptic)
            }
        }
    }
}
