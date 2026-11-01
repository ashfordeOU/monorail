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

final class PeerTests: XCTestCase {
    func testOverlayTitles() {
        XCTAssertTrue(Companions.isKeeperOverlay(title: "Keeper Island"))
        XCTAssertTrue(Companions.isKeeperOverlay(title: "Keeper Stage overlay"))
        XCTAssertTrue(Companions.isKeeperOverlay(title: "Keeper Stage something new"))
        XCTAssertTrue(Companions.isKeeperOverlay(title: "Keeper — sharing this screen"))
        XCTAssertTrue(Companions.isKeeperOverlay(title: "Keeper Notes pop", announced: ["Keeper Notes pop"]))
        XCTAssertFalse(Companions.isKeeperOverlay(title: "Keeper"))
        XCTAssertFalse(Companions.isKeeperOverlay(title: "Terminal — Keeper"))
        XCTAssertFalse(Companions.isKeeperOverlay(title: nil))
    }

    func testKeeperWindowsThatNeverTile() {
        let keeper = Companions.keeper
        XCTAssertFalse(Companions.isKeeperUnmanaged(bundleID: keeper, title: "Keeper", isStandard: true, hasTitleBar: true))
        XCTAssertTrue(Companions.isKeeperUnmanaged(bundleID: keeper, title: "Keeper Island", isStandard: true, hasTitleBar: true))
        XCTAssertTrue(Companions.isKeeperUnmanaged(bundleID: keeper, title: "Anything", isStandard: false, hasTitleBar: true))
        XCTAssertTrue(Companions.isKeeperUnmanaged(bundleID: keeper, title: "Quick Search", isStandard: true, hasTitleBar: false))
        XCTAssertFalse(Companions.isKeeperUnmanaged(bundleID: "com.apple.Safari", title: "Keeper Island", isStandard: true, hasTitleBar: true))
        XCTAssertTrue(Companions.leavesAlone(bundleID: keeper, hasTitleBar: true, layer: 0, title: "Keeper Widget"))
    }

    func testDecodesKeepersHello() {
        let body: [String: Any] = [
            "app": "Keeper", "bundleID": "io.github.ashfordeou.keeper", "version": "2.4.0", "pid": 4242,
            "owns": ["awake": true, "focus": false, "stage": true],
            "overlays": ["Keeper Island", "Keeper Glance"],
            "links": ["keeper://awake?for=30m", "keeper://awake/off"],
            "state": ["focus": false, "awake": true, "stage": false],
        ]
        let hello = PeerHello.decode(body)
        XCTAssertEqual(hello?.app, "Keeper")
        XCTAssertEqual(hello?.pid, 4242)
        XCTAssertEqual(hello?.owns, PeerHello.Owns(awake: true, focus: false, stage: true))
        XCTAssertEqual(hello?.overlays, ["Keeper Island", "Keeper Glance"])
        XCTAssertEqual(hello?.links.count, 2)
    }

    func testRejectsHellosFromOtherApps() {
        XCTAssertNil(PeerHello.decode(["app": "Evil", "bundleID": "com.example.evil", "pid": 10]))
        XCTAssertNil(PeerHello.decode(["app": "Keeper", "bundleID": "io.github.ashfordeou.keeper"]))
        XCTAssertNil(PeerHello.decode(["app": "Keeper", "bundleID": "io.github.ashfordeou.keeper", "pid": 0]))
        XCTAssertNotNil(PeerHello.decode(["app": "Keeper", "bundleID": "io.github.ashfordeou.keeper", "pid": 12.0]))
    }

    func testAwakeLinks() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(PeerHello.awakeLink(for: .indefinitely, now: now), "keeper://awake")
        XCTAssertEqual(PeerHello.awakeLink(for: .until(now.addingTimeInterval(30 * 60)), now: now), "keeper://awake?for=30m")
        XCTAssertEqual(PeerHello.awakeLink(for: .until(now.addingTimeInterval(90 * 60 - 20)), now: now), "keeper://awake?for=90m")
        XCTAssertEqual(PeerHello.awakeLink(for: .until(now.addingTimeInterval(5)), now: now), "keeper://awake?for=1m")
        XCTAssertNil(PeerHello.awakeLink(for: .whileApp("com.apple.Music"), now: now))
        XCTAssertNil(PeerHello.awakeLink(for: .whileDownloading, now: now))
    }

    func testFromKeeper() {
        XCTAssertTrue(PeerHello.isFromKeeper(URL(string: "monorail://focus-mode/on?from=keeper")!))
        XCTAssertTrue(PeerHello.isFromKeeper(URL(string: "monorail://presentation-mode/off?x=1&from=Keeper")!))
        XCTAssertFalse(PeerHello.isFromKeeper(URL(string: "monorail://focus-mode/on")!))
        XCTAssertFalse(PeerHello.isFromKeeper(URL(string: "monorail://focus-mode/on?from=raycast")!))
    }
}
