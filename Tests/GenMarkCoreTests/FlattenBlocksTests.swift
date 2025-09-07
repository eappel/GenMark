import XCTest
@testable import GenMarkCore

final class FlattenBlocksTests: XCTestCase {
    private let parser = CMarkParser()

    func test_no_document_blocks_in_output_tree() {
        // Complex input with nested lists and quotes to exercise tree shaping
        let md = """
        # Title

        > Quote
        > - Item 1
        > - Item 2

        1. First
        2. Second
        
        Paragraph with `code` and ~~strike~~ and [link](https://example.com).
        """
        let doc = parser.parse(markdown: md)
        XCTAssertFalse(containsDocumentNode(in: doc.blocks), "Parser output should not contain nested .document nodes")
    }

    private func containsDocumentNode(in blocks: [BlockNode]) -> Bool {
        for block in blocks {
            switch block {
            case .document(let children):
                // Presence of a .document node indicates flattening failed
                if !children.isEmpty { return true }
            case .blockQuote(let children):
                if containsDocumentNode(in: children) { return true }
            case .list(_, let items):
                for item in items { if containsDocumentNode(in: item.children) { return true } }
            default:
                break
            }
        }
        return false
    }
}

