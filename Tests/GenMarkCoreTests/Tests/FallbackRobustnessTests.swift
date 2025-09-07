import XCTest
@testable import GenMarkCore

final class FallbackRobustnessTests: XCTestCase {
    func test_empty_input_yields_no_blocks() {
        let parser = CMarkParser()
        let doc = parser.parse(markdown: "")
        XCTAssertEqual(doc.blocks.count, 0)
    }

    func test_only_html_comment_yields_no_blocks() {
        let parser = CMarkParser()
        let md = "<!-- just a comment -->"
        let doc = parser.parse(markdown: md)
        XCTAssertEqual(doc.blocks.count, 0)
    }

    func test_long_fixture_parses_without_crash() throws {
        let parser = CMarkParser()
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "fixture_long", withExtension: "md"))
        let md = try String(contentsOf: url, encoding: .utf8)
        let doc = parser.parse(markdown: md)
        XCTAssertGreaterThan(doc.blocks.count, 0)
    }
}

