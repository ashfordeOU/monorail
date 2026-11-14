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

    func testClosedLidHandoffFollowsKeepersCapsAndAck() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var body: [String: Any] = ["app": "Keeper", "bundleID": "io.github.ashfordeou.keeper", "pid": 42, "owns": ["awake": true]]
        // An older Keeper: no caps. Plain sessions go to it, lid-closed ones stay here.
        let old = try XCTUnwrap(PeerHello.decode(body))
        XCTAssertFalse(old.takesClosedLid)
        XCTAssertEqual(old.awakeHandoffLink(for: .indefinitely, closedLid: false, handoffID: "a", now: now), "keeper://awake?from=monorail")
        XCTAssertEqual(old.awakeHandoffLink(for: .until(now.addingTimeInterval(600)), closedLid: false, handoffID: "a", now: now), "keeper://awake?for=10m&from=monorail")
        XCTAssertNil(old.awakeHandoffLink(for: .whileApp("us.zoom.xos"), closedLid: false, handoffID: "a", now: now))
        XCTAssertNil(old.awakeHandoffLink(for: .indefinitely, closedLid: true, handoffID: "a", now: now))
        // Keeper that can, but isn't set up yet: still stays here.
        body["caps"] = ["closedLid": true, "closedLidReady": false]
        XCTAssertNil(PeerHello.decode(body)?.awakeHandoffLink(for: .indefinitely, closedLid: true, handoffID: "a", now: now))
        // Set up: the link carries closedLid, the id and who sent it.
        body["caps"] = ["closedLid": true, "closedLidReady": true]
        let ready = try XCTUnwrap(PeerHello.decode(body))
        XCTAssertEqual(ready.awakeHandoffLink(for: .indefinitely, closedLid: true, handoffID: "h1", now: now),
                       "keeper://awake?closedLid=1&handoff=h1&from=monorail")
        XCTAssertEqual(ready.awakeHandoffLink(for: .until(now.addingTimeInterval(1800)), closedLid: true, handoffID: "h2", now: now),
                       "keeper://awake?for=30m&closedLid=1&handoff=h2&from=monorail")
        // A Keeper that keeps the Mac awake while an app is open, or until transfers finish.
        body["caps"] = ["closedLid": true, "closedLidReady": true, "whileApp": true, "whileDownloading": true]
        let newer = try XCTUnwrap(PeerHello.decode(body))
        XCTAssertEqual(newer.awakeHandoffLink(for: .whileApp("us.zoom.xos"), closedLid: false, handoffID: "a", now: now),
                       "keeper://awake?app=us.zoom.xos&from=monorail")
        XCTAssertEqual(newer.awakeHandoffLink(for: .whileDownloading, closedLid: false, handoffID: "a", now: now),
                       "keeper://awake?while=downloading&from=monorail")
        // The ack, in a later hello.
        body["state"] = ["awake": true, "awakeHandoff": ["id": "h2", "ok": false, "closedLid": true, "reason": "denied", "at": 1]]
        XCTAssertEqual(PeerHello.decode(body)?.awakeHandoff,
                       PeerHello.AwakeHandoff(id: "h2", ok: false, closedLid: true, reason: "denied"))
    }

    func testTheAshfordeMenuShowsKeeper() {
        XCTAssertEqual(Companions.keeperMenu(.running(awake: true)).map(\.title), ["Keeper: keeping your Mac awake", "Open Keeper"])
        XCTAssertEqual(Companions.keeperMenu(.running(awake: false)).last?.link, "keeper://home")
        XCTAssertEqual(Companions.keeperMenu(.installed).map(\.title), ["Open Keeper"])
        XCTAssertTrue(Companions.keeperMenu(.notInstalled, downloadable: false).isEmpty, "nothing to offer before Keeper 1.0")
        XCTAssertEqual(Companions.keeperMenu(.notInstalled, downloadable: true).first?.link, "https://github.com/ashfordeOU/keeper/releases")
        let hello = PeerHello.decode(["app": "Keeper", "bundleID": "io.github.ashfordeou.keeper", "pid": 7, "state": ["awake": true]])
        XCTAssertEqual(hello?.isAwake, true)
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

final class InstallerWindowTests: XCTestCase {
    func testDiskImageWindowsFloat() {
        let volumes: Set<String> = ["Keeper by Ashforde®", "Monorail"]
        XCTAssertTrue(InstallerWindows.isDiskImageWindow(bundleID: "com.apple.finder", title: "Keeper by Ashforde®", readOnlyVolumes: volumes))
        XCTAssertFalse(InstallerWindows.isDiskImageWindow(bundleID: "com.apple.finder", title: "Downloads", readOnlyVolumes: volumes))
        XCTAssertFalse(InstallerWindows.isDiskImageWindow(bundleID: "com.apple.Safari", title: "Monorail", readOnlyVolumes: volumes))
        XCTAssertFalse(InstallerWindows.isDiskImageWindow(bundleID: "com.apple.finder", title: nil, readOnlyVolumes: volumes))
    }
}
