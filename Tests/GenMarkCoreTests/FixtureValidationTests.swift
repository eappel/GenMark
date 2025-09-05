import XCTest
@testable import GenMarkCore

final class FixtureValidationTests: XCTestCase {
    
    func testParserOptionsFixture() throws {
        let url = Bundle.module.url(forResource: "fixture_parser_options", withExtension: "md")!
        let markdown = try String(contentsOf: url, encoding: .utf8)
        
        // Test with default options
        let defaultParser = CMarkParser()
        let defaultResult = defaultParser.parse(markdown: markdown)
        XCTAssertFalse(defaultResult.blocks.isEmpty, "Should parse fixture with default options")
        
        // Test with smart typography
        let smartParser = CMarkParser(options: [.default, .unsafe, .smart])
        let smartResult = smartParser.parse(markdown: markdown)
        XCTAssertFalse(smartResult.blocks.isEmpty, "Should parse fixture with smart options")
        
        // Note: highlight/mark extension is not available in swift-cmark
        // The ==text== syntax will be parsed as regular text
        // Keeping this code for future reference if the extension becomes available
        /*
        var highlightCount = 0
        for block in defaultResult.blocks {
            highlightCount += countHighlights(in: block)
        }
        print("Found \(highlightCount) highlight nodes in fixture")
        */
        
        // Test HTML parsing
        var hasHTMLBreaks = false
        for block in defaultResult.blocks {
            if case .paragraph(let inlines) = block {
                for inline in inlines {
                    if case .lineBreak = inline {
                        hasHTMLBreaks = true
                        break
                    }
                }
            }
        }
        
        XCTAssertTrue(hasHTMLBreaks, "Should have line breaks from <br> tags")
    }
    
    func testUpdatedReadmeFixture() throws {
        let url = Bundle.module.url(forResource: "fixture_readme", withExtension: "md")!
        let markdown = try String(contentsOf: url, encoding: .utf8)
        
        let parser = CMarkParser(options: [.default, .unsafe])
        let result = parser.parse(markdown: markdown)
        
        XCTAssertFalse(result.blocks.isEmpty, "Should parse updated readme fixture")
        
        // Check for various elements
        var hasStrikethrough = false
        var hasTable = false
        var hasTaskList = false
        
        for block in result.blocks {
            switch block {
            case .table:
                hasTable = true
            case .list(let kind, _):
                if case .task = kind {
                    hasTaskList = true
                }
            case .paragraph(let inlines):
                for inline in inlines {
                    if case .strikethrough = inline {
                        hasStrikethrough = true
                    }
                }
            default:
                break
            }
        }
        
        XCTAssertTrue(hasStrikethrough, "Should have strikethrough in readme")
        XCTAssertTrue(hasTable, "Should have table in readme")
        XCTAssertTrue(hasTaskList, "Should have task list in readme")
    }
    
    func testFixtureWithCustomExtensions() throws {
        let url = Bundle.module.url(forResource: "fixture_parser_options", withExtension: "md")!
        let markdown = try String(contentsOf: url, encoding: .utf8)
        
        // Test with limited extensions
        let limitedParser = CMarkParser(
            options: [.default],
            extensions: [.strikethrough, .autolink] // No table support
        )
        
        let result = limitedParser.parse(markdown: markdown)
        
        // Should still parse but tables won't be recognized as tables
        XCTAssertFalse(result.blocks.isEmpty, "Should parse with limited extensions")
        
        var hasTable = false
        for block in result.blocks {
            if case .table = block {
                hasTable = true
            }
        }
        
        XCTAssertFalse(hasTable, "Should not have table nodes without table extension")
    }
    
    private func countHighlights(in block: BlockNode) -> Int {
        var count = 0
        
        switch block {
        case .paragraph(let inlines), .heading(_, let inlines):
            for inline in inlines {
                count += countHighlights(in: inline)
            }
        case .list(_, let items):
            for item in items {
                for child in item.children {
                    count += countHighlights(in: child)
                }
            }
        case .blockQuote(let children), .document(let children):
            for child in children {
                count += countHighlights(in: child)
            }
        case .table(let headers, let rows):
            for header in headers {
                for inline in header.inlines {
                    count += countHighlights(in: inline)
                }
            }
            for row in rows {
                for cell in row {
                    for inline in cell.inlines {
                        count += countHighlights(in: inline)
                    }
                }
            }
        default:
            break
        }
        
        return count
    }
    
    private func countHighlights(in inline: InlineNode) -> Int {
        switch inline {
        // case .highlight:  // Not available in swift-cmark
        //     return 1
        case .emphasis(let children), .strong(let children), .strikethrough(let children):
            var count = 0
            for child in children {
                count += countHighlights(in: child)
            }
            return count
        case .link(_, _, let children):
            var count = 0
            for child in children {
                count += countHighlights(in: child)
            }
            return count
        default:
            return 0
        }
    }
}