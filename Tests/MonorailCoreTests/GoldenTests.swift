import Foundation
import XCTest
@testable import MonorailCore

/// Runs the shared golden tests in tests/golden: every Monorail implementation must pass them.
final class GoldenTests: XCTestCase {
    static var folder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("tests/golden")
    }

    func load(_ name: String) throws -> [[String: Any]] {
        let data = try Data(contentsOf: Self.folder.appendingPathComponent(name))
        let cases = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty, "\(name) has no cases")
        return cases
    }

    func rect(_ any: Any?) -> Rect? {
        guard let list = any as? [Any], list.count == 4 else { return nil }
        let n = list.compactMap { ($0 as? NSNumber)?.doubleValue }
        return n.count == 4 ? Rect(x: n[0], y: n[1], width: n[2], height: n[3]) : nil
    }

    func testDockZones() throws {
        for item in try load("dock-zones.json") {
            let name = item["name"] as? String ?? "?"
            let frame = try XCTUnwrap(rect(item["frame"]), name)
            let point = try XCTUnwrap(item["point"] as? [NSNumber], name)
            let zone = DockZone.edge(x: point[0].doubleValue, y: point[1].doubleValue, in: frame)
            XCTAssertEqual(zone?.rawValue, item["expect"] as? String, name)
        }
    }

    func testSplitTrees() throws {
        for item in try load("split-tree.json") {
            let name = item["name"] as? String ?? "?"
            var tree = SplitTree.single(WindowID((item["start"] as? NSNumber)?.intValue ?? 1))
            for op in item["ops"] as? [[String: Any]] ?? [] {
                if let dock = op["dock"] as? [Any], dock.count == 3,
                    let w = (dock[0] as? NSNumber)?.intValue, let onto = (dock[1] as? NSNumber)?.intValue,
                    let edge = (dock[2] as? String).flatMap(SplitTree.Edge.init(rawValue:))
                {
                    tree = tree.docking(WindowID(w), onto: WindowID(onto), edge: edge)
                } else if let w = (op["remove"] as? NSNumber)?.intValue {
                    tree = try XCTUnwrap(tree.removing(WindowID(w)), name)
                } else if let w = (op["activate"] as? NSNumber)?.intValue {
                    tree = tree.activating(WindowID(w))
                } else if let resize = op["resize"] as? [Any], resize.count == 2, let w = (resize[0] as? NSNumber)?.intValue,
                    let to = rect(resize[1])
                {
                    tree = tree.resizing(WindowID(w), to: to)
                } else if let adjust = op["adjust"] as? [Any], adjust.count == 3, let w = (adjust[0] as? NSNumber)?.intValue,
                    let axis = (adjust[1] as? String).flatMap(SplitTree.Axis.init(rawValue:)), let delta = (adjust[2] as? NSNumber)?.doubleValue
                {
                    tree = tree.adjusting(WindowID(w), axis: axis, by: delta)
                } else if op["balance"] != nil {
                    tree = tree.balanced
                } else {
                    XCTFail("\(name): unknown operation \(op)")
                }
            }
            let expected = (item["expect"] as? [String: Any])?["tiles"] as? [[String: Any]] ?? []
            let tiles = tree.tiles()
            XCTAssertEqual(tiles.map { Int($0.window) }, expected.compactMap { ($0["window"] as? NSNumber)?.intValue }, name)
            for (tile, want) in zip(tiles, expected) {
                let frame = try XCTUnwrap(rect(want["frame"]), name)
                XCTAssertEqual(tile.frame.x, frame.x, accuracy: 1e-6, name)
                XCTAssertEqual(tile.frame.y, frame.y, accuracy: 1e-6, name)
                XCTAssertEqual(tile.frame.width, frame.width, accuracy: 1e-6, name)
                XCTAssertEqual(tile.frame.height, frame.height, accuracy: 1e-6, name)
                XCTAssertEqual(tile.isHiddenTab, want["hidden"] as? Bool ?? false, "\(name): hidden for \(tile.window)")
            }
        }
    }
}
