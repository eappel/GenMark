import XCTest
@testable import GenMarkCore

final class ParserInitializersTests: XCTestCase {

    func test_minimal_has_no_gfm_features() {
        let parser = CMarkParser.minimal()
        let md = """
        ~~strike~~

        | T |
        |---|
        | 1 |

        autolink: https://example.com
        """
        let doc = parser.parse(markdown: md)

        // No table blocks expected
        XCTAssertFalse(doc.blocks.contains { if case .table = $0 { return true } else { return false } })

        // Collect first paragraph inlines to check strikethrough and link
        if let firstParagraph = doc.blocks.first, case .paragraph(let inlines) = firstParagraph {
            let hasStrike = inlines.contains { if case .strikethrough = $0 { return true } else { return false } }
            let hasLink = inlines.contains { if case .link = $0 { return true } else { return false } }
            XCTAssertFalse(hasStrike, "Minimal parser should not produce strikethrough inline")
            XCTAssertFalse(hasLink, "Minimal parser should not autolink URLs")
        }
    }

    func test_standard_enables_gfm_without_smart() {
        let parser = CMarkParser.standard()
        let md = """
        ~~strike~~

        | A | B |
        |---|---|
        | 1 | 2 |

        autolink: https://swift.org
        """
        let doc = parser.parse(markdown: md)

        // Table should be present
        XCTAssertTrue(doc.blocks.contains { if case .table = $0 { return true } else { return false } })

        // Strikethrough inline should appear somewhere
        let hasStrikeAnywhere: Bool = doc.blocks.contains { block in
            if case .paragraph(let inlines) = block {
                return inlines.contains { if case .strikethrough = $0 { return true } else { return false } }
            }
            return false
        }
        XCTAssertTrue(hasStrikeAnywhere, "Standard parser should support strikethrough")

        // Autolink should be present
        let hasAutolink: Bool = doc.blocks.contains { block in
            if case .paragraph(let inlines) = block {
                return inlines.contains { if case .link = $0 { return true } else { return false } }
            }
            return false
        }
        XCTAssertTrue(hasAutolink, "Standard parser should autolink URLs")
    }

    func test_maximal_matches_default_capabilities() {
        let a = CMarkParser.maximal()
        let b = CMarkParser() // default
        let md = """
        ~~strike~~ and https://example.com

        | A | B |
        |---|---|
        | 1 | 2 |
        """

        let docA = a.parse(markdown: md)
        let docB = b.parse(markdown: md)

        func hasStrike(_ doc: MarkdownDocument) -> Bool {
            doc.blocks.contains { block in
                if case .paragraph(let inlines) = block {
                    return inlines.contains { if case .strikethrough = $0 { return true } else { return false } }
                }
                return false
            }
        }
        func hasAutolink(_ doc: MarkdownDocument) -> Bool {
            doc.blocks.contains { block in
                if case .paragraph(let inlines) = block {
                    return inlines.contains { if case .link = $0 { return true } else { return false } }
                }
                return false
            }
        }
        func hasTable(_ doc: MarkdownDocument) -> Bool {
            doc.blocks.contains { if case .table = $0 { return true } else { return false } }
        }

        XCTAssertEqual(hasStrike(docA), hasStrike(docB))
        XCTAssertEqual(hasAutolink(docA), hasAutolink(docB))
        XCTAssertEqual(hasTable(docA), hasTable(docB))
    }
}

