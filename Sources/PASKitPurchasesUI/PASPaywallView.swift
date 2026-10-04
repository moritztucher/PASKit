//
//  PASPaywallView.swift
//  PASKitPurchasesUI
//
//  The dashboard-designed RevenueCat paywall for a placement, reduced to
//  the two outcomes an app acts on: the entitlement became active, or the
//  learner left without it. Mechanism only — layout, copy, prices and the
//  close button's look all come from the RevenueCat dashboard.
//

import PASKitPurchases
import RevenueCat
import RevenueCatUI
import SwiftUI

/// Renders the RevenueCat paywall attached to the offering a placement
/// resolves to (`PASPurchases.offering(forPlacement:)`, falling back to the
/// current offering).
///
/// ```swift
/// enum Entitlement: String { case premium }
/// enum Placement: String { case onboarding, lockedFeature }
///
/// PASPaywallView(placement: Placement.onboarding,
///                entitlement: Entitlement.premium,
///                onEntitled: { … },
///                onClose: { … })
/// ```
///
/// `onEntitled` fires once, after a purchase or restore leaves the
/// entitlement active. `onClose` fires when the paywall asks to be dismissed
/// without that — its close button, or an error the learner acknowledged.
/// Exactly one of the two fires per presentation. The view never dismisses
/// itself: the caller decides what each outcome means, which is what lets it
/// be embedded directly (a non-swipeable "hard" paywall) as well as shown in
/// a `.sheet`.
@available(tvOS, unavailable)
public struct PASPaywallView: View {

    private let placementID: String?
    private let entitlementID: String
    private let displayCloseButton: Bool
    private let fonts: PaywallFontProvider
    private let onEntitled: () -> Void
    private let onClose: () -> Void

    @State private var phase: Phase = .loading
    /// Set once either outcome has been reported, so RevenueCat's
    /// post-purchase dismissal request does not also report a close.
    @State private var isFinished = false

    private enum Phase {
        case loading
        case offering(Offering)
        /// The placement lookup failed (offline, misconfigured). RevenueCat's
        /// own current-offering paywall takes over and shows its error UI.
        case fallback
    }

    /// - Parameters:
    ///   - placementID: Dashboard placement identifier; `nil` shows the
    ///     current offering's paywall.
    ///   - entitlementID: The entitlement a purchase must activate.
    ///   - displayCloseButton: Whether RevenueCat adds its close button.
    ///     Keep it on for an embedded paywall — it is the only way out.
    ///   - fonts: Custom fonts for paywalls that use the app's typeface.
    public init(
        placementID: String?,
        entitlementID: String,
        displayCloseButton: Bool = true,
        fonts: PaywallFontProvider = DefaultPaywallFontProvider(),
        onEntitled: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.placementID = placementID
        self.entitlementID = entitlementID
        self.displayCloseButton = displayCloseButton
        self.fonts = fonts
        self.onEntitled = onEntitled
        self.onClose = onClose
    }

    /// Typed variant for the app's `String`-backed placement and
    /// entitlement enums.
    public init<P: RawRepresentable, E: RawRepresentable>(
        placement: P,
        entitlement: E,
        displayCloseButton: Bool = true,
        fonts: PaywallFontProvider = DefaultPaywallFontProvider(),
        onEntitled: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) where P.RawValue == String, E.RawValue == String {
        self.init(placementID: placement.rawValue, entitlementID: entitlement.rawValue,
                  displayCloseButton: displayCloseButton, fonts: fonts,
                  onEntitled: onEntitled, onClose: onClose)
    }

    public var body: some View {
        content
            .onPurchaseCompleted { info in finishIfEntitled(info) }
            .onRestoreCompleted { info in finishIfEntitled(info) }
            .onRequestedDismissal { finish(entitled: false) }
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .offering(let offering):
            PaywallView(offering: offering, fonts: fonts, displayCloseButton: displayCloseButton)
        case .fallback:
            PaywallView(fonts: fonts, displayCloseButton: displayCloseButton)
        }
    }

    private func load() async {
        guard case .loading = phase else { return }
        guard let placementID else {
            phase = .fallback
            return
        }
        do {
            if let offering = try await PASPurchases.shared.offering(forPlacement: placementID) {
                phase = .offering(offering)
            } else {
                phase = .fallback
            }
        } catch {
            phase = .fallback
        }
    }

    /// A completed restore does not imply an entitlement; a clean restore
    /// with nothing to restore leaves the paywall up (RevenueCat shows its
    /// own "nothing found" message).
    private func finishIfEntitled(_ info: CustomerInfo) {
        guard info.entitlements[entitlementID]?.isActive == true else { return }
        finish(entitled: true)
    }

    private func finish(entitled: Bool) {
        guard !isFinished else { return }
        isFinished = true
        if entitled { onEntitled() } else { onClose() }
    }
}
