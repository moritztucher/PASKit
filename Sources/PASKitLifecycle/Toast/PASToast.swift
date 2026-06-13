//
//  PASToast.swift
//  PASKitLifecycle
//
//  Default toast content: optional symbol, message, optional trailing
//  action (the Undo case). System styling — material background with a
//  Reduce Transparency fallback; brand via `.tint` at the call site. Apps
//  with a locked design language pass their own view to `pasToast` and
//  share only the lifecycle.
//

import SwiftUI

/// System-styled toast row for `View.pasToast`.
///
/// ```swift
/// PASToast(symbol: "checkmark.circle.fill", symbolTint: .green,
///          message: "Saved to Photos")
/// PASToast(message: "Set 4 logged", actionTitle: "Undo") { undo() }
/// ```
public struct PASToast: View {
    private let symbol: String?
    private let symbolTint: Color?
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - symbol: Optional SF Symbol shown leading.
    ///   - symbolTint: Symbol color; `nil` uses the environment tint.
    ///   - message: The toast text (two lines max).
    ///   - actionTitle: Optional trailing button title (e.g. "Undo").
    ///   - action: Runs on action tap. The toast does not auto-dismiss on
    ///     tap — clear the presentation state in the handler if desired.
    public init(
        symbol: String? = nil,
        symbolTint: Color? = nil,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(symbolTint ?? .accentColor)
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let actionTitle, let action {
                Spacer(minLength: 8)
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(backgroundShape)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThickMaterial)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PASToast(symbol: "checkmark.circle.fill", symbolTint: .green, message: "Saved to Photos")
        PASToast(message: "Set 4 logged · Bench Press", actionTitle: "Undo") {}
    }
    .padding()
}
