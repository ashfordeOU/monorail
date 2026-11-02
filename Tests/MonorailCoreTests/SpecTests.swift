import Foundation
@testable import MonorailCore
import XCTest

/// spec/ is what the other implementations (C#, TypeScript) are built from: it must say exactly
/// what the Swift core does.
final class SpecTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testActionsMatchTheSwiftCore() throws {
        let data = try Data(contentsOf: Self.root.appendingPathComponent("spec/actions.json"))
        let file = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let listed = try XCTUnwrap(file["actions"] as? [[String: Any]])
        XCTAssertEqual(listed.compactMap { $0["name"] as? String }, Action.allCases.map(\.rawValue), "names and order")
        for (entry, action) in zip(listed, Action.allCases) {
            XCTAssertEqual(entry["title"] as? String, action.title, "title of \(action.rawValue)")
        }
    }
}
