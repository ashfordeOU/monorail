@testable import MonorailEngine
import XCTest

final class NavigationHistoryTests: XCTestCase {
    func testBackAndForwardLikeABrowser() {
        var history = NavigationHistory<String>()
        history.leave("A")
        history.leave("B")
        // Now at C.
        XCTAssertEqual(history.back(from: "C"), "B")
        XCTAssertEqual(history.back(from: "B"), "A")
        XCTAssertNil(history.back(from: "A"))
        XCTAssertEqual(history.forward(from: "A"), "B")
        XCTAssertEqual(history.forward(from: "B"), "C")
        XCTAssertNil(history.forward(from: "C"))
        XCTAssertEqual(history.past, ["A", "B"])
    }

    func testGoingSomewhereNewClearsForward() {
        var history = NavigationHistory<String>()
        history.leave("A")
        XCTAssertEqual(history.back(from: "B"), "A")
        XCTAssertTrue(history.canGoForward)
        history.leave("A")
        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.past, ["A"])
    }

    func testKeepsOnlyTheLimit() {
        var history = NavigationHistory<Int>(limit: 3)
        for n in 1...5 { history.leave(n) }
        XCTAssertEqual(history.past, [3, 4, 5])
        XCTAssertEqual(NavigationHistory<Int>().limit, 50)
    }
}
