import XCTest
@testable import GenMarkCore

final class HTMLInlineBreakVariantsTests: XCTestCase {
    private let parser = CMarkParser()

    func test_br_variants_map_to_linebreak() {
        let cases = [
            ("Hello<br>World", "<br>"),
            ("Hello<BR/>World", "<BR/>"),
            ("Hello<Br />World", "<Br />")
        ]
        for (md, tag) in cases {
            let doc = parser.parse(markdown: md)
            guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph for \(tag)") }
            let hasLineBreak = inlines.contains { if case .lineBreak = $0 { return true } else { return false } }
            XCTAssertTrue(hasLineBreak, "Expected .lineBreak inline for tag \(tag)")
        }
    }
}

