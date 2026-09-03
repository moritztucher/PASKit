//
//  ReleaseNoteTests.swift
//  PASKitLifecycleTests
//
//  Pins the authoring conveniences both changelog surfaces depend on: the prefix
//  vocabulary and the ISO date parse.
//

import Foundation
import Testing
@testable import PASKitLifecycle

@Suite("ChangelogItem prefixes")
struct ChangelogItemTests {

    @Test("Each marker maps to its kind and drops the marker from the text", arguments: [
        ("+ Added a thing", ChangelogItem.added("Added a thing")),
        ("> Changed a thing", ChangelogItem.changed("Changed a thing")),
        ("~ Fixed a thing", ChangelogItem.fixed("Fixed a thing")),
        ("* Noted a thing", ChangelogItem.note("Noted a thing")),
    ])
    func markersMap(input: String, expected: ChangelogItem) {
        #expect(ChangelogItem(prefixed: input) == expected)
    }

    @Test("An unmarked line keeps its whole text as a note")
    func unmarkedLineIsWholeNote() {
        #expect(ChangelogItem(prefixed: "Just a line") == .note("Just a line"))
    }

    @Test("Leading and trailing whitespace is trimmed on both sides of the marker")
    func whitespaceIsTrimmed() {
        #expect(ChangelogItem(prefixed: "  +   Spaced out  ") == .added("Spaced out"))
    }
}

@Suite("ReleaseNote")
struct ReleaseNoteTests {

    @Test("An ISO date parses to that calendar day")
    func isoDateParses() throws {
        let note = ReleaseNote(build: 1, version: "1.0.0", date: "2026-09-02", changes: [])
        let date = try #require(note.date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        #expect(calendar.component(.year, from: date) == 2026)
        #expect(calendar.component(.month, from: date) == 9)
        #expect(calendar.component(.day, from: date) == 2)
    }

    @Test("An unparseable date degrades to nil instead of trapping", arguments: ["nope", "2026-09", "", "2026-13-99x"])
    func badDateIsNil(input: String) {
        #expect(ReleaseNote(build: 1, version: "1.0.0", date: input, changes: []).date == nil)
    }

    @Test("displayVersion renders version and build")
    func displayVersionRenders() {
        #expect(ReleaseNote(build: 45, version: "1.2.0").displayVersion == "1.2.0 (45)")
    }

    @Test("Identity and equality are the build alone")
    func equalityIsBuildOnly() {
        let a = ReleaseNote(build: 7, version: "1.0.0", highlights: [WhatsNewCard(symbol: "a", title: "A", subtitle: "a")])
        let b = ReleaseNote(build: 7, version: "9.9.9")

        #expect(a == b, "per-instance card UUIDs must not defeat equality")
        #expect(a.id == 7)
    }
}
