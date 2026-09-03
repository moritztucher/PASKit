//
//  ReleaseNote.swift
//  PASKitLifecycle
//
//  One shipped build's release notes — the single authoring source behind both
//  `ChangelogView` (the full retrospective list) and `WhatsNewView` (the one-shot
//  post-update sheet). Apps author one array of these, newest build first.
//

import Foundation

/// One shipped build's release notes, in two shapes: the full `items` list
/// `ChangelogView` renders, and the short `highlights` cards `WhatsNewView` shows
/// after a build bump. Typically only the newest build carries any `highlights`.
///
/// `build` is the identity and the ordering key — `WhatsNewGate` keys its cadence
/// on it, so builds must be unique and strictly increasing across a release list.
public struct ReleaseNote: Identifiable, Sendable, Hashable {

    /// Build number — `CFBundleVersion`. Unique per release note.
    public let build: Int

    /// Marketing version — `CFBundleShortVersionString`, e.g. `"1.2.0"`.
    public let version: String

    /// Release date. Rendered localized by `ChangelogView`; `nil` hides it.
    public let date: Date?

    /// The full change list — what `ChangelogView` renders.
    public let items: [ChangelogItem]

    /// The short highlight cards — what `WhatsNewView` shows after a build bump.
    ///
    /// Empty means "not worth interrupting for": `WhatsNewGate` absorbs such a
    /// build silently rather than presenting an empty sheet. This is the lever
    /// for App-Store-era cadence — author highlights for x.y bumps, ship `[]`
    /// for patch builds — and it needs no change to the gate.
    public let highlights: [WhatsNewCard]

    public var id: Int { build }

    /// `"1.2.0 (45)"` — version and build, the form both changelog surfaces show.
    public var displayVersion: String { "\(version) (\(build))" }

    public init(
        build: Int,
        version: String,
        date: Date? = nil,
        items: [ChangelogItem] = [],
        highlights: [WhatsNewCard] = []
    ) {
        self.build = build
        self.version = version
        self.date = date
        self.items = items
        self.highlights = highlights
    }

    /// Authoring convenience: an ISO `"2026-09-02"` date plus prefix-tagged change
    /// strings, so a release list stays a literal array of one-liners. See
    /// ``ChangelogItem/init(prefixed:)`` for the prefix vocabulary.
    ///
    /// An unparseable `date` becomes `nil` (the date is simply not shown) rather
    /// than trapping — a typo in a release list should not crash the app.
    public init(
        build: Int,
        version: String,
        date: String?,
        changes: [String],
        highlights: [WhatsNewCard] = []
    ) {
        self.init(
            build: build,
            version: version,
            date: date.flatMap(Self.date(fromISO:)),
            items: changes.map(ChangelogItem.init(prefixed:)),
            highlights: highlights
        )
    }

    /// Equal by `build` alone. `WhatsNewCard` carries a per-instance `UUID`, so
    /// field-wise equality would never hold across two reads of the same list —
    /// and `build` is the identity anyway.
    public static func == (lhs: ReleaseNote, rhs: ReleaseNote) -> Bool {
        lhs.build == rhs.build
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(build)
    }

    /// `"2026-09-02"` → noon UTC on that day. Noon, not midnight, so rendering the
    /// date in a timezone behind UTC cannot roll it back to the previous day.
    private static func date(fromISO string: String) -> Date? {
        let parts = string.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }
}
