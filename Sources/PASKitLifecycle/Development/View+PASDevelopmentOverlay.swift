//
//  View+PASDevelopmentOverlay.swift
//  PASKitLifecycle
//
//  DEBUG-only floating "DEV" capsule that opens the app's dev menu as a
//  sheet. Release builds compile the modifier to a no-op — the symbol
//  stays available, so call sites build in every configuration.
//

import SwiftUI

public extension View {
    /// Attaches a floating DEV button that presents `menu` as a sheet.
    /// No-op (zero UI) in release builds.
    ///
    /// ```swift
    /// ContentView()
    ///     .pasDevelopmentOverlay {
    ///         #if DEBUG
    ///         MyDevMenu()   // typically built on PASDevelopmentMenu
    ///         #endif
    ///     }
    /// ```
    ///
    /// The menu closure is never invoked in release, but it must compile —
    /// gate DEBUG-only menu types inside the closure (as above) or gate
    /// the whole call site.
    @ViewBuilder
    func pasDevelopmentOverlay<Menu: View>(
        alignment: Alignment = .bottomLeading,
        @ViewBuilder menu: @escaping () -> Menu
    ) -> some View {
        #if DEBUG
        modifier(PASDevelopmentOverlayModifier(alignment: alignment, menu: menu))
        #else
        self
        #endif
    }
}

#if DEBUG
private struct PASDevelopmentOverlayModifier<Menu: View>: ViewModifier {
    let alignment: Alignment
    @ViewBuilder let menu: () -> Menu

    @State private var isMenuPresented = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                Button {
                    isMenuPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("DEV")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.tint))
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityIdentifier("PAS_DEV_OVERLAY")
            }
            .sheet(isPresented: $isMenuPresented) {
                menu()
            }
    }
}
#endif
