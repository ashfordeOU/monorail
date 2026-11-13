@testable import MonorailCore
import XCTest

final class SystemHistoryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testKeepsADayOfMinutesThenFifteenMinuteAverages() {
        var h = SystemHistory()
        // 26 hours, one sample a minute, cpu = minute index % 2 * 100 (so averages are 50).
        for minute in 0..<(26 * 60) {
            h.add(.init(at: start.addingTimeInterval(Double(minute) * 60), cpu: Double(minute % 2) * 100, memory: 40))
        }
        XCTAssertLessThanOrEqual(h.recent.count, 24 * 60 + 15)
        XCTAssertEqual(h.older.count, 8, "two hours folded into 15-minute averages")
        XCTAssertEqual(h.older.first?.cpu ?? 0, 50, accuracy: 4)
        let now = start.addingTimeInterval(26 * 3600)
        XCTAssertEqual(h.samples(.hours12, now: now).count, 12 * 60, accuracy: 2)
        XCTAssertGreaterThan(h.samples(.days7, now: now).count, h.samples(.hours24, now: now).count)
    }

    func testDropsAfterThirtyDays() {
        var h = SystemHistory()
        h.add(.init(at: start, cpu: 1, memory: 1))
        h.add(.init(at: start.addingTimeInterval(2 * 86400), cpu: 1, memory: 1))
        XCTAssertEqual(h.older.count, 1)
        h.add(.init(at: start.addingTimeInterval(40 * 86400), cpu: 1, memory: 1))
        XCTAssertTrue(h.older.isEmpty)
    }

    func testSummaryAndRestartAdvice() {
        let s = SystemHistory.summary([2, 4, 9])!
        XCTAssertEqual(s.low, 2); XCTAssertEqual(s.high, 9); XCTAssertEqual(s.average, 5)
        XCTAssertNil(SystemHistory.summary([]))
        XCTAssertNotNil(SystemHistory.restartAdvice(uptime: 37 * 86400, swapGB: 10))
        XCTAssertNil(SystemHistory.restartAdvice(uptime: 3 * 86400, swapGB: 10))
        XCTAssertTrue(SystemHistory.restartAdvice(uptime: 8 * 86400, swapGB: 5)!.contains("swap"))
    }
}
