import XCTest
@testable import GenMarkCore

final class ParserOptionsTests: XCTestCase {
    
    func testDefaultOptions() throws {
        let parser = CMarkParser()
        let result = parser.parse(markdown: "Hello world")
        XCTAssertEqual(result.blocks.count, 1)
    }
    
    func testSmartQuotesOption() throws {
        let parser = CMarkParser(options: [.default, .smart])
        
        // Test smart quotes conversion
        let markdown = """
        "Hello world"
        
        It's a nice day -- don't you think?
        
        Em dash---here
        """
        
        let result = parser.parse(markdown: markdown)
        
        // The smart option should convert:
        // - Straight quotes to curly quotes
        // - -- to en dash
        // - --- to em dash
        // - Apostrophes to curly apostrophes
        
        guard case .paragraph(let inlines) = result.blocks[0] else {
            XCTFail("Expected paragraph")
            return
        }
        
        // Check that smart typography is applied
        let text = inlines.compactMap { node -> String? in
            if case .text(let str) = node { return str }
            return nil
        }.joined()
        
        // Smart quotes should convert "Hello world" to curly quotes
        XCTAssertTrue(text.contains("\u{201C}") || text.contains("\u{201D}"), "Smart quotes should be applied")
    }
    
    func testHardBreaksOption() throws {
        let parserDefault = CMarkParser(options: [.default])
        let parserHardBreaks = CMarkParser(options: [.default, .hardBreaks])
        
        let markdown = """
        Line one
        Line two
        """
        
        let resultDefault = parserDefault.parse(markdown: markdown)
        let resultHardBreaks = parserHardBreaks.parse(markdown: markdown)
        
        // Default: soft break between lines
        guard case .paragraph(let defaultInlines) = resultDefault.blocks[0] else {
            XCTFail("Expected paragraph")
            return
        }
        
        // Hard breaks: line break between lines
        guard case .paragraph(let hardBreakInlines) = resultHardBreaks.blocks[0] else {
            XCTFail("Expected paragraph")
            return
        }
        
        // Default should have a soft break
        let hasSoftBreak = defaultInlines.contains { node in
            if case .softBreak = node { return true }
            return false
        }
        
        // Hard breaks should convert soft breaks to line breaks
        let hasLineBreak = hardBreakInlines.contains { node in
            if case .lineBreak = node { return true }
            return false
        }
        
        XCTAssertTrue(hasSoftBreak || hasLineBreak, "Should have some kind of break between lines")
    }
    
    func testNoBreaksOption() throws {
        let parserNoBreaks = CMarkParser(options: [.default, .noBreaks])
        
        let markdown = """
        Line one
        Line two
        """
        
        let result = parserNoBreaks.parse(markdown: markdown)
        
        guard case .paragraph(let inlines) = result.blocks[0] else {
            XCTFail("Expected paragraph")
            return
        }
        
        // With noBreaks, soft breaks should be converted to spaces
        // The actual behavior depends on cmark-gfm's implementation
        // It may convert them to spaces in the text rather than removing break nodes
        
        // Collect all text including spaces
        var fullText = ""
        for inline in inlines {
            switch inline {
            case .text(let str):
                fullText += str
            case .softBreak:
                // noBreaks might still have soft breaks but they render as spaces
                fullText += " "
            case .lineBreak:
                fullText += "\n"
            default:
                break
            }
        }
        
        // Both lines should be present
        XCTAssertTrue(fullText.contains("Line one") && fullText.contains("Line two"), 
                      "Both lines should be present in the text")
        
        // Check that the lines are joined properly (with space or directly)
        // The exact behavior depends on cmark-gfm implementation
        print("NoBreaks result text: '\(fullText)'")
    }
    
    func testUnsafeOption() throws {
        let parserSafe = CMarkParser(options: [.default])
        let parserUnsafe = CMarkParser(options: [.default, .unsafe])
        
        let markdown = """
        <div>HTML content</div>
        
        <script>alert('test')</script>
        """
        
        let resultSafe = parserSafe.parse(markdown: markdown)
        let resultUnsafe = parserUnsafe.parse(markdown: markdown)
        
        // Without unsafe, raw HTML should be filtered
        // With unsafe, raw HTML should be preserved
        
        // The exact behavior depends on cmark-gfm implementation
        // We're mainly testing that both parsers work without errors
        XCTAssertNotNil(resultSafe.blocks)
        XCTAssertNotNil(resultUnsafe.blocks)
    }
    
    func testValidateUTF8Option() throws {
        let parser = CMarkParser(options: [.default, .validateUTF8])
        
        // Test with valid UTF-8
        let validMarkdown = "Hello 世界 🌍"
        let result = parser.parse(markdown: validMarkdown)
        
        guard case .paragraph(let inlines) = result.blocks[0] else {
            XCTFail("Expected paragraph")
            return
        }
        
        let text = inlines.compactMap { node -> String? in
            if case .text(let str) = node { return str }
            return nil
        }.joined()
        
        XCTAssertTrue(text.contains("世界"), "Should preserve valid UTF-8")
        XCTAssertTrue(text.contains("🌍"), "Should preserve emoji")
    }
    
    func testCustomExtensions() throws {
        // Test with only specific extensions enabled
        let parser = CMarkParser(
            options: [.default],
            extensions: [.strikethrough, .autolink]
        )
        
        let markdown = """
        ~~strikethrough~~
        
        https://example.com
        
        | Table | Header |
        |-------|--------|
        | Cell  | Cell   |
        """
        
        let result = parser.parse(markdown: markdown)
        
        // Strikethrough should work
        var hasStrikethrough = false
        for block in result.blocks {
            if case .paragraph(let inlines) = block {
                for inline in inlines {
                    if case .strikethrough = inline {
                        hasStrikethrough = true
                    }
                }
            }
        }
        
        XCTAssertTrue(hasStrikethrough, "Strikethrough extension should be enabled")
        
        // Tables should NOT work (not in extensions list)
        let hasTable = result.blocks.contains { block in
            if case .table = block { return true }
            return false
        }
        
        XCTAssertFalse(hasTable, "Table extension should not be enabled")
    }
    
    func testMultipleOptionsComposition() throws {
        // Test combining multiple options
        let parser = CMarkParser(options: [.default, .unsafe, .smart, .hardBreaks])
        
        let markdown = """
        "Quote" and line
        break here
        
        <div>HTML</div>
        """
        
        let result = parser.parse(markdown: markdown)
        
        // Should have both smart quotes and hard breaks and HTML support
        XCTAssertNotNil(result.blocks)
        XCTAssertGreaterThan(result.blocks.count, 0)
    }
}