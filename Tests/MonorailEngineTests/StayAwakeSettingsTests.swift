import Foundation
import MonorailCore
@testable import MonorailEngine
import XCTest

final class StayAwakeSettingsTests: XCTestCase {
    private func read(_ json: String) -> StayAwakeSettings { StayAwakeSettings(json: Data(json.utf8)) }

    func testMissingOrUnreadableIsOffWithChatAppsKeptAvailable() {
        XCTAssertEqual(read(#"{"layout":{}}"#), StayAwakeSettings(mode: .off, keepChatAvailable: true))
        XCTAssertEqual(read("not json"), StayAwakeSettings())
        XCTAssertEqual(StayAwakeSettings(json: Data()), StayAwakeSettings())
    }

    func testReadsTheModes() {
        XCTAssertEqual(read(#"{"stayAwake":{"on":true}}"#).mode, .untilTurnedOff)
        XCTAssertEqual(read(#"{"stayAwake":{"on":true,"until":1800000000}}"#).mode, .until(Date(timeIntervalSince1970: 1_800_000_000)))
        XCTAssertEqual(read(#"{"stayAwake":{"on":false,"until":1800000000,"keepChatAvailable":false}}"#),
                       StayAwakeSettings(mode: .off, keepChatAvailable: false))
    }

    func testAnHourEndsAfterAnHour() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let hour = StayAwakeSettings(mode: .until(start.addingTimeInterval(3600)))
        XCTAssertTrue(hour.isOn(now: start))
        XCTAssertTrue(hour.isOn(now: start.addingTimeInterval(3599)))
        XCTAssertFalse(hour.isOn(now: start.addingTimeInterval(3600)))
        XCTAssertTrue(StayAwakeSettings(mode: .untilTurnedOff).isOn(now: start))
        XCTAssertEqual(StayAwakeSettings(mode: .untilTurnedOff).session(now: start), .indefinitely)
        XCTAssertFalse(StayAwakeSettings(mode: .off).isOn(now: start))
    }

    func testWritingKeepsEveryOtherSettingAsItWas() throws {
        let original = #"{"layout":{"gap":20,"defaultWidth":0.75,"widthPresets":[0.5,1]},"someMacOnlyKey":true,"fitMinimumWidth":480,"name":"x","none":null}"#
        let settings = StayAwakeSettings(mode: .until(Date(timeIntervalSince1970: 1_800_000_000)), keepChatAvailable: false)
        let written = try XCTUnwrap(settings.written(into: Data(original.utf8)))
        XCTAssertEqual(StayAwakeSettings(json: written), settings)
        let before = try JSONDecoder().decode(JSONValue.self, from: Data(original.utf8))
        guard case .object(var after) = try JSONDecoder().decode(JSONValue.self, from: written) else { return XCTFail("not an object") }
        after[StayAwakeSettings.key] = nil
        XCTAssertEqual(JSONValue.object(after), before)
        XCTAssertTrue(String(decoding: written, as: UTF8.self).contains("true"))
        XCTAssertFalse(String(decoding: written, as: UTF8.self).contains("\"someMacOnlyKey\" : 1"))
    }

    func testWritingANewFileAndNeverOverwritingOneThatIsntAnObject() throws {
        let fresh = try XCTUnwrap(StayAwakeSettings(mode: .untilTurnedOff).written(into: nil))
        XCTAssertEqual(StayAwakeSettings(json: fresh).mode, .untilTurnedOff)
        XCTAssertNil(StayAwakeSettings().written(into: Data("[1,2]".utf8)))
        XCTAssertNil(StayAwakeSettings().written(into: Data("{broken".utf8)))
    }

    func testSavingKeepsTheSharedSettingsReadable() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("monorail-awake-\(UUID().uuidString)")
        let url = folder.appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertTrue(SharedSettings.writeDefaultsIfMissing(to: url))
        XCTAssertTrue(StayAwakeSettings(mode: .untilTurnedOff).save(to: url))
        XCTAssertEqual(StayAwakeSettings.load(from: url).mode, .untilTurnedOff)
        XCTAssertEqual(SharedSettings.load(from: url), SharedSettings())
    }
}
