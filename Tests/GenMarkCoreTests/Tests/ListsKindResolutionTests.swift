import XCTest
@testable import GenMarkCore

final class ListsKindResolutionTests: XCTestCase {
    private let parser = CMarkParser()

    func test_mixed_task_and_regular_items_yields_task_kind() {
        let md = """
        - regular item
        - [ ] unchecked task
        - [x] checked task
        """
        let doc = parser.parse(markdown: md)
        guard case .list(let kind, let items) = doc.blocks.first else { return XCTFail("Expected list block") }

        // List kind should resolve to .task as soon as any task item appears
        XCTAssertEqual(kind, .task)
        XCTAssertEqual(items.count, 3)

        // Checked states: regular item -> nil, unchecked -> false, checked -> true
        XCTAssertNil(items[0].checked)
        XCTAssertEqual(items[1].checked, false)
        XCTAssertEqual(items[2].checked, true)
    }
}

