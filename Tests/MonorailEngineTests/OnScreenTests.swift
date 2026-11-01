import MonorailCore
@testable import MonorailEngine
import XCTest

final class OnScreenTests: XCTestCase {
    // Two displays side by side: a laptop (menu bar 25) and an external one to its right.
    let laptop = Rect(x: 0, y: 0, width: 1440, height: 900)
    let laptopVisible = Rect(x: 0, y: 25, width: 1440, height: 875)
    let external = Rect(x: 1440, y: 0, width: 2560, height: 1440)
    var visible: [Rect] { [laptopVisible, external] }
    var frames: [Rect] { [laptop, external] }

    func testFullyShownAllowsRoundingSlack() {
        XCTAssertTrue(OnScreen.isFullyShown(Rect(x: 100, y: 25, width: 800, height: 600), on: visible))
        XCTAssertTrue(OnScreen.isFullyShown(Rect(x: -1.5, y: 24, width: 800, height: 600), on: visible))
        XCTAssertFalse(OnScreen.isFullyShown(Rect(x: -10, y: 25, width: 800, height: 600), on: visible))
    }

    func testStraddlingTwoDisplaysIsNotFullyShownButReachable() {
        let across = Rect(x: 1200, y: 100, width: 600, height: 400)
        XCTAssertFalse(OnScreen.isFullyShown(across, on: visible))
        XCTAssertTrue(OnScreen.isReachable(across, visibleAreas: visible, displayFrames: frames))
    }

    func testWindowLeftOnAnUnpluggedDisplayIsUnreachable() {
        // The external display is gone; the window still thinks it's there.
        let stranded = Rect(x: 2000, y: 200, width: 900, height: 700)
        XCTAssertFalse(OnScreen.isReachable(stranded, visibleAreas: [laptopVisible], displayFrames: [laptop]))
    }

    func testTitleBarUnderTheMenuBarIsUnreachable() {
        let tucked = Rect(x: 200, y: 5, width: 800, height: 600)
        XCTAssertFalse(OnScreen.isReachable(tucked, visibleAreas: [laptopVisible], displayFrames: [laptop]))
    }

    func testMostlyOffTheBottomIsUnreachable() {
        let low = Rect(x: 200, y: 700, width: 800, height: 600)
        XCTAssertFalse(OnScreen.isReachable(low, visibleAreas: [laptopVisible], displayFrames: [laptop]))
    }

    func testFittedSizeKeepsMargins() {
        let size = OnScreen.fittedSize(width: 2000, height: 500, in: laptopVisible)
        XCTAssertEqual(size.width, 1408)
        XCTAssertEqual(size.height, 500)
    }

    func testClampedSlidesTheShortestWay() {
        let off = Rect(x: 1300, y: 800, width: 400, height: 300)
        XCTAssertEqual(OnScreen.clamped(off, into: laptopVisible), Rect(x: 1040, y: 600, width: 400, height: 300))
        // Bigger than the area: pinned to its top left rather than flung off the other side.
        let huge = Rect(x: 50, y: 50, width: 2000, height: 1000)
        XCTAssertEqual(OnScreen.clamped(huge, into: laptopVisible).x, 0)
        XCTAssertEqual(OnScreen.clamped(huge, into: laptopVisible).y, 25)
    }

    func testPlacementCentresOnTheDisplayAndStaggers() {
        let frame = Rect(x: 5000, y: 5000, width: 400, height: 300)
        let first = OnScreen.placement(for: frame, visible: laptopVisible, parent: nil, cascade: 0, resizable: true)
        XCTAssertEqual(first, Rect(x: 520, y: 312.5, width: 400, height: 300))
        let second = OnScreen.placement(for: frame, visible: laptopVisible, parent: nil, cascade: 1, resizable: true)
        XCTAssertEqual(second.x - first.x, 26)
        XCTAssertEqual(OnScreen.placement(for: frame, visible: laptopVisible, parent: nil, cascade: 8, resizable: true), first)
    }

    func testPlacementOverTheParentLikeASheet() {
        let parent = Rect(x: 100, y: 100, width: 1000, height: 700)
        let placed = OnScreen.placement(for: Rect(x: -900, y: 0, width: 500, height: 400), visible: laptopVisible,
                                        parent: parent, cascade: 0, resizable: true)
        XCTAssertEqual(placed, Rect(x: 350, y: 160, width: 500, height: 400))
    }

    func testPlacementShrinksOnlyResizableWindows() {
        let big = Rect(x: 0, y: 0, width: 3000, height: 2000)
        let shrunk = OnScreen.placement(for: big, visible: laptopVisible, parent: nil, cascade: 0, resizable: true)
        XCTAssertEqual(shrunk.width, 1400)
        XCTAssertEqual(shrunk.height, 835)
        XCTAssertTrue(OnScreen.isFullyShown(shrunk, on: [laptopVisible]))
        let fixed = OnScreen.placement(for: big, visible: laptopVisible, parent: nil, cascade: 0, resizable: false)
        XCTAssertEqual(fixed.width, 3000)
        XCTAssertEqual(fixed.x, 0)
    }
}
