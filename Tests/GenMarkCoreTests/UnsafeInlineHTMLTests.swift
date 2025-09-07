import XCTest
@testable import GenMarkCore

final class UnsafeInlineHTMLTests: XCTestCase {
    func test_inline_html_non_br_is_text_in_safe_and_unsafe() {
        let md = "Hello <span>there</span> friend"
        let safe = CMarkParser(options: [.default])
        let unsafe = CMarkParser(options: [.default, .unsafe])

        let safeDoc = safe.parse(markdown: md)
        let unsafeDoc = unsafe.parse(markdown: md)

        func assertInlineHTMLAsText(_ doc: MarkdownDocument) {
            guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
            // No line breaks should be introduced for <span>
            XCTAssertFalse(inlines.contains { if case .lineBreak = $0 { return true } else { return false } })
            // Content should remain present; allow either literal HTML text or just the word 'there'
            let concatenated = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
            XCTAssertTrue(concatenated.contains("there"), "Expected inline HTML content to be preserved as text")
        }

        assertInlineHTMLAsText(safeDoc)
        assertInlineHTMLAsText(unsafeDoc)
    }
}
