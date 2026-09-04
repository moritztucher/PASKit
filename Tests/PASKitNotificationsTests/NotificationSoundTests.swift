//
//  NotificationSoundTests.swift
//  PASKitNotificationsTests
//
//  Covers PASNotificationSound's Bool-literal shim and PASNotificationRequest's
//  compile-time compatibility with the old `sound: Bool` spelling. Value types
//  only — never call anything on PASNotifications.shared here:
//  UNUserNotificationCenter.current() aborts in a bundle-less macOS test host.
//

import Testing
import UserNotifications
@testable import PASKitNotifications

@Suite("PASNotificationSound")
struct NotificationSoundTests {

    @Test("Boolean literals map to default and silent")
    func booleanLiteralsMap() {
        let on: PASNotificationSound = true
        let off: PASNotificationSound = false
        #expect(on == .default)
        #expect(off == .silent)
    }

    @Test("unSound maps silent to nil, default to .default, named to a named sound")
    func unSoundMapping() {
        #expect(PASNotificationSound.silent.unSound == nil)
        #expect(PASNotificationSound.default.unSound == .default)
        #expect(PASNotificationSound.named("rest_complete.wav").unSound != nil)
    }

    @Test("Request keeps compiling with the Bool spelling and defaults to the system sound")
    func requestBoolSpellingCompatibility() {
        let defaulted = PASNotificationRequest(
            id: "a", title: "t", body: "b", trigger: .interval(60, repeats: false)
        )
        #expect(defaulted.sound == .default)

        let silent = PASNotificationRequest(
            id: "b", title: "t", body: "b", sound: false, trigger: .interval(60, repeats: false)
        )
        #expect(silent.sound == .silent)

        let named = PASNotificationRequest(
            id: "c", title: "t", body: "b", sound: .named("x.wav"), trigger: .interval(60, repeats: false)
        )
        #expect(named.sound == .named("x.wav"))
    }
}
