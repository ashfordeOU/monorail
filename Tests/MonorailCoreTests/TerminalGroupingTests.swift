import XCTest
@testable import MonorailCore

final class TerminalGroupingTests: XCTestCase {
    func testTerminalAppsShareOneGroup() {
        var settings = AppSettings()
        XCTAssertEqual(settings.groupKey(for: "com.apple.Terminal", appName: "Terminal"), AppSettings.terminalsGroup)
        XCTAssertEqual(settings.groupKey(for: "com.googlecode.iterm2", appName: "iTerm2"), AppSettings.terminalsGroup)
        XCTAssertEqual(settings.groupKey(for: "com.apple.Safari", appName: "Safari"), "com.apple.Safari")
        XCTAssertEqual(settings.tiles(forGroup: AppSettings.terminalsGroup), 4, "the terminal rules' four per slide")
        settings.groupTerminals = false
        XCTAssertEqual(settings.groupKey(for: "com.apple.Terminal", appName: "Terminal"), "com.apple.Terminal")
    }

    func testTerminalAndITermWindowsLandOnOneSlide() {
        let settings = AppSettings()
        let apps: [Int: String] = [1: "com.apple.Terminal", 2: "com.apple.Safari", 3: "com.googlecode.iterm2"]
        let groups = Grouping.plan(
            [1, 2, 3].map { WindowID($0) },
            app: { settings.groupKey(for: apps[Int($0)], appName: "") },
            capacity: { settings.tiles(forGroup: $0) },
            pairSize: settings.tilesPerSlide
        )
        XCTAssertTrue(groups.contains { Set($0) == Set([WindowID(1), WindowID(3)]) }, "\(groups)")
    }

    func testOlderSettingsKeepTerminalsTogether() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(decoded.groupTerminals)
    }
}
