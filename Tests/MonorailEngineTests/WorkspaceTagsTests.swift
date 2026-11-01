import MonorailCore
@testable import MonorailEngine
import XCTest

final class WorkspaceTagsTests: XCTestCase {
    func testTaggingKeepsTheCurrentWorkspaceToo() {
        var tags = WorkspaceTags()
        let result = tags.toggle(7, workspace: 3, current: 1)
        XCTAssertTrue(result.added)
        XCTAssertEqual(result.tags, [1, 3])
        XCTAssertEqual(tags.tags(of: 7), [1, 3])
    }

    func testOneWorkspaceLeftMeansNotTagged() {
        var tags = WorkspaceTags()
        tags.toggle(7, workspace: 3, current: 1)
        let result = tags.toggle(7, workspace: 3, current: 1)
        XCTAssertFalse(result.added)
        XCTAssertEqual(result.tags, [])
        XCTAssertNil(tags.byWindow[7])
    }

    func testFollowsOnlyBetweenItsWorkspaces() {
        var tags = WorkspaceTags()
        tags.toggle(7, workspace: 3, current: 1)
        tags.toggle(7, workspace: 5, current: 1)
        XCTAssertTrue(tags.follows(7, from: 1, to: 5))
        XCTAssertTrue(tags.follows(7, from: 3, to: 1))
        XCTAssertFalse(tags.follows(7, from: 1, to: 2))
        XCTAssertFalse(tags.follows(7, from: 1, to: 1))
        XCTAssertFalse(tags.follows(8, from: 1, to: 3))
        XCTAssertEqual(tags.windows(taggedWith: 5), [7])
    }

    func testLoadingDropsSingleTagsAndSavingDropsClosedWindows() {
        let tags = WorkspaceTags([1: [2], 2: [2, 4], 3: [1, 4]])
        XCTAssertEqual(tags.byWindow.keys.sorted(), [2, 3])
        XCTAssertEqual(tags.keeping { $0 == 3 }, [3: [1, 4]])
    }
}
