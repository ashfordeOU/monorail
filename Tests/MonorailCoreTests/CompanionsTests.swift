@testable import MonorailCore
import XCTest

final class CompanionsTests: XCTestCase {
    func testKeeperAndItsHelpersAreRecognised() {
        XCTAssertTrue(Companions.isKeeper("io.github.ashfordeou.keeper"))
        XCTAssertTrue(Companions.isKeeper("io.github.ashfordeou.keeper.helper"))
        XCTAssertFalse(Companions.isKeeper("io.github.ashfordeou.keeperx"))
        XCTAssertFalse(Companions.isKeeper(nil))
    }

    func testKeeperIslandWidgetsAndQuickWindowsAreLeftAlone() {
        // The Island floats at the status level by the notch.
        XCTAssertTrue(Companions.leavesAlone(bundleID: Companions.keeper, hasTitleBar: false, layer: 25))
        // Desktop widgets sit on the normal layer, without a title bar.
        XCTAssertTrue(Companions.leavesAlone(bundleID: Companions.keeper, hasTitleBar: false, layer: 0))
        // Quick Search and Quick Terminal float just above windows.
        XCTAssertTrue(Companions.leavesAlone(bundleID: Companions.keeper, hasTitleBar: false, layer: 3))
    }

    func testKeeperMainWindowIsManaged() {
        XCTAssertFalse(Companions.leavesAlone(bundleID: Companions.keeper, hasTitleBar: true, layer: 0))
    }

    func testOtherAppsOnlyAboveModalPanels() {
        XCTAssertTrue(Companions.leavesAlone(bundleID: "com.example.notch", hasTitleBar: false, layer: 25))
        // A file picker (modal panel layer, no title bar) is still kept on screen.
        XCTAssertFalse(Companions.leavesAlone(bundleID: "com.google.Chrome", hasTitleBar: false, layer: 8))
        XCTAssertFalse(Companions.leavesAlone(bundleID: "com.apple.Terminal", hasTitleBar: true, layer: 0))
    }
}
