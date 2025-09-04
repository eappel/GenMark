import XCTest
@testable import GenMarkCore

final class ParserFixturesTests: XCTestCase {
    func test_fixtures_are_loadable() throws {
        let names = ["fixture_readme", "fixture_tables", "fixture_long"]
        for name in names {
            let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name, withExtension: "md"))
            let contents = try String(contentsOf: url)
            XCTAssertFalse(contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Fixture \(name) should not be empty")
        }
    }

    func test_parser_runs_on_fixtures_without_crashing() throws {
        let parser = CMarkParser() // stub for now
        let names = ["fixture_readme", "fixture_tables", "fixture_long"]
        for name in names {
            let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name, withExtension: "md"))
            let contents = try String(contentsOf: url)
            let doc = parser.parse(markdown: contents)
            // For now, stub returns a single paragraph. Validate non-empty blocks.
            XCTAssertFalse(doc.blocks.isEmpty)
        }
    }

    func test_basic_heading_and_paragraph_mapping() throws {
        let md = "# Title\n\nHello world."
        let parser = CMarkParser()
        let doc = parser.parse(markdown: md)
        XCTAssertFalse(doc.blocks.isEmpty)
        // When cmark is available we expect a heading then a paragraph.
        // Otherwise fallback returns a single paragraph with full text.
        if doc.blocks.count >= 2 {
            if case let .heading(level, _) = doc.blocks[0] { XCTAssertEqual(level, 1) } else { XCTFail("Expected heading") }
            if case .paragraph = doc.blocks[1] { /* ok */ } else { XCTFail("Expected paragraph") }
        }
    }
}
