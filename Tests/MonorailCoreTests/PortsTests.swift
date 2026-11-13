@testable import MonorailCore
import XCTest

final class PortsTests: XCTestCase {
    func testParsesLsofFields() {
        let out = "p501\ncnode\nf23\nn*:3000\nf24\nn[::1]:3000\np88\ncpostgres\nf5\nn127.0.0.1:5432\np90\ncrapportd\nn*:49152\n"
        let ports = ListeningPort.parse(out)
        XCTAssertEqual(ports.map(\.port), [3000, 5432, 49152])
        XCTAssertEqual(ports[0].command, "node")
        XCTAssertEqual(ports[0].kind, "Dev server")
        XCTAssertTrue(ports[0].isExposed)
        XCTAssertEqual(ports[1].kind, "PostgreSQL")
        XCTAssertFalse(ports[1].isExposed)
        XCTAssertEqual(ports[2].kind, "Service")
    }
}
