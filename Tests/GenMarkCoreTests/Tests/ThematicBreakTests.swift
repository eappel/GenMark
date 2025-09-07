import XCTest
@testable import GenMarkCore

final class ThematicBreakTests: XCTestCase {
    private let parser = CMarkParser()

    func test_thematic_break_between_paragraphs() {
        let md = """
        Before paragraph

        ---

        After paragraph
        """

        let doc = parser.parse(markdown: md)
        XCTAssertGreaterThanOrEqual(doc.blocks.count, 3, "Expected paragraph, hr, paragraph")

        // Find a thematicBreak node between paragraphs
        var foundBreak = false
        for (idx, block) in doc.blocks.enumerated() {
            if case .thematicBreak = block {
                // Basic neighbor sanity where possible
                if idx > 0, idx + 1 < doc.blocks.count {
                    if case .paragraph = doc.blocks[idx - 1], case .paragraph = doc.blocks[idx + 1] {
                        foundBreak = true
                        break
                    }
                } else {
                    foundBreak = true
                    break
                }
            }
        }
        XCTAssertTrue(foundBreak, "Expected a thematic break in the document")
    }
}

