//
//  PASOnboardingFlow.swift
//  PASKitLifecycle
//
//  Step engine for onboarding: index-based navigation over a live step
//  list, with direction tracking for slide transitions and a 0–1 progress
//  value. The step list is a closure so flows can be conditional — steps
//  appear/disappear as earlier answers change. PASKit owns the engine;
//  the app owns step vocabulary, step views, and navigation chrome.
//

import Foundation
import Observation

/// Observable onboarding step engine.
///
/// ```swift
/// enum Step: String, Codable, Hashable { case welcome, units, permissions }
///
/// let flow = PASOnboardingFlow(steps: Step.allCases)        // static flow
/// let flow = PASOnboardingFlow { model.visibleSteps }       // conditional flow
///
/// flow.advance()              // bounded; sets direction = .forward
/// flow.back()                 // bounded; sets direction = .backward
/// flow.go(to: restoredStep)   // draft resume / jump; direction from comparison
/// ```
///
/// The flow must always have at least one step.
@Observable
@MainActor
public final class PASOnboardingFlow<Step: Hashable> {
    /// Position in the current step list. Clamped on read where it matters
    /// (`current`, `progress`) so a shrinking conditional list never traps.
    public private(set) var index = 0

    /// Direction of the last navigation — feeds `pasOnboardingTransition`.
    public private(set) var direction: PASOnboardingDirection = .forward

    @ObservationIgnored private let stepsProvider: () -> [Step]

    /// Conditional flow — the closure is re-evaluated on every access, so
    /// the visible steps stay correct as earlier answers change.
    public init(steps: @escaping () -> [Step]) {
        self.stepsProvider = steps
    }

    /// Static flow with a fixed step list.
    public convenience init(steps: [Step]) {
        self.init { steps }
    }

    /// The live step list.
    public var steps: [Step] { stepsProvider() }

    public var count: Int { steps.count }

    /// The step at the current index, clamped into the live list.
    public var current: Step {
        let list = steps
        precondition(!list.isEmpty, "PASOnboardingFlow requires at least one step")
        return list[min(max(index, 0), list.count - 1)]
    }

    public var isFirst: Bool { index <= 0 }

    public var isLast: Bool { index >= count - 1 }

    /// Completed fraction for a progress bar: `(index + 1) / count`, so the
    /// first step already shows progress and a single-step flow reads 1.
    public var progress: Double {
        let total = count
        guard total > 0 else { return 0 }
        return Double(min(index, total - 1) + 1) / Double(total)
    }

    /// Moves one step forward. No-op on the last step.
    public func advance() {
        guard !isLast else { return }
        direction = .forward
        index += 1
    }

    /// Moves one step back. No-op on the first step.
    public func back() {
        guard !isFirst else { return }
        direction = .backward
        index -= 1
    }

    /// Jumps to a step in the live list, setting the direction from the
    /// index comparison. No-op when the step is absent or already current.
    /// For draft resume, hydrate answers first (so a conditional list
    /// computes correctly), then `go(to:)` the restored step.
    public func go(to step: Step) {
        guard let target = steps.firstIndex(of: step), target != index else { return }
        direction = target > index ? .forward : .backward
        index = target
    }
}
