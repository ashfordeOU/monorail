import XCTest
@testable import MonorailCore

final class SplitTreeTests: XCTestCase {
    func testDockingNestsToAnyDepth() {
        var tree = SplitTree.single(1)
        tree = tree.docking(2, onto: 1, edge: .right)
        tree = tree.docking(3, onto: 2, edge: .bottom)
        tree = tree.docking(4, onto: 3, edge: .left)
        XCTAssertEqual(tree.windows.sorted(), [1, 2, 3, 4])
        XCTAssertEqual(tree.depth, 3)
        let frames = Dictionary(uniqueKeysWithValues: tree.tiles().map { ($0.window, $0.frame) })
        XCTAssertEqual(frames[1], Rect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(frames[2], Rect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        XCTAssertEqual(frames[4], Rect(x: 0.5, y: 0.5, width: 0.25, height: 0.5))
        XCTAssertEqual(frames[3], Rect(x: 0.75, y: 0.5, width: 0.25, height: 0.5))
    }

    func testCentreMakesTabGroupAndRemovingCollapses() {
        var tree = SplitTree.single(1).docking(2, onto: 1, edge: .right).docking(3, onto: 2, edge: .center)
        XCTAssertEqual(tree.tabGroups, [[2, 3]])
        let hidden = tree.tiles().filter(\.isHiddenTab).map(\.window)
        XCTAssertEqual(hidden, [2])
        tree = tree.activating(2)
        XCTAssertEqual(tree.tiles().filter(\.isHiddenTab).map(\.window), [3])
        tree = tree.removing(1)!
        XCTAssertEqual(tree, .leaf([2, 3], active: 0))
        XCTAssertNil(SplitTree.single(9).removing(9))
    }

    func testMovingAWindowWithinTheTree() {
        let tree = SplitTree.single(1).docking(2, onto: 1, edge: .right).docking(1, onto: 2, edge: .bottom)
        XCTAssertEqual(tree.frame(of: 2), Rect(x: 0, y: 0, width: 1, height: 0.5))
        XCTAssertEqual(tree.frame(of: 1), Rect(x: 0, y: 0.5, width: 1, height: 0.5))
    }

    func testResizingMovesOnlyBorderingSplits() {
        let tree = SplitTree.single(1).docking(2, onto: 1, edge: .right).docking(3, onto: 2, edge: .bottom)
        // Window 1's right edge dragged to 0.7.
        let resized = tree.resizing(1, to: Rect(x: 0, y: 0, width: 0.7, height: 1))
        XCTAssertEqual(resized.frame(of: 1)!.width, 0.7, accuracy: 0.0001)
        XCTAssertEqual(resized.frame(of: 2)!.height, 0.5, accuracy: 0.0001)
        // Window 3's top edge dragged up to 0.3.
        let taller = tree.resizing(3, to: Rect(x: 0.5, y: 0.3, width: 0.5, height: 0.7))
        XCTAssertEqual(taller.frame(of: 2)!.height, 0.3, accuracy: 0.0001)
        XCTAssertEqual(taller.frame(of: 1)!.width, 0.5, accuracy: 0.0001)
        // Adjusting grows the window and stays in range.
        XCTAssertGreaterThan(tree.adjusting(3, axis: .vertical, by: 0.1).frame(of: 3)!.height, 0.5)
        XCTAssertLessThanOrEqual(tree.adjusting(1, axis: .horizontal, by: 5).frame(of: 1)!.width, 0.9)
    }

    func testReconcileAndCoding() throws {
        let tree = SplitTree.single(1).docking(2, onto: 1, edge: .bottom)
        let next = tree.reconciled(with: [2, 5])!
        XCTAssertEqual(next.windows, [2, 5])
        let data = try JSONEncoder().encode(tree)
        XCTAssertEqual(try JSONDecoder().decode(SplitTree.self, from: data), tree)
    }

    func testDockZones() {
        let frame = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(DockZone.edge(x: 5, y: 50, in: frame), .left)
        XCTAssertEqual(DockZone.edge(x: 95, y: 50, in: frame), .right)
        XCTAssertEqual(DockZone.edge(x: 50, y: 4, in: frame), .top)
        XCTAssertEqual(DockZone.edge(x: 50, y: 50, in: frame), .center)
        // Edge zones are generous: 35% in from the side still docks.
        XCTAssertEqual(DockZone.edge(x: 35, y: 50, in: frame), .left)
        XCTAssertEqual(DockZone.edge(x: 50, y: 64, in: frame), .bottom)
        XCTAssertNil(DockZone.edge(x: 150, y: 50, in: frame))
    }

    func testStripDockKeepsNestingThroughChanges() {
        var strip = Strip()
        strip.appendColumn(Column(windows: [1], width: 0.5))
        strip.appendColumn(Column(windows: [2], width: 0.5))
        strip.appendColumn(Column(windows: [3], width: 0.5))
        XCTAssertTrue(strip.dock(2, onto: 1, edge: .right))
        XCTAssertTrue(strip.dock(3, onto: 2, edge: .bottom))
        XCTAssertEqual(strip.columns.count, 1)
        XCTAssertTrue(strip.columns[0].isNested)
        XCTAssertEqual(Set(strip.columns[0].windows), [1, 2, 3])
        XCTAssertTrue(strip.remove(3))
        XCTAssertEqual(strip.columns[0].tree?.windows, [1, 2])
        XCTAssertEqual(strip.columns[0].unitFrames.count, 2)
        XCTAssertTrue(strip.dock(3, onto: 1, edge: .center))
        XCTAssertEqual(strip.columns[0].hiddenTabs, [1])
        XCTAssertTrue(strip.tearOff(3, width: 0.5))
        XCTAssertEqual(strip.columns.count, 2)
        let data = try! JSONEncoder().encode(strip.columns[0])
        XCTAssertEqual(try JSONDecoder().decode(Column.self, from: data).tree, strip.columns[0].tree)
    }
}

final class ZoneTests: XCTestCase {
    func testZonesFillInOrderAndCloseUp() {
        // Zones: 1 | (2 over 3)
        let zones = SplitTree.single(1).docking(2, onto: 1, edge: .right).docking(3, onto: 2, edge: .bottom)
        let filled = zones.filling([10, 20, 30])!
        XCTAssertEqual(filled.frame(of: 10), Rect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(filled.frame(of: 30), Rect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        let fewer = zones.filling([10, 20])!
        XCTAssertEqual(fewer.frame(of: 20), Rect(x: 0.5, y: 0, width: 0.5, height: 1))
        let more = zones.filling([10, 20, 30, 40])!
        XCTAssertEqual(Set(more.windows), [10, 20, 30, 40])
    }

    func testRowsBecomeZones() {
        let layout = CustomLayout(name: "x", rows: [1, 2])
        let zones = layout.zonesOrDefault
        XCTAssertEqual(zones.windows.count, 3)
        XCTAssertEqual(zones.frame(of: 1), Rect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(zones.frame(of: 3), Rect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        let three = CustomLayout(name: "y", rows: [1, 1, 1]).zonesOrDefault
        XCTAssertEqual(three.frame(of: 2)!.width, 1.0 / 3, accuracy: 0.0001)
    }
}

final class NestedRestoreTests: XCTestCase {
    func testNestedShapeSurvivesNewWindowIDs() {
        var column = Column(windows: [1, 2, 3], width: 0.6)
        column.tree = SplitTree.single(1).docking(2, onto: 1, edge: .right).docking(3, onto: 2, edge: .bottom)
        let prints: [WindowID: WindowFingerprint] = [1: .init(app: "a", title: ""), 2: .init(app: "b", title: ""), 3: .init(app: "c", title: "")]
        let saved = SavedColumn(column, fingerprint: { prints[$0] })
        let data = try! JSONEncoder().encode(saved)
        let decoded = try! JSONDecoder().decode(SavedColumn.self, from: data)
        var used = Set<WindowID>()
        let now: [(id: WindowID, fingerprint: WindowFingerprint)] = [(30, .init(app: "c", title: "")), (10, .init(app: "a", title: "")), (20, .init(app: "b", title: ""))]
        let columns = LayoutMatcher.columns(for: [decoded], windows: now, used: &used)
        XCTAssertEqual(columns.first?.tree?.frame(of: 10), Rect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(columns.first?.tree?.frame(of: 30), Rect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }
}
