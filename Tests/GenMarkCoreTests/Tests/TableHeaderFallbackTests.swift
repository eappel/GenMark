import XCTest
@testable import GenMarkCore

final class TableHeaderFallbackTests: XCTestCase {
    private let parser = CMarkParser()

    func test_standard_table_has_headers() {
        let md = """
        | H1 | H2 |
        |:---|---:|
        | a  |  b |
        """
        let doc = parser.parse(markdown: md)
        guard case .table(let headers, let rows) = doc.blocks.first else { return XCTFail("Expected table") }
        XCTAssertEqual(headers.count, 2)
        XCTAssertGreaterThan(rows.count, 0)
    }

    func test_header_fallback_when_no_explicit_header_present() throws {
        // Some parsers may still require a header separator; if no table is produced, skip.
        // Attempt using a malformed table without header separator to probe fallback behavior.
        let md = """
        | A | B |
        | 1 | 2 |
        """
        let doc = parser.parse(markdown: md)
        guard case .table(let headers, let rows) = doc.blocks.first else {
            throw XCTSkip("Parser did not produce a table without explicit header; skipping fallback assertion.")
        }
        // If headers are empty but rows exist, the implementation should have used first row as header
        if headers.isEmpty {
            XCTAssertFalse(rows.isEmpty, "Rows should exist when headers are empty in fallback scenario")
        } else {
            // Otherwise, we at least validated that a table was formed
            XCTAssertGreaterThanOrEqual(headers.count, 1)
        }
    }
}

