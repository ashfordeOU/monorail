import MonorailCore
@testable import MonorailEngine
import XCTest

final class ReturnMemoryTests: XCTestCase {
    func testAWindowGoesBackToItsOwnPlaceOnce() {
        var memory = ReturnMemory<String>()
        memory.remember(1, app: "Safari", at: "ws1 slide 3")
        XCTAssertTrue(memory.remembers(1))
        XCTAssertEqual(memory.recall(1, app: "Safari", appIsAt: { _ in true }), "ws1 slide 3")
        XCTAssertFalse(memory.remembers(1))
    }

    func testAReopenedAppUsesItsLastPlaceOnlyWhenItIsNotThereAlready() {
        var memory = ReturnMemory<String>()
        memory.remember(1, app: "Mail", at: "ws2 slide 1")
        // A new window of Mail while another Mail window is still on that strip: opens normally.
        XCTAssertNil(memory.recall(9, app: "Mail", appIsAt: { _ in true }))
        // Mail was closed and comes back: its last place.
        XCTAssertEqual(memory.recall(9, app: "Mail", appIsAt: { _ in false }), "ws2 slide 1")
        // Used up.
        XCTAssertNil(memory.recall(10, app: "Mail", appIsAt: { _ in false }))
    }

    func testForget() {
        var memory = ReturnMemory<Int>()
        memory.remember(1, app: "A", at: 1)
        memory.remember(2, app: "B", at: 2)
        memory.forget(1)
        XCTAssertFalse(memory.remembers(1))
        XCTAssertEqual(memory.recall(1, app: "A", appIsAt: { _ in false }), 1)
        memory.forgetAll()
        XCTAssertNil(memory.recall(2, app: "B", appIsAt: { _ in false }))
    }
}
