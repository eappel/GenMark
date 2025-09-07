import XCTest
@testable import GenMarkCore

final class HTMLBlocksFilteringTests: XCTestCase {
    func test_html_blocks_are_dropped_in_safe_and_unsafe_modes() {
        let md = """
        Before paragraph

        <div>HTML content</div>

        <script>alert('x')</script>

        After paragraph
        """

        let safe = CMarkParser(options: [.default])
        let unsafe = CMarkParser(options: [.default, .unsafe])

        let safeDoc = safe.parse(markdown: md)
        let unsafeDoc = unsafe.parse(markdown: md)

        // Expect paragraphs for before/after and no nodes representing HTML blocks
        func assertNoHTMLBlocks(_ doc: MarkdownDocument) {
            // Ensure we have at least the two visible paragraphs
            let paragraphCount = doc.blocks.filter { if case .paragraph = $0 { return true } else { return false } }.count
            XCTAssertGreaterThanOrEqual(paragraphCount, 2)

            // Ensure literal HTML block strings do not appear as text paragraphs unexpectedly
            let containsHTMLLiteral = doc.blocks.contains { block in
                if case .paragraph(let inlines) = block {
                    return inlines.contains { inline in
                        if case .text(let s) = inline { return s.contains("HTML content") || s.contains("<script>") }
                        return false
                    }
                }
                return false
            }
            XCTAssertFalse(containsHTMLLiteral)
        }

        assertNoHTMLBlocks(safeDoc)
        assertNoHTMLBlocks(unsafeDoc)
    }
}

