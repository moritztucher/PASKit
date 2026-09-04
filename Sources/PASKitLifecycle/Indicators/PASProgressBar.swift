//
//  PASProgressBar.swift
//  PASKitLifecycle
//
//  Slim capsule progress bar. System-styled per PASKit convention: track in
//  `.quaternary`, fill in `.tint` — brand it at the call site with
//  `.tint(.brand)`. Reduce Motion-aware (via `pasAnimation`).
//

import PASKitCore
import SwiftUI

/// A slim, animated capsule progress bar — the linear sibling of
/// `PASProgressRing`.
///
/// ```swift
/// PASProgressBar(progress: flow.progress)
///     .tint(.brand)
///     .padding(.horizontal)
/// ```
public struct PASProgressBar: View {
    private let progress: Double
    private let height: CGFloat

    /// - Parameters:
    ///   - progress: Completed fraction; clamped to 0…1.
    ///   - height: Bar height in points. Defaults to 4.
    public init(progress: Double, height: CGFloat = 4) {
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(.tint)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: height)
        .pasAnimation(.easeInOut(duration: 0.3), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

/// Renamed in v0.3.2 — the bar was never onboarding-specific. Alias removed in the next minor.
@available(*, deprecated, renamed: "PASProgressBar")
public typealias PASOnboardingProgressBar = PASProgressBar

#Preview {
    VStack(spacing: 24) {
        PASProgressBar(progress: 0.25)
        PASProgressBar(progress: 0.6, height: 6)
            .tint(.orange)
        PASProgressBar(progress: 1)
    }
    .padding()
}
