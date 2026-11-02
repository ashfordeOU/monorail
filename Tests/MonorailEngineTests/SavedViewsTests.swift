import Foundation
import MonorailCore
@testable import MonorailEngine
import XCTest

final class SavedViewsTests: XCTestCase {
    func testSavesNinePerDisplay() {
        var views = SavedViews()
        let a = SavedView(workspace: 2, scroll: 1.5, window: 42)
        XCTAssertTrue(views.save(a, as: 3, on: "Built-in"))
        XCTAssertFalse(views.save(a, as: 0, on: "Built-in"))
        XCTAssertFalse(views.save(a, as: 10, on: "Built-in"))
        XCTAssertEqual(views.view(3, on: "Built-in"), a)
        XCTAssertNil(views.view(3, on: "Studio Display"))
        views.save(SavedView(workspace: 1, scroll: 0, window: nil), as: 1, on: "Built-in")
        XCTAssertEqual(views.list(on: "Built-in").map(\.number), [1, 3])
    }

    func testKeepsTheSavedFormat() throws {
        // Views saved by earlier versions must still load.
        let json = #"{"Built-in":{"3":{"workspace":2,"scroll":1.5,"window":42}}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: [Int: SavedView]].self, from: json)
        XCTAssertEqual(SavedViews(decoded).view(3, on: "Built-in"), SavedView(workspace: 2, scroll: 1.5, window: 42))
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SavedView(workspace: 2, scroll: 1.5, window: nil))) as? [String: Any]
        XCTAssertEqual(Set(object?.keys.map { $0 } ?? []), ["workspace", "scroll"])
    }

    func testLoadingDropsOutOfRangeSlots() {
        let views = SavedViews(["A": [0: SavedView(workspace: 1, scroll: 0, window: nil), 4: SavedView(workspace: 1, scroll: 0, window: nil)], "B": [12: SavedView(workspace: 1, scroll: 0, window: nil)]])
        XCTAssertEqual(views.list(on: "A").map(\.number), [4])
        XCTAssertNil(views.byDisplay["B"])
    }
}
