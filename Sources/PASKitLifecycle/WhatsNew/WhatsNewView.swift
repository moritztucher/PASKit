//
//  WhatsNewView.swift
//  PASKitLifecycle
//
//  The one-shot "what's new in this release" sheet: a staggered blur-slide
//  entrance over a list of feature cards. PASKit owns the layout, spacing and
//  animation; apps supply the strings and — through three optional slots — their
//  own header mark, card container and CTA. No app content is baked in.
//

import SwiftUI

/// The What's New sheet. Present it with `.sheet(item:)` driven by a
/// ``WhatsNewHighlights``, so the cards arrive as the presentation value.
///
/// ```swift
/// .sheet(item: $highlights) { highlights in
///     WhatsNewView(cards: highlights.cards) { self.highlights = nil }
///         .header { _ in AppMark() }
///         .continueButton { config in BrandButton(config.title, action: config.action) }
/// }
/// ```
///
/// Strings are parameters and are rendered verbatim — PASKit ships no string
/// catalog, so pass already-localized text. Accent colour comes from `.tint`.
///
/// The sheet stays inert (`allowsHitTesting`) until the footer lands, so the CTA
/// cannot be tapped mid-entrance.
public struct WhatsNewView: View {

    // MARK: - Content

    private let title: String
    private let headerSymbol: String?
    private let footerMessage: String?
    private let continueButtonTitle: String
    private let cards: [WhatsNewCard]
    private let onContinue: () -> Void

    // MARK: - Branding Slots

    private var headerSlot: ((WhatsNewHeaderConfiguration) -> AnyView)?
    private var cardSlot: ((WhatsNewCardConfiguration) -> AnyView)?
    private var actionSlot: ((WhatsNewActionConfiguration) -> AnyView)?

    // MARK: - Animation State

    @State private var animateHeader = false
    @State private var animateTitle = false
    @State private var animateCards: [Bool]
    @State private var animateFooter = false

    // MARK: - Initialization

    /// - Parameters:
    ///   - cards: The highlights to show, in order. Normally straight from
    ///     ``WhatsNewGate/highlightsForLaunch(currentBuild:notes:)``.
    ///   - title: Sheet title. Already localized.
    ///   - headerSymbol: SF Symbol shown above the title, tinted. Ignored when a
    ///     ``header(_:)`` slot is supplied.
    ///   - footerMessage: Optional line above the CTA.
    ///   - continueButtonTitle: CTA title.
    ///   - onContinue: Dismissal. The sheet does not dismiss itself.
    public init(
        cards: [WhatsNewCard],
        title: String = "What's New",
        headerSymbol: String? = nil,
        footerMessage: String? = nil,
        continueButtonTitle: String = "Continue",
        onContinue: @escaping () -> Void
    ) {
        self.cards = cards
        self.title = title
        self.headerSymbol = headerSymbol
        self.footerMessage = footerMessage
        self.continueButtonTitle = continueButtonTitle
        self.onContinue = onContinue
        self._animateCards = State(initialValue: Array(repeating: false, count: cards.count))
    }

    /// Declarative variant — cards written inline instead of passed as an array.
    public init(
        title: String = "What's New",
        headerSymbol: String? = nil,
        footerMessage: String? = nil,
        continueButtonTitle: String = "Continue",
        @WhatsNewCardResultBuilder cards: () -> [WhatsNewCard],
        onContinue: @escaping () -> Void
    ) {
        self.init(
            cards: cards(),
            title: title,
            headerSymbol: headerSymbol,
            footerMessage: footerMessage,
            continueButtonTitle: continueButtonTitle,
            onContinue: onContinue
        )
    }

    // MARK: - Slots

    /// Replaces the stock header mark (the tinted `headerSymbol`) with the app's
    /// own — a gradient glyph, a logo, a wordmark. The entrance animation still
    /// applies.
    public func header<Content: View>(
        @ViewBuilder _ builder: @escaping (WhatsNewHeaderConfiguration) -> Content
    ) -> WhatsNewView {
        var copy = self
        copy.headerSlot = { AnyView(builder($0)) }
        return copy
    }

    /// Wraps each stock card row in the app's own container — a branded card
    /// surface, a border, a glow. Wrap `configuration.content`; do not rebuild it.
    public func cardContainer<Content: View>(
        @ViewBuilder _ builder: @escaping (WhatsNewCardConfiguration) -> Content
    ) -> WhatsNewView {
        var copy = self
        copy.cardSlot = { AnyView(builder($0)) }
        return copy
    }

    /// Replaces the stock CTA with the app's own button. Must invoke
    /// `configuration.action`.
    public func continueButton<Content: View>(
        @ViewBuilder _ builder: @escaping (WhatsNewActionConfiguration) -> Content
    ) -> WhatsNewView {
        var copy = self
        copy.actionSlot = { AnyView(builder($0)) }
        return copy
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                        .blurSlide(animateHeader)

                    Text(title)
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity)
                        .blurSlide(animateTitle)

                    cardsView
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24) // keeps the last card clear of the footer
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                if let footerMessage {
                    Text(footerMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                actionView
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .blurSlide(animateFooter)
        }
        .interactiveDismissDisabled()
        .allowsHitTesting(animateFooter)
        .task { await animateSequence() }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        let configuration = WhatsNewHeaderConfiguration(symbol: headerSymbol, title: title)
        if let headerSlot {
            headerSlot(configuration)
        } else if let headerSymbol {
            Image(systemName: headerSymbol)
                .font(.system(size: 48))
                .symbolVariant(.fill)
                .foregroundStyle(.tint)
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private var cardsView: some View {
        ForEach(cards.indices, id: \.self) { index in
            let card = cards[index]
            let configuration = WhatsNewCardConfiguration(
                card: card,
                content: .init(stock: AnyView(stockCard(card)))
            )
            Group {
                if let cardSlot {
                    cardSlot(configuration)
                } else {
                    configuration.content
                }
            }
            .blurSlide(animateCards[index])
        }
    }

    private func stockCard(_ card: WhatsNewCard) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: card.symbol)
                .font(.title2)
                .symbolVariant(.fill)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(AnyShapeStyle(.tint).opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                Text(card.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action

    @ViewBuilder
    private var actionView: some View {
        let configuration = WhatsNewActionConfiguration(title: continueButtonTitle, action: onContinue)
        if let actionSlot {
            actionSlot(configuration)
        } else {
            Button(configuration.title, action: configuration.action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Animation

    /// Header, title, then each card in turn, then the footer. The whole sheet is
    /// inert until `animateFooter` lands — if this sequence is ever broken the
    /// sheet is dead, so the guard and the sequence must move together.
    private func animateSequence() async {
        guard !animateHeader else { return }
        await delayed(0.3) { animateHeader = true }
        await delayed(0.2) { animateTitle = true }
        try? await Task.sleep(for: .seconds(0.2))
        for index in animateCards.indices {
            await delayed(0.1) { animateCards[index] = true }
        }
        await delayed(0.2) { animateFooter = true }
    }

    private func delayed(_ delay: Double, action: @escaping () -> Void) async {
        try? await Task.sleep(for: .seconds(delay))
        withAnimation(.smooth) { action() }
    }
}

// MARK: - Blur Slide Transition

private extension View {
    @ViewBuilder
    func blurSlide(_ show: Bool) -> some View {
        compositingGroup()
            .blur(radius: show ? 0 : 10)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 80)
    }
}
