import XCTest
@testable import GenMarkCore

final class HTMLBlockParsingComprehensiveTests: XCTestCase {
    private let parser = CMarkParser()

    func test_unordered_list_case_insensitive_and_whitespace() {
        let md = """
        <UL>
          <LI> One </LI>
          <li> Two</li>
        </UL>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(let kind, let items) = doc.blocks.first else { return XCTFail("Expected list block") }
        XCTAssertEqual(kind, .bullet)
        XCTAssertEqual(items.count, 2)
        if case .paragraph(let inlines) = items[0].children.first {
            let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
            XCTAssertEqual(text, "One")
        }
        if case .paragraph(let inlines) = items[1].children.first {
            let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
            XCTAssertEqual(text, "Two")
        }
    }

    func test_ordered_list_start_attribute_variants() {
        let cases: [(String, Int)] = [
            ("""
            <ol start='4'>
              <li>A</li>
            </ol>
            """, 4),
            ("""
            <ol start=6>
              <li>B</li>
            </ol>
            """, 6),
            ("""
            <OL start="7">
              <li>C</li>
            </OL>
            """, 7)
        ]
        for (md, expectedStart) in cases {
            let doc = parser.parse(markdown: md)
            guard case .list(let kind, let items) = doc.blocks.first else { return XCTFail("Expected list block") }
            guard case .ordered(let start) = kind else { return XCTFail("Expected ordered list kind") }
            XCTAssertEqual(start, expectedStart)
            XCTAssertEqual(items.count, 1)
        }
    }

    func test_br_inside_li_becomes_newline_in_text() {
        let md = """
        <ul>
          <li>First<br>Second</li>
        </ul>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(_, let items) = doc.blocks.first, let first = items.first else { return XCTFail("Expected list with item") }
        guard case .paragraph(let inlines) = first.children.first else { return XCTFail("Expected paragraph in item") }
        let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
        XCTAssertEqual(text, "First\nSecond")
    }

    func test_nested_list_is_flattened_text() {
        let md = """
        <ul>
          <li>Parent<ul><li>Child</li></ul></li>
        </ul>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(_, let items) = doc.blocks.first, let first = items.first else { return XCTFail("Expected list with item") }
        guard case .paragraph(let inlines) = first.children.first else { return XCTFail("Expected paragraph in item") }
        let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
        XCTAssertTrue(text.contains("Parent"))
        XCTAssertTrue(text.contains("Child"))
    }

    func test_multiple_html_lists_in_document() {
        let md = """
        <ul><li>A</li></ul>

        Middle paragraph

        <ol start="2"><li>B</li><li>C</li></ol>
        """
        let doc = parser.parse(markdown: md)
        XCTAssertGreaterThanOrEqual(doc.blocks.count, 3)
        guard case .list(let k1, let items1) = doc.blocks[0] else { return XCTFail("Expected first list") }
        XCTAssertEqual(k1, .bullet)
        XCTAssertEqual(items1.count, 1)
        guard case .paragraph = doc.blocks[1] else { return XCTFail("Expected middle paragraph") }
        guard case .list(let k2, let items2) = doc.blocks[2] else { return XCTFail("Expected second list") }
        guard case .ordered(let start) = k2 else { return XCTFail("Expected ordered kind for second list") }
        XCTAssertEqual(start, 2)
        XCTAssertEqual(items2.count, 2)
    }

    func test_empty_li_are_ignored() {
        let md = """
        <ul>
          <li>  </li>
          <li>Item</li>
          <li>\n\n</li>
        </ul>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(_, let items) = doc.blocks.first else { return XCTFail("Expected list block") }
        XCTAssertEqual(items.count, 1)
        if case .paragraph(let inlines) = items[0].children.first {
            let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
            XCTAssertEqual(text, "Item")
        } else {
            XCTFail("Expected paragraph in list item")
        }
    }

    func test_formatting_tags_inside_li_are_stripped() {
        let md = """
        <ul>
          <li><strong>Bold</strong> and <em>italic</em></li>
        </ul>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(_, let items) = doc.blocks.first, let first = items.first else { return XCTFail("Expected list with item") }
        guard case .paragraph(let inlines) = first.children.first else { return XCTFail("Expected paragraph in item") }
        let text = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
        XCTAssertEqual(text, "Bold and italic")
    }

    func test_ordered_list_without_start_defaults_to_one() {
        let md = """
        <OL>
          <li>One</li>
          <li>Two</li>
        </OL>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(let kind, let items) = doc.blocks.first else { return XCTFail("Expected list block") }
        guard case .ordered(let start) = kind else { return XCTFail("Expected ordered list kind") }
        XCTAssertEqual(start, 1)
        XCTAssertEqual(items.count, 2)
    }
}
