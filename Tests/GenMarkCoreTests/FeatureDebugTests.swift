import XCTest
@testable import GenMarkCore

final class FeatureDebugTests: XCTestCase {
    
    func testHighlightExtensionAvailability() throws {
        // Test if highlight/mark extension is actually available
        let parser = CMarkParser(
            options: [.default],
            extensions: []  // highlight/mark not available
        )
        
        let markdown = "==highlighted text=="
        let result = parser.parse(markdown: markdown)
        
        print("\n=== HIGHLIGHT TEST ===")
        print("Input: \(markdown)")
        print("Blocks: \(result.blocks)")
        
        if case .paragraph(let inlines) = result.blocks.first {
            print("Inlines in paragraph:")
            for inline in inlines {
                switch inline {
                case .text(let text):
                    print("  - Found text: '\(text)'")
                default:
                    print("  - Found other: \(inline)")
                }
            }
        }
        
        // Check if it's being parsed as text instead
        let hasHighlightNode = result.blocks.contains { block in
            if case .paragraph(let inlines) = block {
                return inlines.contains { inline in
                    // if case .highlight = inline { return true }  // Not available
                    return false
                }
            }
            return false
        }
        
        print("Has highlight node: \(hasHighlightNode)")
        
        // Note: The highlight extension might not be part of standard cmark-gfm
        // It's possible that ==text== is not supported by the library we're using
    }
    
    func testSmartTypographyActuallyWorks() throws {
        let regularParser = CMarkParser(options: [.default])
        let smartParser = CMarkParser(options: [.default, .smart])
        
        let markdown = """
        "Hello world"
        It's great -- really --- awesome
        """
        
        let regularResult = regularParser.parse(markdown: markdown)
        let smartResult = smartParser.parse(markdown: markdown)
        
        print("\n=== SMART TYPOGRAPHY TEST ===")
        print("Input: \(markdown)")
        
        // Extract text from regular parser
        var regularText = ""
        if case .paragraph(let inlines) = regularResult.blocks.first {
            for inline in inlines {
                if case .text(let text) = inline {
                    regularText += text
                }
            }
        }
        
        // Extract text from smart parser
        var smartText = ""
        if case .paragraph(let inlines) = smartResult.blocks.first {
            for inline in inlines {
                if case .text(let text) = inline {
                    smartText += text
                }
            }
        }
        
        print("Regular text: '\(regularText)'")
        print("Smart text: '\(smartText)'")
        
        let hasSmartQuotes = smartText.contains("\u{201C}") || smartText.contains("\u{201D}") ||
                            smartText.contains("\u{2018}") || smartText.contains("\u{2019}")
        let hasSmartDashes = smartText.contains("\u{2014}") || smartText.contains("\u{2013}")
        
        print("Has smart quotes: \(hasSmartQuotes)")
        print("Has smart dashes: \(hasSmartDashes)")
        
        // Check if there's any difference at all
        if regularText == smartText {
            print("WARNING: Smart typography made no difference!")
        }
    }
    
    func testAvailableExtensions() throws {
        // Test which extensions actually work
        let extensions = GFMExtension.allCases
        
        print("\n=== EXTENSION AVAILABILITY TEST ===")
        
        for ext in extensions {
            let parser = CMarkParser(
                options: [.default],
                extensions: [ext]
            )
            
            var testMarkdown = ""
            
            switch ext {
            case .autolink:
                testMarkdown = "https://example.com"
            case .strikethrough:
                testMarkdown = "~~strike~~"
            case .table:
                testMarkdown = "| A | B |\n|---|---|\n| 1 | 2 |"
            case .tasklist:
                testMarkdown = "- [ ] task"
            case .tagfilter:
                testMarkdown = "<script>alert('test')</script>"
            }
            
            let result = parser.parse(markdown: testMarkdown)
            
            var featureFound = false
            for block in result.blocks {
                switch ext {
                case .table:
                    if case .table = block { featureFound = true }
                case .tasklist:
                    if case .list(let kind, _) = block,
                       case .task = kind { featureFound = true }
                case .strikethrough:
                    if case .paragraph(let inlines) = block {
                        featureFound = inlines.contains { inline in
                            if case .strikethrough = inline { return true }
                            return false
                        }
                    }
                case .autolink:
                    if case .paragraph(let inlines) = block {
                        featureFound = inlines.contains { inline in
                            if case .link = inline { return true }
                            if case .autolink = inline { return true }
                            return false
                        }
                    }
                default:
                    break
                }
            }
            
            print("Extension '\(ext)': \(featureFound ? "✅ WORKS" : "❌ NOT WORKING")")
        }
    }
    
    func testParserOptionsActualEffect() throws {
        print("\n=== PARSER OPTIONS EFFECT TEST ===")
        
        // Test HARDBREAKS
        let hardBreaksParser = CMarkParser(options: [.default, .hardBreaks])
        let normalParser = CMarkParser(options: [.default])
        
        let lineBreakMarkdown = "Line 1\nLine 2"
        
        let hardResult = hardBreaksParser.parse(markdown: lineBreakMarkdown)
        let normalResult = normalParser.parse(markdown: lineBreakMarkdown)
        
        var hardBreakCount = 0
        var softBreakCount = 0
        
        if case .paragraph(let inlines) = hardResult.blocks.first {
            for inline in inlines {
                if case .lineBreak = inline { hardBreakCount += 1 }
                if case .softBreak = inline { softBreakCount += 1 }
            }
        }
        
        print("HardBreaks option: \(hardBreakCount) hard breaks, \(softBreakCount) soft breaks")
        
        hardBreakCount = 0
        softBreakCount = 0
        
        if case .paragraph(let inlines) = normalResult.blocks.first {
            for inline in inlines {
                if case .lineBreak = inline { hardBreakCount += 1 }
                if case .softBreak = inline { softBreakCount += 1 }
            }
        }
        
        print("Normal option: \(hardBreakCount) hard breaks, \(softBreakCount) soft breaks")
        
        // Test NOBREAKS
        let noBreaksParser = CMarkParser(options: [.default, .noBreaks])
        let noBreaksResult = noBreaksParser.parse(markdown: lineBreakMarkdown)
        
        var noBreaksText = ""
        if case .paragraph(let inlines) = noBreaksResult.blocks.first {
            for inline in inlines {
                switch inline {
                case .text(let text):
                    noBreaksText += text
                case .softBreak:
                    noBreaksText += "[SOFTBREAK]"
                case .lineBreak:
                    noBreaksText += "[LINEBREAK]"
                default:
                    break
                }
            }
        }
        
        print("NoBreaks result: '\(noBreaksText)'")
    }
    
    func testHTMLParsing() throws {
        print("\n=== HTML PARSING TEST ===")
        
        let unsafeParser = CMarkParser(options: [.default, .unsafe])
        let safeParser = CMarkParser(options: [.default])
        
        let htmlMarkdown = "Text<br>New line"
        
        let unsafeResult = unsafeParser.parse(markdown: htmlMarkdown)
        let safeResult = safeParser.parse(markdown: htmlMarkdown)
        
        print("HTML markdown: \(htmlMarkdown)")
        
        // Check unsafe parser
        if case .paragraph(let inlines) = unsafeResult.blocks.first {
            print("Unsafe parser inlines:")
            for inline in inlines {
                switch inline {
                case .lineBreak:
                    print("  - LineBreak (from <br>)")
                case .text(let text):
                    print("  - Text: '\(text)'")
                default:
                    print("  - Other: \(inline)")
                }
            }
        }
        
        // Check safe parser
        if case .paragraph(let inlines) = safeResult.blocks.first {
            print("Safe parser inlines:")
            for inline in inlines {
                switch inline {
                case .lineBreak:
                    print("  - LineBreak (from <br>)")
                case .text(let text):
                    print("  - Text: '\(text)'")
                default:
                    print("  - Other: \(inline)")
                }
            }
        }
    }
}