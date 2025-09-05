import XCTest
@testable import GenMarkCore

final class HTMLTagTests: XCTestCase {
    private let parser = CMarkParser()
    
    func test_br_tag_in_paragraph() {
        let md = "Line one<br>Line two<br/>Line three"
        let doc = parser.parse(markdown: md)
        
        guard case let .paragraph(inlines) = doc.blocks.first else {
            XCTFail("Expected paragraph block")
            return
        }
        
        // Should have text, lineBreak, text, lineBreak, text
        var hasLineBreak = false
        for inline in inlines {
            if case .lineBreak = inline {
                hasLineBreak = true
                break
            }
        }
        
        XCTAssertTrue(hasLineBreak, "Should convert <br> tags to line breaks")
    }
    
    func test_br_tag_in_table_cell() {
        let md = """
        | Header |
        |--------|
        | Line 1<br>Line 2 |
        """
        
        let doc = parser.parse(markdown: md)
        
        guard case let .table(_, rows) = doc.blocks.first else {
            XCTFail("Expected table block")
            return
        }
        
        XCTAssertEqual(rows.count, 1, "Should have one data row")
        
        if let firstRow = rows.first, let firstCell = firstRow.first {
            var hasLineBreak = false
            for inline in firstCell.inlines {
                if case .lineBreak = inline {
                    hasLineBreak = true
                    break
                }
            }
            XCTAssertTrue(hasLineBreak, "Table cell should contain line break from <br> tag")
        }
    }
    
    func test_multiple_br_tags() {
        let md = "Text with<br><br>double break"
        let doc = parser.parse(markdown: md)
        
        guard case let .paragraph(inlines) = doc.blocks.first else {
            XCTFail("Expected paragraph block")
            return
        }
        
        var lineBreakCount = 0
        for inline in inlines {
            if case .lineBreak = inline {
                lineBreakCount += 1
            }
        }
        
        XCTAssertGreaterThanOrEqual(lineBreakCount, 1, "Should have at least one line break")
    }
    
    func test_br_tag_variations() {
        // Test different BR tag formats
        let variations = [
            "<br>",
            "<BR>",
            "<br/>",
            "<br />",
            "<BR/>"
        ]
        
        for brTag in variations {
            let md = "Line 1\(brTag)Line 2"
            let doc = parser.parse(markdown: md)
            
            guard case let .paragraph(inlines) = doc.blocks.first else {
                XCTFail("Expected paragraph for \(brTag)")
                continue
            }
            
            var hasLineBreak = false
            for inline in inlines {
                if case .lineBreak = inline {
                    hasLineBreak = true
                    break
                }
            }
            
            XCTAssertTrue(hasLineBreak, "Should handle \(brTag) variation")
        }
    }
    
    func test_fixture_tables_with_br_tags() throws {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "fixture_tables", withExtension: "md"))
        let md = try String(contentsOf: url)
        let doc = parser.parse(markdown: md)
        
        // Find the table
        guard case let .table(_, rows) = doc.blocks.first(where: { 
            if case .table = $0 { return true }
            return false
        }) else {
            XCTFail("Expected table in fixture")
            return
        }
        
        // Check that cells with <br> tags have line breaks
        for row in rows {
            for cell in row {
                let textContent = cell.inlines.compactMap { 
                    if case .text(let s) = $0 { return s }
                    return nil
                }.joined()
                
                // If the original text had <br>, we should have line breaks in inlines
                if textContent.contains("lines") || textContent.contains("item") {
                    // These cells should have line breaks
                    let hasLineBreak = cell.inlines.contains { 
                        if case .lineBreak = $0 { return true }
                        return false
                    }
                    if textContent.contains("lines") {
                        XCTAssertTrue(hasLineBreak, "Multi-line cell should have line breaks")
                    }
                }
            }
        }
    }
}