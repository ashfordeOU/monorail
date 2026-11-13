import XCTest
@testable import MonorailCore

final class SystemStatsTests: XCTestCase {
    func testLoadPerCore() {
        let a = [SystemStats.Ticks(user: 100, system: 50, idle: 850, nice: 0), SystemStats.Ticks(user: 0, system: 0, idle: 1000, nice: 0)]
        let b = [SystemStats.Ticks(user: 160, system: 70, idle: 870, nice: 0), SystemStats.Ticks(user: 10, system: 0, idle: 1090, nice: 0)]
        let load = SystemStats.load(previous: a, now: b)
        XCTAssertEqual(load[0], 80, accuracy: 0.01)
        XCTAssertEqual(load[1], 10, accuracy: 0.01)
        XCTAssertEqual(SystemStats.average(load), 45, accuracy: 0.01)
    }

    func testIdleCoreWithNoTicksIsZero() {
        let t = SystemStats.Ticks(user: 5, system: 5, idle: 5, nice: 0)
        XCTAssertEqual(SystemStats.load(previous: [t], now: [t]), [0])
    }

    func testSplitPutsEfficiencyCoresFirst() {
        let (p, e) = SystemStats.split([1, 2, 3, 4, 5, 6], performance: 4)
        XCTAssertEqual(e, [1, 2])
        XCTAssertEqual(p, [3, 4, 5, 6])
    }

    func testMemoryFromPages() {
        let m = SystemStats.Memory.fromPages(pageSize: 16384, total: 36 * 1_073_741_824, internalPages: 1_000_000, purgeable: 50_000,
                                             wired: 260_000, compressed: 200_000, external: 150_000)
        XCTAssertEqual(m.app, 950_000 * 16384)
        XCTAssertEqual(m.cached, 200_000 * 16384)
        XCTAssertEqual(m.level, .low)
        XCTAssertEqual(SystemStats.gigabytes(m.wired), "4.0 GB")
    }

    func testRatesAndText() {
        XCTAssertEqual(SystemStats.rate(from: 1000, to: 49_001_000, seconds: 1), 49_000_000)
        XCTAssertEqual(SystemStats.rate(from: 5000, to: 10, seconds: 1), 0)
        XCTAssertEqual(SystemStats.speed(312_000), "312 KB/s")
        XCTAssertEqual(SystemStats.speed(48_000_000), "48.0 MB/s")
        XCTAssertEqual(SystemStats.megabits(bytes: 25_000_000, seconds: 2), 100, accuracy: 0.01)
    }

    func testUptime() {
        XCTAssertEqual(SystemStats.uptime(3 * 86_400 + 4 * 3600 + 120), "3 days, 4 hr")
        XCTAssertEqual(SystemStats.uptime(5400), "1 hr 30 min")
        XCTAssertFalse(SystemStats.suggestsRestart(uptime: 86_400))
        XCTAssertTrue(SystemStats.suggestsRestart(uptime: 20 * 86_400))
    }
}
