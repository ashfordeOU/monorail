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

    /// A command as plain data, in the golden files' shape (workspaces counted from 1, as people say them).
    func describe(_ command: NaturalCommand?) -> Any {
        guard let command else { return NSNull() }
        func opt(_ value: Any?) -> Any { value ?? NSNull() }
        switch command {
        case .pair(let apps, let arrangement, let workspace):
            return ["pair": ["apps": apps, "arrangement": arrangement.rawValue, "workspace": opt(workspace.map { $0 + 1 })]]
        case .width(let app, let share): return ["width": ["app": opt(app), "share": share]]
        case .moveTo(let app, let workspace): return ["moveTo": ["app": opt(app), "workspace": workspace + 1]]
        case .switchTo(let workspace): return ["switchTo": ["workspace": workspace + 1]]
        case .open(let app): return ["open": ["app": app]]
        case .focusMode(let on): return ["focusMode": on]
        case .action(let action): return ["action": action.rawValue]
        }
    }

    func testSentences() throws {
        let data = try Data(contentsOf: Self.folder.appendingPathComponent("sentences.json"))
        let file = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let apps = file["apps"] as? [String] ?? []
        let cases = try XCTUnwrap(file["cases"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let text = item["text"] as? String ?? ""
            let got = describe(CommandParser.parse(text, apps: apps))
            let want = item["expect"] ?? NSNull()
            // Compare as JSON, so numbers and nulls match the same way in every language.
            let encode = { (value: Any) -> String in
                guard JSONSerialization.isValidJSONObject(["v": value]),
                    let data = try? JSONSerialization.data(withJSONObject: ["v": value], options: [.sortedKeys])
                else { return "\(value)" }
                return String(decoding: data, as: UTF8.self)
            }
            XCTAssertEqual(encode(got), encode(want), text)
        }
    }

    func testAeroSpaceImport() throws {
        let toml = try String(contentsOf: Self.folder.appendingPathComponent("import-aerospace.toml"), encoding: .utf8)
        let data = try Data(contentsOf: Self.folder.appendingPathComponent("import-aerospace.expect.json"))
        let want = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let plan = ConfigImport.aeroSpace(toml)
        XCTAssertEqual(plan.gap, (want["gap"] as? NSNumber)?.doubleValue)
        XCTAssertEqual(plan.floatApps, want["floatApps"] as? [String])
        let rules = (want["workspaceApps"] as? [[Any]] ?? []).map { "\($0[0])=\($0[1])" }
        XCTAssertEqual(plan.workspaceApps.map { "\($0.app)=\($0.workspace)" }, rules)
        func names(_ mods: Modifiers) -> [String] {
            [(Modifiers.control, "control"), (.option, "option"), (.shift, "shift"), (.command, "command")]
                .filter { mods.contains($0.0) }.map(\.1)
        }
        let bindings = (want["bindings"] as? [[Any]] ?? []).map { "\($0[0])|\($0[1])|\(($0[2] as? [String] ?? []).joined(separator: "+"))" }
        XCTAssertEqual(plan.bindings.map { "\($0.action.rawValue)|\($0.shortcut.keyCode)|\(names($0.shortcut.modifiers).joined(separator: "+"))" }, bindings)
        XCTAssertEqual(plan.skipped.count, (want["skipped"] as? NSNumber)?.intValue)
    }
}
