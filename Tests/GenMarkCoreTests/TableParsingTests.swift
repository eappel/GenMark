import XCTest
@testable import GenMarkCore

final class TableParsingTests: XCTestCase {
    private let parser = CMarkParser()
    
    func test_simple_table_parsing() {
        let md = """
        | Header A | Header B |
        |----------|----------|
        | Cell 1   | Cell 2   |
        | Cell 3   | Cell 4   |
        """
        
        let doc = parser.parse(markdown: md)
        
        // Find the table
        guard case let .table(headers, rows) = doc.blocks.first else {
            XCTFail("Expected table block")
            return
        }
        
        // Check headers
        XCTAssertEqual(headers.count, 2, "Should have 2 headers")
        
        // Check rows
        XCTAssertEqual(rows.count, 2, "Should have 2 data rows")
        
        if rows.count >= 2 {
            XCTAssertEqual(rows[0].count, 2, "First row should have 2 cells")
            XCTAssertEqual(rows[1].count, 2, "Second row should have 2 cells")
        }
    }
    
    func test_table_with_alignment() {
        let md = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | L1   |   C1   |    R1 |
        | L2   |   C2   |    R2 |
        """
        
        let doc = parser.parse(markdown: md)
        
        guard case let .table(headers, rows) = doc.blocks.first else {
            XCTFail("Expected table block")
            return
        }
        
        // Check headers have correct alignment
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(headers[0].alignment, .left)
        XCTAssertEqual(headers[1].alignment, .center)
        XCTAssertEqual(headers[2].alignment, .right)
        
        // Check we have data rows
        XCTAssertEqual(rows.count, 2, "Should have 2 data rows")
    }
    
    func test_fixture_tables_parsing() throws {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "fixture_tables", withExtension: "md"))
        let md = try String(contentsOf: url)
        let doc = parser.parse(markdown: md)
        
        // Find the table block
        var tableFound = false
        var tableHeaders: [TableCell] = []
        var tableRows: [[TableCell]] = []
        
        for block in doc.blocks {
            if case let .table(headers, rows) = block {
                tableFound = true
                tableHeaders = headers
                tableRows = rows
                break
            }
        }
        
        XCTAssertTrue(tableFound, "Should find a table in fixture")
        XCTAssertEqual(tableHeaders.count, 3, "Should have 3 headers")
        XCTAssertGreaterThan(tableRows.count, 0, "Should have at least one data row")
        
        print("DEBUG: Table has \(tableHeaders.count) headers and \(tableRows.count) rows")
        for (i, row) in tableRows.enumerated() {
            print("DEBUG: Row \(i) has \(row.count) cells")
            for (j, cell) in row.enumerated() {
                let text = cell.inlines.compactMap { 
                    if case .text(let s) = $0 { return s } else { return nil }
                }.joined()
                print("  Cell [\(i)][\(j)]: \(text.prefix(30))...")
            }
        }
    }
}