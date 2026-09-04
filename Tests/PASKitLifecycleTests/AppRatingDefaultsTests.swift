//
//  AppRatingDefaultsTests.swift
//  PASKitLifecycleTests
//
//  presentAppRating's modifier is SwiftUI and not unit-testable, but the
//  regression that matters is: silently changing the installed-user keys
//  or the shipped copy. These pin both.
//

import Testing
@testable import PASKitLifecycle

@Suite("presentAppRating defaults")
struct AppRatingDefaultsTests {

    @Test("Standard keys are the ones shipped in v0.3.x")
    func standardKeys() {
        #expect(PASAppRatingKeys.standard.isCompleted == "paskit.appRating.isComplete")
        #expect(PASAppRatingKeys.standard.isInitialPromptShown == "paskit.appRating.isInitialPromptShown")
    }

    @Test("Standard copy is the shipped copy")
    func standardCopy() {
        let copy = PASAppRatingCopy.standard
        #expect(copy.initialTitle == "Would you like to rate the app?")
        #expect(copy.initialMessage == nil)
        #expect(copy.initialAccept == "Yes, Continue!")
        #expect(copy.askLater == "Ask Later")
        #expect(copy.neverAsk == "Never Ask Me Again")
        #expect(copy.followUpTitle == "Would you like to rate the app?")
        #expect(copy.followUpMessage == nil)
        #expect(copy.followUpAccept == "Yes!")
        #expect(copy.followUpDecline == "Nope")
    }

    @Test("Custom keys and copy round-trip")
    func customKeysAndCopyRoundTrip() {
        let keys = PASAppRatingKeys(isCompleted: "isRatingInteractionComplete", isInitialPromptShown: "isInitialPromptComplete")
        #expect(keys.isCompleted == "isRatingInteractionComplete")
        #expect(keys.isInitialPromptShown == "isInitialPromptComplete")

        let copy = PASAppRatingCopy(
            initialTitle: "Enjoying the app?",
            initialMessage: "A rating helps a lot.",
            initialAccept: "Yes, Rate It!",
            askLater: "Later",
            neverAsk: "No Thanks",
            followUpTitle: "Enjoying it?",
            followUpMessage: "Just a moment.",
            followUpAccept: "Rate Now",
            followUpDecline: "Not Now"
        )
        #expect(copy.initialTitle == "Enjoying the app?")
        #expect(copy.initialMessage == "A rating helps a lot.")
        #expect(copy.initialAccept == "Yes, Rate It!")
        #expect(copy.askLater == "Later")
        #expect(copy.neverAsk == "No Thanks")
        #expect(copy.followUpTitle == "Enjoying it?")
        #expect(copy.followUpMessage == "Just a moment.")
        #expect(copy.followUpAccept == "Rate Now")
        #expect(copy.followUpDecline == "Not Now")
    }
}
