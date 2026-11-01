import MonorailCore
@testable import MonorailEngine
import XCTest

final class FocusHistoryTests: XCTestCase {
    func testRecordsInOrderWithoutRepeats() {
        var history = FocusHistory()
        XCTAssertTrue(history.record(1))
        XCTAssertTrue(history.record(2))
        XCTAssertFalse(history.record(2))
        XCTAssertTrue(history.record(1))
        XCTAssertEqual(history.ids, [2, 1])
        XCTAssertEqual(history.last, 1)
        XCTAssertEqual(history.previous, 2)
        XCTAssertEqual(history.recentFirst, [1, 2])
    }

    func testKeepsOnlyTheLimit() {
        var history = FocusHistory(limit: 3)
        for id in 1...5 { history.record(WindowID(id)) }
        XCTAssertEqual(history.ids, [3, 4, 5])
        XCTAssertEqual(FocusHistory().limit, 30)
    }

    func testBackSkipsTheCurrentAndClosedWindows() {
        var history = FocusHistory()
        for id: WindowID in [10, 20, 30, 40] { history.record(id) }
        let open: Set<WindowID> = [10, 40]
        XCTAssertEqual(history.back(from: 40, isAlive: open.contains), 10)
        XCTAssertNil(history.back(from: 10, isAlive: { $0 == 10 }))
    }

    func testMostRecentAndRemove() {
        var history = FocusHistory()
        for id: WindowID in [1, 2, 3, 4] { history.record(id) }
        XCTAssertEqual(history.mostRecent { $0 % 2 == 1 }, 3)
        history.remove(3)
        XCTAssertEqual(history.mostRecent { $0 % 2 == 1 }, 1)
        XCTAssertEqual(history.ids, [1, 2, 4])
    }
}
