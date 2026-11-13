@testable import MonorailCore
import XCTest

final class StorageTests: XCTestCase {
    func testLevels() {
        XCTAssertEqual(Storage.level(free: 300_000_000_000, total: 1_000_000_000_000), .fine)
        XCTAssertEqual(Storage.level(free: 15_000_000_000, total: 1_000_000_000_000), .low)
        XCTAssertEqual(Storage.level(free: 4_000_000_000, total: 1_000_000_000_000), .critical)
        XCTAssertEqual(Storage.level(free: 30_000_000_000, total: 250_000_000_000), .fine)
        XCTAssertEqual(Storage.level(free: 0, total: 0), .fine)
    }

    func testSizes() {
        XCTAssertEqual(Storage.size(1_500_000_000), "1.5 GB")
        XCTAssertEqual(Storage.size(512_000_000_000), "512 GB")
        XCTAssertEqual(Storage.size(2_000_000_000_000), "2.0 TB")
        XCTAssertEqual(Storage.size(42_000_000), "42 MB")
        XCTAssertEqual(Storage.size(12), "12 bytes")
    }

    func testLargestAndAge() {
        let items = [Storage.Item(path: "a", bytes: 50_000_000), .init(path: "b", bytes: 900_000_000), .init(path: "c", bytes: 300_000_000)]
        XCTAssertEqual(Storage.largest(items).map(\.path), ["b", "c"])
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(Storage.isOld(lastUsed: now.addingTimeInterval(-100 * 86400), modified: nil, days: 90, now: now))
        XCTAssertFalse(Storage.isOld(lastUsed: now.addingTimeInterval(-100 * 86400), modified: now, days: 90, now: now))
        XCTAssertTrue(Storage.isOld(lastUsed: now, modified: now, days: nil, now: now))
        XCTAssertEqual(Set(Storage.cleanups.map(\.id)).count, Storage.cleanups.count)
    }
}
