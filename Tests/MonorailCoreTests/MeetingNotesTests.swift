@testable import MonorailCore
import XCTest

final class MeetingNotesTests: XCTestCase {
    func testTranscriptOrderAndJoining() {
        var t = MeetingTranscript(title: "Design review", started: Date(timeIntervalSince1970: 0))
        t.add(.init(speaker: "Others", at: 10, text: "Morning all."))
        t.add(.init(speaker: "You", at: 4, text: "Hi there."))
        t.add(.init(speaker: "Others", at: 14, text: "Shall we start?"))
        t.add(.init(speaker: "You", at: 30, text: "  "))
        XCTAssertEqual(t.lines.map(\.speaker), ["You", "Others"])
        XCTAssertEqual(t.lines[1].text, "Morning all. Shall we start?")
        XCTAssertEqual(t.wordCount, 7)
        XCTAssertTrue(t.plainText.hasPrefix("You: Hi there."))
    }

    func testActionItems() {
        var t = MeetingTranscript(title: "Plan", started: Date())
        t.add(.init(speaker: "You", at: 0, text: "Great. I'll send the deck to everyone tonight. Lovely weather today."))
        t.add(.init(speaker: "Others", at: 60, text: "Can you book the room for Thursday? We need to fix the login bug by Friday."))
        let items = MeetingNotes.actionItems(t)
        XCTAssertEqual(items, ["I'll send the deck to everyone tonight.", "Others: Can you book the room for Thursday?",
                               "Others: We need to fix the login bug by Friday."])
    }

    func testChunksAndMarkdown() {
        var t = MeetingTranscript(title: "Long one", started: Date(timeIntervalSince1970: 0), duration: 3725)
        for i in 0..<50 { t.add(.init(speaker: i % 2 == 0 ? "You" : "Others", at: Double(i * 30), text: String(repeating: "word ", count: 60))) }
        let pieces = MeetingNotes.chunks(t, maxCharacters: 2000)
        XCTAssertGreaterThan(pieces.count, 1)
        XCTAssertTrue(pieces.allSatisfy { $0.count <= 2000 })
        XCTAssertEqual(pieces.joined().count, t.plainText.count)
        t.summary = "We agreed the plan."
        t.actionItems = ["Send the deck"]
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let md = t.markdown(calendar: c)
        XCTAssertTrue(md.contains("## Summary\n\nWe agreed the plan."))
        XCTAssertTrue(md.contains("- [ ] Send the deck"))
        XCTAssertTrue(md.contains("1:02:05"))
        XCTAssertEqual(MeetingNotes.fileName(t, calendar: c), "1970-01-01 Long one.md")
        XCTAssertEqual(MeetingNotes.clock(65), "1:05")
    }
}
