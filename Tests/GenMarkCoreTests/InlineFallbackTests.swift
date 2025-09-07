import XCTest
@testable import GenMarkCore

final class InlineFallbackTests: XCTestCase {
    private let parser = CMarkParser()

    func test_invalid_link_url_falls_back_to_child_text() {
        let md = "[click here](ht!tp://bad)"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        // Expect no link node and presence of plain text from children
        let hasLink = inlines.contains { if case .link = $0 { return true } else { return false } }
        XCTAssertFalse(hasLink, "Invalid URL should not create a link inline")

        let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
        XCTAssertTrue(text.contains("click here"), "Child text should be preserved as plain text")
    }

    func test_invalid_image_url_falls_back_to_alt_text() {
        let md = "![alt text](ht!tp://bad)"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }

        // Invalid image URL should render as plain text using alt text
        let asText = inlines.first { if case .text = $0 { return true } else { return false } }
        XCTAssertNotNil(asText, "Expected alt text to be rendered as plain text when URL is invalid")
        if case .text(let s) = asText! {
            XCTAssertTrue(s.contains("alt text"))
        }
    }
}

