//
//  PASProgressRing.swift
//  PASKitLifecycle
//
//  Circular progress indicator — the circular sibling of
//  PASOnboardingProgressBar. System-styled: track `.quaternary`, fill
//  `.tint`. Brand it at the call site with `.tint(.brand)` and an optional
//  track color. The center content is the app's (a fraction, a glyph, …).
//

import SwiftUI

/// A circular progress ring with an optional center label.
///
/// ```swift
/// PASProgressRing(progress: 0.75, lineWidth: 6) {
///     Text("3/4").font(.caption.bold())
/// }
/// .tint(.brand)
/// ```
public struct PASProgressRing<Label: View>: View {
    private let progress: Double
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let trackColor: Color
    private let label: Label

    /// - Parameters:
    ///   - progress: Completed fraction; clamped to 0…1.
    ///   - size: Ring diameter in points. Defaults to 48.
    ///   - lineWidth: Stroke width. Defaults to 4.
    ///   - trackColor: Unfilled-track color. Defaults to a faint adaptive grey.
    ///   - label: Center content (omit for a bare ring).
    public init(
        progress: Double,
        size: CGFloat = 48,
        lineWidth: CGFloat = 4,
        trackColor: Color = Color.secondary.opacity(0.25),
        @ViewBuilder label: () -> Label
    ) {
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        self.size = size
        self.lineWidth = lineWidth
        self.trackColor = trackColor
        self.label = label()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress)
            label
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

public extension PASProgressRing where Label == EmptyView {
    /// A bare ring with no center content.
    init(
        progress: Double,
        size: CGFloat = 48,
        lineWidth: CGFloat = 4,
        trackColor: Color = Color.secondary.opacity(0.25)
    ) {
        self.init(progress: progress, size: size, lineWidth: lineWidth, trackColor: trackColor) {
            EmptyView()
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        PASProgressRing(progress: 0.3, size: 32, lineWidth: 3)
        PASProgressRing(progress: 0.75, lineWidth: 6) {
            Text("3/4").font(.system(.caption, weight: .bold))
        }
        .tint(.orange)
        PASProgressRing(progress: 1, size: 64, lineWidth: 8)
    }
    .padding()
}
