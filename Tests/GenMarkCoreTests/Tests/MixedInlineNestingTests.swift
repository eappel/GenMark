import XCTest
@testable import GenMarkCore

final class MixedInlineNestingTests: XCTestCase {
    private let parser = CMarkParser()

    func test_emphasis_within_strong_and_link_and_code() {
        let md = """
        **Bold with *italic* and [a link](https://example.com) and `code`**
        """
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }

        // Find a strong node
        guard let strong = inlines.first(where: { if case .strong = $0 { return true } else { return false } }) else {
            return XCTFail("Expected a strong inline at top level")
        }

        // Extract children of the strong node
        var strongChildren: [InlineNode] = []
        if case .strong(let children) = strong { strongChildren = children }

        // Assertions: contains nested emphasis, link, and code within strong
        XCTAssertTrue(containsEmphasis(in: strongChildren), "Expected emphasis nested within strong")
        XCTAssertTrue(containsLink(in: strongChildren), "Expected link nested within strong")
        XCTAssertTrue(containsCode(in: strongChildren), "Expected code nested within strong")
    }

    private func containsEmphasis(in inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .emphasis:
                return true
            case .strong(let children), .strikethrough(let children), .link(_, _, let children):
                if containsEmphasis(in: children) { return true }
            default:
                break
            }
        }
        return false
    }

    private func containsLink(in inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .link:
                return true
            case .emphasis(let children), .strong(let children), .strikethrough(let children):
                if containsLink(in: children) { return true }
            default:
                break
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
            default:
                break
            }
        }
        return false
    }
}

