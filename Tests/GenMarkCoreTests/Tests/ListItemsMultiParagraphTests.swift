import XCTest
@testable import GenMarkCore

final class ListItemsMultiParagraphTests: XCTestCase {
    private let parser = CMarkParser()

    func test_list_item_contains_multiple_paragraph_children() {
        let md = """
        - First paragraph in list

          Second paragraph in same list item

        - Another list item
        """

        let doc = parser.parse(markdown: md)
        guard case .list(_, let items) = doc.blocks.first else {
            return XCTFail("Expected list block")
        }
        XCTAssertEqual(items.count, 2, "Should parse two list items")

        guard let first = items.first else { return XCTFail("Missing first item") }
        // Expect multiple block children inside the first item (two paragraphs)
        XCTAssertGreaterThanOrEqual(first.children.count, 2, "First list item should contain multiple block children (paragraphs)")

        // Optionally, verify both are paragraphs when present
        if first.children.count >= 2 {
            if case .paragraph = first.children[0] { /* ok */ } else { XCTFail("Expected paragraph as first child") }
            if case .paragraph = first.children[1] { /* ok */ } else { XCTFail("Expected paragraph as second child") }
        }
    }
}

