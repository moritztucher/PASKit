//
//  View+PASToast.swift
//  PASKitLifecycle
//
//  Toast presentation lifecycle: overlay placement, slide+fade transition
//  (fade-only under Reduce Motion), and auto-dismiss that re-arms
//  correctly on re-trigger via structured task cancellation — the stale
//  -timer bug apps write with a bare Task.sleep can't happen here.
//

import SwiftUI

public extension View {
    /// Presents a toast while `isPresented` is true, auto-dismissing after
    /// `duration`.
    ///
    /// ```swift
    /// .pasToast(isPresented: $showUndo, duration: 5) {
    ///     PASToast(symbol: "checkmark.circle.fill", symbolTint: .green,
    ///              message: "Habit completed", actionTitle: "Undo") { undo() }
    /// }
    /// ```
    ///
    /// When consecutive triggers change the toast's content (e.g. "Set 3
    /// logged" then "Set 4 logged"), use the `item:` variant — a new item
    /// restarts the dismiss timer; a Bool that stays `true` does not.
    func pasToast<Content: View>(
        isPresented: Binding<Bool>,
        duration: TimeInterval? = 4,
        alignment: Alignment = .bottom,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(PASBoolToastModifier(
            isPresented: isPresented,
            duration: duration,
            alignment: alignment,
            toast: content
        ))
    }

    /// Presents a toast for a non-nil `item`, auto-dismissing after
    /// `duration`. Setting a new item replaces the content and restarts
    /// the timer.
    ///
    /// ```swift
    /// .pasToast(item: $savedConfirmation, duration: 2) { item in
    ///     PASToast(symbol: "checkmark.circle.fill", symbolTint: .green,
    ///              message: item.text)
    /// }
    /// ```
    ///
    /// - Parameter duration: Seconds until auto-dismiss; `nil` keeps the
    ///   toast until the caller clears the state.
    func pasToast<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        duration: TimeInterval? = 4,
        alignment: Alignment = .bottom,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(PASItemToastModifier(
            item: item,
            duration: duration,
            alignment: alignment,
            toast: content
        ))
    }
}

private struct PASBoolToastModifier<Toast: View>: ViewModifier {
    @Binding var isPresented: Bool
    let duration: TimeInterval?
    let alignment: Alignment
    @ViewBuilder let toast: () -> Toast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            ZStack {
                if isPresented {
                    toast()
                        .padding()
                        .transition(pasToastTransition(alignment: alignment, reduceMotion: reduceMotion))
                        .task {
                            guard let duration else { return }
                            try? await Task.sleep(for: .seconds(duration))
                            guard !Task.isCancelled else { return }
                            isPresented = false
                        }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
        }
    }
}

private struct PASItemToastModifier<Item: Identifiable, Toast: View>: ViewModifier {
    @Binding var item: Item?
    let duration: TimeInterval?
    let alignment: Alignment
    @ViewBuilder let toast: (Item) -> Toast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            ZStack {
                if let presented = item {
                    toast(presented)
                        .padding()
                        .transition(pasToastTransition(alignment: alignment, reduceMotion: reduceMotion))
                        .task(id: presented.id) {
                            guard let duration else { return }
                            try? await Task.sleep(for: .seconds(duration))
                            guard !Task.isCancelled else { return }
                            item = nil
                        }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: item?.id)
        }
    }
}

private func pasToastTransition(alignment: Alignment, reduceMotion: Bool) -> AnyTransition {
    guard !reduceMotion else { return .opacity }
    if alignment == .top || alignment == .topLeading || alignment == .topTrailing {
        return .move(edge: .top).combined(with: .opacity)
    }
    return .move(edge: .bottom).combined(with: .opacity)
}
