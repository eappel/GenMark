import XCTest
@testable import GenMarkCore

final class TableAlignmentWideTests: XCTestCase {
    private let parser = CMarkParser()

    func test_alignment_across_many_columns_and_empty_cells() {
        let md = """
        | L  | C  | R  | C2 | L2 |
        |:---|:--:|---:|:--:|:---|
        |    | b  | c  | d  | e  |
        | x  |    |    |    |    |
        """

        let doc = parser.parse(markdown: md)
        guard case .table(let headers, let rows) = doc.blocks.first else { return XCTFail("Expected table") }

        // Expect 5 headers with specified alignment
        XCTAssertEqual(headers.count, 5)
        let aligns = headers.map { $0.alignment }
        XCTAssertEqual(aligns, [.left, .center, .right, .center, .left])

        // Expect 2 data rows with 5 cells each
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].count, 5)
        XCTAssertEqual(rows[1].count, 5)

        // Check empty cells are present and handled (joined text is empty)
        func cellText(_ cell: TableCell) -> String {
            cell.inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
        }
        XCTAssertEqual(cellText(rows[0][0]), "")
        XCTAssertEqual(cellText(rows[1][1]), "")
    }
}

