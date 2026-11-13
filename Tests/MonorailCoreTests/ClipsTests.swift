@testable import MonorailCore
import XCTest

final class ClipsTests: XCTestCase {
    func testNewestFirstWithoutRepeats() {
        var h = ClipHistory(keep: 3)
        h.add("one"); h.add("two"); h.add("one")
        XCTAssertEqual(h.clips.map(\.text), ["one", "two"])
        h.add("   ")
        XCTAssertEqual(h.clips.count, 2)
    }

    func testPinnedClipsSurviveTrimAndClear() {
        var h = ClipHistory(keep: 2)
        h.add("keep me")
        h.togglePin(h.clips[0].id)
        h.add("a"); h.add("b"); h.add("c")
        XCTAssertEqual(h.shown().map(\.text), ["keep me", "c", "b"])
        h.clear()
        XCTAssertEqual(h.clips.map(\.text), ["keep me"])
    }

    func testSearchAndPreview() {
        var h = ClipHistory()
        h.add("Hello\n   world"); h.add("other")
        XCTAssertEqual(h.shown(matching: "WORLD").count, 1)
        XCTAssertEqual(h.clips[1].preview(), "Hello world")
        XCTAssertEqual(ClipHistory.Clip(text: String(repeating: "a", count: 100)).preview(10).count, 10)
    }

    func testPlainText() {
        XCTAssertEqual(PlainText.clean("a\u{00A0}b  \r\nc\u{200B}"), "a b\nc")
        XCTAssertEqual(PlainText.clean("“hi” it’s", straightQuotes: true), "\"hi\" it's")
        XCTAssertEqual(PlainText.counts("two words\nthree").words, 3)
    }

    func testColourFormats() {
        let c = PickedColour(red: 1, green: 0.5, blue: 0)
        XCTAssertEqual(c.hex, "#FF8000")
        XCTAssertEqual(c.rgb, "rgb(255, 128, 0)")
        XCTAssertEqual(c.hsl, "hsl(30, 100%, 50%)")
        XCTAssertTrue(PickedColour(red: 1, green: 1, blue: 1).prefersDarkText)
        XCTAssertFalse(PickedColour(red: 0, green: 0, blue: 0.4).prefersDarkText)
    }
}
