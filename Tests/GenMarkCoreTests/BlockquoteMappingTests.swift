import XCTest
@testable import GenMarkCore

final class BlockquoteMappingTests: XCTestCase {
    private let parser = CMarkParser()

    func test_blockquote_parses_children_and_nested_structures() {
        let md = """
        > First paragraph in quote
        >
        > Second paragraph in quote
        >
        > - item 1
        > - item 2
        >
        > > Nested quote line
        """

        let doc = parser.parse(markdown: md)
        guard case .blockQuote(let children) = doc.blocks.first else {
            return XCTFail("Expected top-level blockQuote")
        }

        // Expect at least two paragraphs and a list within the quote
        let paragraphCount = children.filter { if case .paragraph = $0 { return true } else { return false } }.count
        XCTAssertGreaterThanOrEqual(paragraphCount, 2, "Expected multiple paragraphs inside blockquote")

        let hasList = children.contains { if case .list = $0 { return true } else { return false } }
        XCTAssertTrue(hasList, "Expected a list inside blockquote")

        // Expect nested blockquote present
        let hasNestedQuote = children.contains { if case .blockQuote = $0 { return true } else { return false } }
        XCTAssertTrue(hasNestedQuote, "Expected a nested blockquote inside blockquote")
    }
}

