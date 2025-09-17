import XCTest
@testable import GenMarkCore

final class HTMLListBlockParsingTests: XCTestCase {
    private let parser = CMarkParser()

    func test_unordered_html_list_maps_to_bullet_list() {
        let md = """
        Before

        <ul>
          <li>First</li>
          <li>Second</li>
        </ul>

        After
        """

        let doc = parser.parse(markdown: md)
        // Expect: paragraph, list, paragraph
        XCTAssertGreaterThanOrEqual(doc.blocks.count, 3)
        guard case .list(let kind, let items) = doc.blocks[1] else {
            return XCTFail("Expected list block at index 1")
        }
        XCTAssertEqual(kind, .bullet)
        XCTAssertEqual(items.count, 2)
        if case .paragraph(let inlines) = items[0].children.first {
            let txt = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
            XCTAssertEqual(txt, "First")
        } else {
            XCTFail("Expected paragraph in first list item")
        }
    }

    func test_ordered_html_list_with_start_attribute() {
        let md = """
        <ol start="3">
          <li>Three</li>
          <li>Four</li>
        </ol>
        """

        let doc = parser.parse(markdown: md)
        guard case .list(let kind, let items) = doc.blocks.first else {
            return XCTFail("Expected list as first block")
        }
        guard case .ordered(let start) = kind else {
            return XCTFail("Expected ordered list kind")
        }
        XCTAssertEqual(start, 3)
        XCTAssertEqual(items.count, 2)
    }

    func test_html_list_with_paragraph_wrapped_items() {
        let md = """
        <ul>
          <li><p>Alpha</p></li>
          <li><p>Beta</p></li>
        </ul>
        """
        let doc = parser.parse(markdown: md)
        guard case .list(_, let items) = doc.blocks.first else {
            return XCTFail("Expected list block")
        }
        XCTAssertEqual(items.count, 2)
        if case .paragraph(let inlines) = items[1].children.first {
            let txt = inlines.compactMap { if case .text(let s) = $0 { return s } else { return nil } }.joined()
            XCTAssertEqual(txt, "Beta")
        } else {
            XCTFail("Expected paragraph in second list item")
        }
    }
}

