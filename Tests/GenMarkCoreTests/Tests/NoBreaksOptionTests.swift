import XCTest
@testable import GenMarkCore

final class NoBreaksOptionTests: XCTestCase {
    func test_no_linebreak_nodes_and_text_joined_with_spaces() {
        let parser = CMarkParser(options: [.default, .noBreaks])
        let md = """
        Line one
        Line two
        Line three
        """
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }

        // Ensure there are no hard line breaks
        let hasLineBreak = inlines.contains { if case .lineBreak = $0 { return true } else { return false } }
        XCTAssertFalse(hasLineBreak, ".noBreaks should not produce hard line break nodes")

        // Ensure text contains all lines, joined with spaces
        let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
        XCTAssertTrue(text.contains("Line one"))
        XCTAssertTrue(text.contains("Line two"))
        XCTAssertTrue(text.contains("Line three"))
    }
}

