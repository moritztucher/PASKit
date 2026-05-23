//
//  WhatsNewView.swift
//  PASKitLifecycle
//
//  Declarative "what's new in this version" sheet, with a staggered blur-slide
//  entrance. Cards declared via `@WhatsNewCardResultBuilder`. Strings and
//  symbols are caller-supplied — no XueTang content baked in.
//

import SwiftUI

public struct WhatsNewView: View {

    public let appName: String?
    public let title: String
    public let footerMessage: String?
    public let continueButtonTitle: String
    public let cards: [WhatsNewCard]
    public let onContinue: () -> Void

    @State private var animateAppName = false
    @State private var animateTitle = false
    @State private var animateCards: [Bool]
    @State private var animateFooter = false

    public init(
        appName: String? = nil,
        title: String = "What's New",
        footerMessage: String? = nil,
        continueButtonTitle: String = "Continue",
        @WhatsNewCardResultBuilder cards: () -> [WhatsNewCard],
        onContinue: @escaping () -> Void
    ) {
        self.appName = appName
        self.title = title
        self.footerMessage = footerMessage
        self.continueButtonTitle = continueButtonTitle
        let builtCards = cards()
        self.cards = builtCards
        self.onContinue = onContinue
        self._animateCards = State(initialValue: Array(repeating: false, count: builtCards.count))
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    if let appName {
                        Text(appName)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.tint)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                            .padding(.bottom, 4)
                            .blurSlide(animateAppName)
                    }
                    Text(title)
                        .font(.title.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                        .blurSlide(appName == nil ? animateAppName : animateTitle)

                    cardsView
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                if let footerMessage {
                    Text(footerMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(continueButtonTitle, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 16)
            }
            .blurSlide(animateFooter)
        }
        .padding(.horizontal, 24)
        .interactiveDismissDisabled()
        .allowsHitTesting(animateFooter)
        .task { await animateSequence() }
    }

    @ViewBuilder
    private var cardsView: some View {
        ForEach(cards.indices, id: \.self) { index in
            let card = cards[index]
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: card.symbol)
                    .resizable()
                    .scaledToFit()
                    .symbolVariant(.fill)
                    .foregroundStyle(.tint)
                    .frame(width: 45, height: 45)

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(card.subtitle)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)
            .blurSlide(animateCards[index])
        }
    }

    private func animateSequence() async {
        guard !animateAppName else { return }
        await delayed(0.35) { animateAppName = true }
        if appName != nil {
            await delayed(0.2) { animateTitle = true }
        }
        try? await Task.sleep(for: .seconds(0.2))
        for index in animateCards.indices {
            await delayed(Double(index) * 0.1) { animateCards[index] = true }
        }
        await delayed(0.2) { animateFooter = true }
    }

    private func delayed(_ delay: Double, action: @escaping () -> Void) async {
        try? await Task.sleep(for: .seconds(delay))
        withAnimation(.smooth) { action() }
    }
}

extension View {
    @ViewBuilder
    func blurSlide(_ show: Bool) -> some View {
        compositingGroup()
            .blur(radius: show ? 0 : 10)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 100)
    }
}

/// One feature card in a `WhatsNewView`. `symbol` is an SF Symbol name.
public struct WhatsNewCard: Identifiable, Sendable {
    public var id = UUID().uuidString
    public let symbol: String
    public let title: String
    public let subtitle: String

    public init(symbol: String, title: String, subtitle: String) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
    }
}

/// Declarative card builder for `WhatsNewView`.
@resultBuilder
public struct WhatsNewCardResultBuilder {
    public static func buildBlock(_ components: WhatsNewCard...) -> [WhatsNewCard] {
        Array(components)
    }
}
