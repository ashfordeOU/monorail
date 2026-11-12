import XCTest
@testable import MonorailCore

final class ReleaseNotesTests: XCTestCase {
    let changelog = """
    # Changelog

    ## [Unreleased]

    ## [1.8.0] - 2026-11-13

    ### Changed
    - **One panel, pages inside it.** Clicking the Monorail icon opens a single panel. It slides with a spring.
    - **Three battery rings.** Charge, time left and drain against your usual, drawn in with a spring.
    - **The menu bar icon stays the same.** Only the Monorail icon shows.
    - A plain line without a title.

    ### Fixed
    - **A crash.** Fixed.

    ## [1.7.30] - 2026-11-12

    ### Fixed
    - **Something small.** Now right.
    """

    func testSectionStopsAtTheNextVersion() {
        let lines = ReleaseNotes.section("1.8.0", in: changelog)
        XCTAssertEqual(lines.first, "### Changed")
        XCTAssertFalse(lines.contains { $0.contains("Something small") })
    }

    func testHighlightsTakeTitleAndFirstSentence() {
        let rows = ReleaseNotes.highlights(ReleaseNotes.section("1.8.0", in: changelog))
        XCTAssertEqual(rows.map(\.title), ["One panel, pages inside it", "Three battery rings", "The menu bar icon stays the same"])
        XCTAssertEqual(rows[0].text, "Clicking the Monorail icon opens a single panel.")
        XCTAssertEqual(rows[0].kind, .panel)
        XCTAssertEqual(rows[1].kind, .battery)
        XCTAssertEqual(rows[2].kind, .menuBar)
    }

    func testFixesOnlyWhenNothingElse() {
        XCTAssertEqual(ReleaseNotes.highlights(ReleaseNotes.section("1.7.30", in: changelog)).map(\.title), ["Something small"])
    }

    func testLimit() {
        XCTAssertEqual(ReleaseNotes.highlights(ReleaseNotes.section("1.8.0", in: changelog), limit: 2).count, 2)
    }

    func testOnlyAddedOrChangedIsNotable() {
        XCTAssertTrue(ReleaseNotes.isNotable(ReleaseNotes.section("1.8.0", in: changelog)))
        XCTAssertFalse(ReleaseNotes.isNotable(ReleaseNotes.section("1.7.30", in: changelog)))
    }

    func testPlainTextAndLongSentences() {
        XCTAssertEqual(ReleaseNotes.plain("Use `monorail say` and [the guide](https://x.y) **now**"), "Use monorail say and the guide now")
        let long = String(repeating: "word ", count: 40)
        let short = ReleaseNotes.firstSentence(long)
        XCTAssertLessThanOrEqual(short.count, 110)
        XCTAssertTrue(short.hasSuffix("…"))
    }
}
