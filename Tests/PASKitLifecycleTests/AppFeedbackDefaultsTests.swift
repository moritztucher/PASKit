//
//  AppFeedbackDefaultsTests.swift
//  PASKitLifecycleTests
//
//  Same rationale as AppRatingDefaultsTests: presentAppFeedback's modifier
//  is SwiftUI and not unit-testable, but silently changing the
//  installed-user keys or the shipped copy is the regression that matters.
//

import Testing
@testable import PASKitLifecycle

@Suite("presentAppFeedback defaults")
struct AppFeedbackDefaultsTests {

    @Test("Standard keys are the ones shipped in v0.3.x")
    func standardKeys() {
        #expect(PASAppFeedbackKeys.standard.isCompleted == "paskit.appFeedback.isComplete")
        #expect(PASAppFeedbackKeys.standard.isInitialPromptShown == "paskit.appFeedback.isInitialPromptShown")
    }

    @Test("Standard copy is the shipped copy")
    func standardCopy() {
        let copy = PASAppFeedbackCopy.standard
        #expect(copy.initialTitle == "Got a moment to share feedback?")
        #expect(copy.initialMessage == nil)
        #expect(copy.initialAccept == "Yes, Continue!")
        #expect(copy.askLater == "Ask Later")
        #expect(copy.neverAsk == "Never Ask Me Again")
        #expect(copy.followUpTitle == "Got a moment to share feedback?")
        #expect(copy.followUpMessage == nil)
        #expect(copy.followUpAccept == "Yes!")
        #expect(copy.followUpDecline == "Nope")
    }

    @Test("Custom keys and copy round-trip")
    func customKeysAndCopyRoundTrip() {
        let keys = PASAppFeedbackKeys(isCompleted: "isFeedbackComplete", isInitialPromptShown: "isFeedbackInitialShown")
        #expect(keys.isCompleted == "isFeedbackComplete")
        #expect(keys.isInitialPromptShown == "isFeedbackInitialShown")

        let copy = PASAppFeedbackCopy(
            initialTitle: "Got a sec?",
            initialMessage: "We'd love to hear from you.",
            initialAccept: "Sure!",
            askLater: "Later",
            neverAsk: "No Thanks",
            followUpTitle: "Got a sec now?",
            followUpMessage: "Won't take long.",
            followUpAccept: "Okay!",
            followUpDecline: "Not Now"
        )
        #expect(copy.initialTitle == "Got a sec?")
        #expect(copy.initialMessage == "We'd love to hear from you.")
        #expect(copy.initialAccept == "Sure!")
        #expect(copy.askLater == "Later")
        #expect(copy.neverAsk == "No Thanks")
        #expect(copy.followUpTitle == "Got a sec now?")
        #expect(copy.followUpMessage == "Won't take long.")
        #expect(copy.followUpAccept == "Okay!")
        #expect(copy.followUpDecline == "Not Now")
    }
}
