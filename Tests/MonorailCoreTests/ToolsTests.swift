@testable import MonorailCore
import XCTest

final class ToolsTests: XCTestCase {
    func testJSONAndBase64() {
        XCTAssertEqual(DevTools.minifyJSON("{ \"b\": 1, \"a\": [1, 2] }"), "{\"a\":[1,2],\"b\":1}")
        XCTAssertNotNil(DevTools.prettyJSON("{\"a\":1}"))
        XCTAssertNil(DevTools.prettyJSON("{nope"))
        XCTAssertEqual(DevTools.base64Encode("hello"), "aGVsbG8=")
        XCTAssertEqual(DevTools.base64Decode("aGVsbG8"), "hello")
    }

    func testTimestampsJWTAndLinks() {
        XCTAssertEqual(DevTools.timestamp("0"), "1970-01-01T00:00:00Z")
        XCTAssertEqual(DevTools.timestamp("1700000000000"), "2023-11-14T22:13:20Z")
        XCTAssertEqual(DevTools.timestamp("1970-01-01T00:01:40Z"), "100")
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.sig"
        XCTAssertTrue(DevTools.decodeJWT(jwt)?.payload.contains("123") ?? false)
        XCTAssertEqual(DevTools.cleanLink("https://a.com/x?utm_source=t&id=4&fbclid=z"), "https://a.com/x?id=4")
        XCTAssertEqual(DevTools.cleanLink("https://a.com/x?utm_source=t"), "https://a.com/x")
    }

    func testPasswordAndCase() {
        let p = DevTools.password(length: 24)
        XCTAssertEqual(p.count, 24)
        XCTAssertTrue(p.contains { $0.isNumber })
        XCTAssertFalse(p.contains("0") || p.contains("O") || p.contains("l"))
        XCTAssertEqual(DevTools.convert("Hello big World", to: .snake), "hello_big_world")
        XCTAssertEqual(DevTools.convert("hello big world", to: .camel), "helloBigWorld")
        XCTAssertEqual(DevTools.convert("hello WORLD", to: .sentence), "Hello world")
    }

    func testBatchRename() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let d = Date(timeIntervalSince1970: 0)
        let files = (1...12).map { (name: "IMG_\($0)", ext: "jpg", date: d) }
        let names = BatchRename.names(files, pattern: "Trip {n} {date}", calendar: c)
        XCTAssertEqual(names.first, "Trip 01 1970-01-01.jpg")
        XCTAssertEqual(names.last, "Trip 12 1970-01-01.jpg")
        XCTAssertEqual(BatchRename.names([(name: "a b", ext: "", date: d)], pattern: "", find: " ", replace: "_", calendar: c), ["a_b"])
        XCTAssertEqual(BatchRename.unique(["x.png", "X.png", "y"]), ["x.png", "X 2.png", "y"])
    }

    func testScreenshotNames() {
        XCTAssertEqual(ScreenshotName.suggest(from: ["9:41", "File Edit View", "Quarterly revenue by region", "Q1 Q2"]), "Quarterly revenue by region")
        XCTAssertNil(ScreenshotName.suggest(from: ["12:30", "OK"]))
        XCTAssertEqual(ScreenshotName.suggest(from: ["Welcome to the Monorail Dashboard: battery, storage and more today"]), "Welcome to the Monorail Dashboard")
    }

    #if canImport(CryptoKit)
    func testHashes() {
        XCTAssertEqual(DevTools.hashes("abc").first { $0.name == "SHA-256" }?.hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    #endif
}
