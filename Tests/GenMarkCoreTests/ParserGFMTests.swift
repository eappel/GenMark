import XCTest
@testable import GenMarkCore

final class ParserGFMTests: XCTestCase {
    private let parser = CMarkParser()

    func test_headings_levels_are_mapped() {
        let md = "# H1\n\n## H2\n\n### H3"
        let doc = parser.parse(markdown: md)
        let headings = doc.blocks.compactMap { block -> (Int, [InlineNode])? in
            if case let .heading(level, inlines) = block { return (level, inlines) }
            return nil
        }
        XCTAssertEqual(headings.count, 3)
        XCTAssertEqual(headings.map { $0.0 }, [1, 2, 3])
    }

    func test_task_list_checked_state() {
        let md = "- [ ] Todo\n- [x] Done"
        let doc = parser.parse(markdown: md)
        guard case let .list(kind, items) = doc.blocks.first else { return XCTFail("Expected list") }
        // We classify any list with task items as .task
        XCTAssertEqual(kind, .task)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].checked, false)
        XCTAssertEqual(items[1].checked, true)
    }

    func test_code_fence_language_is_captured() {
        let md = "```swift\nprint(\"hi\")\n```"
        let doc = parser.parse(markdown: md)
        guard case let .codeBlock(language, code) = doc.blocks.first else { return XCTFail("Expected code block") }
        XCTAssertEqual(language, "swift")
        XCTAssertTrue(code.contains("print"))
    }

    func test_strikethrough_inline() {
        let md = "~~gone~~"
        let doc = parser.parse(markdown: md)
        guard case let .paragraph(inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        XCTAssertTrue(containsStrikethrough(inlines))
    }

    func test_autolink_and_link() {
        let md = "Autolink: <https://example.org> and [link](https://swift.org)"
        let doc = parser.parse(markdown: md)
        guard case let .paragraph(inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        let links = collectLinks(inlines)
        let urls = links.map { $0.absoluteString }
        XCTAssertTrue(urls.contains("https://example.org"))
        XCTAssertTrue(urls.contains("https://swift.org"))
    }

    func test_image_inline() {
        let md = "![alt](https://example.com/img.png)"
        let doc = parser.parse(markdown: md)
        guard case let .paragraph(inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        let images = inlines.compactMap { inline -> URL? in
            if case let .image(url, _) = inline { return url }
            return nil
        }
        XCTAssertEqual(images.first?.absoluteString, "https://example.com/img.png")
    }

    func test_table_alignment_from_fixture() throws {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "fixture_tables", withExtension: "md"))
        let md = try String(contentsOf: url)
        let doc = parser.parse(markdown: md)
        guard let table = firstTable(in: doc.blocks) else { return XCTFail("Expected table") }
        // Table with 3 headers: left, center, right
        XCTAssertEqual(table.headers.count, 3)
        let aligns = table.headers.map { $0.alignment }
        XCTAssertEqual(aligns, [.left, .center, .right])
    }

    // MARK: - Helpers

    private func containsStrikethrough(_ inlines: [InlineNode]) -> Bool {
        for inline in inlines {
            switch inline {
            case .strikethrough:
                return true
            case .emphasis(let children), .strong(let children):
                if containsStrikethrough(children) { return true }
            default: break
            }
        }
        return false
    }

    private func collectLinks(_ inlines: [InlineNode]) -> [URL] {
        var result: [URL] = []
        for inline in inlines {
            switch inline {
            case .link(let url, _, let children):
                result.append(url)
                result.append(contentsOf: collectLinks(children))
            case .emphasis(let children), .strong(let children), .strikethrough(let children):
                result.append(contentsOf: collectLinks(children))
            default: break
            }
        }
        return result
    }

    private func firstTable(in blocks: [BlockNode]) -> (headers: [TableCell], rows: [[TableCell]])? {
        for block in blocks {
            switch block {
            case .table(let headers, let rows):
                return (headers, rows)
            case .blockQuote(let children):
                if let t = firstTable(in: children) { return t }
            case .list(_, let items):
                for item in items {
                    if let t = firstTable(in: item.children) { return t }
                }
            case .document(let children):
                if let t = firstTable(in: children) { return t }
            default:
                break
            }
        }
        return nil
    }
}

