@testable import MonorailCore
import XCTest

final class ClipboardTwoTests: XCTestCase {
    func testKinds() {
        XCTAssertEqual(ClipKind.detect("https://monorail.ashforde.org/docs"), .link)
        XCTAssertEqual(ClipKind.detect("hello@ashforde.org"), .email)
        XCTAssertEqual(ClipKind.detect("#FF8000"), .colour)
        XCTAssertEqual(ClipKind.detect("rgb(255, 128, 0)"), .colour)
        XCTAssertEqual(ClipKind.detect("1,234.50"), .number)
        XCTAssertEqual(ClipKind.detect("+44 20 7946 0958"), .phone)
        XCTAssertEqual(ClipKind.detect("func go() {\n    return 1\n}"), .code)
        XCTAssertEqual(ClipKind.detect("const a = () => b;"), .code)
        XCTAssertEqual(ClipKind.detect("Lunch at one? Let me know."), .text)
    }

    func testSensitive() {
        XCTAssertEqual(SensitiveClip.detect("key: sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123"), "Anthropic key")
        XCTAssertEqual(SensitiveClip.detect("ghp_abcdefghijklmnopqrstuvwxyz0123456789"), "GitHub token")
        XCTAssertEqual(SensitiveClip.detect("AKIAABCDEFGHIJKLMNOP"), "AWS key")
        XCTAssertEqual(SensitiveClip.detect("-----BEGIN OPENSSH PRIVATE KEY-----\nabc"), "Private key")
        XCTAssertEqual(SensitiveClip.detect("4242 4242 4242 4242"), "Card number")
        XCTAssertNil(SensitiveClip.detect("4242 4242 4242 4241"))
        XCTAssertNil(SensitiveClip.detect("Call me on 020 7946 0958 tomorrow"))
        XCTAssertEqual(SensitiveClip.detect("password: hunter2hunter2"), "Password")
        var h = ClipHistory()
        h.add("4242424242424242", sensitive: "Card number")
        XCTAssertEqual(h.clips[0].preview(), "Card number •••••••")
        h.reveal(h.clips[0].id)
        XCTAssertEqual(h.clips[0].preview(), "4242424242424242")
    }

    func testImagesFilesAndDuplicates() {
        var h = ClipHistory(keep: 2)
        h.addImage(file: "a.png", digest: "d1", width: 800, height: 600)
        let dropped = h.addImage(file: "b.png", digest: "d1", width: 800, height: 600)
        XCTAssertEqual(h.clips.count, 1)
        XCTAssertEqual(h.clips[0].image, "a.png")
        XCTAssertEqual(dropped.first?.image, "b.png")
        XCTAssertEqual(h.clips[0].preview(), "Image 800×600")
        h.setImageText(h.clips[0].id, "Quarterly revenue")
        XCTAssertEqual(h.shown(matching: "revenue").count, 1)
        h.addFiles(["/Users/a/Report.pdf"])
        XCTAssertEqual(h.clips[0].kind, .file)
        XCTAssertEqual(h.clips[0].text, "Report.pdf")
        let gone = h.add("third")
        XCTAssertEqual(gone.first?.image, "a.png")
        XCTAssertEqual(h.kindCounts[.file], 1)
    }

    func testBoardsTagsAndFilters() {
        var h = ClipHistory(keep: 1)
        h.add("https://a.com")
        let id = h.clips[0].id
        h.addToBoard(id, board: "Trip")
        h.setTags(id, ["Travel", " travel ", "Flights"])
        h.add("x"); h.add("y")
        XCTAssertTrue(h.clips.contains { $0.id == id })
        XCTAssertEqual(h.shown(board: "Trip").count, 1)
        XCTAssertEqual(h.shown(kind: .link).count, 1)
        XCTAssertEqual(h.shown(tag: "flights").count, 1)
        XCTAssertEqual(h.shown(matching: "travel").count, 1)
        XCTAssertEqual(h.allTags, ["flights", "travel"])
        h.renameBoard("Trip", to: "Lisbon")
        XCTAssertEqual(h.boards, ["Lisbon"])
        XCTAssertEqual(h.clips.first { $0.id == id }?.boards, ["Lisbon"])
        h.clear()
        XCTAssertEqual(h.clips.count, 1)
        h.deleteBoard("Lisbon")
        XCTAssertTrue(h.boards.isEmpty)
    }

    func testRemindersAndQuickPaste() {
        var h = ClipHistory()
        let now = Date(timeIntervalSince1970: 1000)
        h.add("old", at: now.addingTimeInterval(-500))
        h.add("new", at: now)
        let old = h.clips[1].id
        h.remind(old, at: now.addingTimeInterval(60))
        XCTAssertTrue(h.takeDueReminders(now: now).isEmpty)
        XCTAssertEqual(h.takeDueReminders(now: now.addingTimeInterval(61)).map(\.text), ["old"])
        XCTAssertEqual(h.clips[0].text, "old")
        XCTAssertNil(h.clips[0].remindAt)
        XCTAssertEqual(h.quick.map(\.text), ["old", "new"])
    }

    func testOldHistoriesStillOpen() throws {
        let json = #"{"keep":50,"clips":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","text":"https://x.com","copied":0,"pinned":true}]}"#
        let h = try JSONDecoder().decode(ClipHistory.self, from: Data(json.utf8))
        XCTAssertEqual(h.clips[0].kind, .link)
        XCTAssertTrue(h.clips[0].boards.isEmpty)
        let again = try JSONDecoder().decode(ClipHistory.self, from: JSONEncoder().encode(h))
        XCTAssertEqual(again, h)
    }

    func testMoodboard() {
        let r = Moodboard.layout(sizes: [(1600, 900), (900, 900), (600, 900), (1200, 800)], width: 1200, rowHeight: 320, gap: 10)
        XCTAssertEqual(r.frames.count, 4)
        for f in r.frames { XCTAssertLessThanOrEqual(f.x + f.width, 1200.5) }
        // The first row fills the width.
        let firstRow = r.frames.filter { $0.y == r.frames[0].y }
        XCTAssertEqual((firstRow.last!.x + firstRow.last!.width), 1190, accuracy: 0.5)
        XCTAssertGreaterThan(r.height, 200)
    }
}
