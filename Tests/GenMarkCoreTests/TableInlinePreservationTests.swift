import XCTest
@testable import GenMarkCore

final class TableInlinePreservationTests: XCTestCase {
    private let parser = CMarkParser()

    func test_inline_styles_preserved_inside_table_cells() {
        let md = """
        | A | B |
        |---|---|
        | **bold** and *italic* | `code` and ~~strike~~ |
        """
        let doc = parser.parse(markdown: md)
        guard case .table(_, let rows) = doc.blocks.first else { return XCTFail("Expected table") }
        guard let firstRow = rows.first, firstRow.count == 2 else { return XCTFail("Expected single data row with two cells") }

        let cellA = firstRow[0]
        let cellB = firstRow[1]

        // Cell A should contain strong and emphasis
        XCTAssertTrue(containsStrong(in: cellA.inlines), "Expected strong inlines in first cell")
        XCTAssertTrue(containsEmphasis(in: cellA.inlines), "Expected emphasis inlines in first cell")

        // Cell B should contain code and strikethrough
        XCTAssertTrue(containsCode(in: cellB.inlines), "Expected code inline in second cell")
        XCTAssertTrue(containsStrikethrough(in: cellB.inlines), "Expected strikethrough inline in second cell")
    }

    private func containsStrong(in inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .strong:
                return true
            case .emphasis(let children), .strikethrough(let children), .link(_, _, let children):
                if containsStrong(in: children) { return true }
            default: break
            }
        }
        return false
    }

    private func containsEmphasis(in inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .emphasis:
                return true
            case .strong(let children), .strikethrough(let children), .link(_, _, let children):
                if containsEmphasis(in: children) { return true }
            default: break
            }
        }
        return false
    }

    private func containsCode(in inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .code:
                return true
            case .emphasis(let children), .strong(let children), .strikethrough(let children), .link(_, _, let children):
                if containsCode(in: children) { return true }
            default: break
            }
        }
        return false
    }

    private func containsStrikethrough(in inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .strikethrough:
                return true
            case .emphasis(let children), .strong(let children), .link(_, _, let children):
                if containsStrikethrough(in: children) { return true }
            default: break
            }
        }
        return false
    }
}

