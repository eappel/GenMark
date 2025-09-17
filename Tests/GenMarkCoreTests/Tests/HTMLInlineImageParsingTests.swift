import XCTest
@testable import GenMarkCore

final class HTMLInlineImageParsingTests: XCTestCase {
    private let parser = CMarkParser()

    func test_html_img_tag_maps_to_image_inline() {
        let md = "Before <img src=\"https://example.com/pic.png\" alt=\"Example\" width=\"320\" height=\"200\"> After"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        guard let image = inlines.first(where: { inline in
            if case .image = inline { return true }
            return false
        }) else {
            return XCTFail("Expected image inline")
        }

        if case let .image(url, alt) = image {
            XCTAssertEqual(url.absoluteString, "https://example.com/pic.png")
            XCTAssertEqual(alt, "Example", "Unexpected alt text: \(String(describing: alt))")
        } else {
            XCTFail("Expected image node")
        }
    }

    func test_html_img_without_size_sets_nil_size() {
        let md = "<img src='https://example.com/no-dim.png' alt='No size'>"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        guard let image = inlines.first(where: { inline in
            if case .image = inline { return true }
            return false
        }) else {
            return XCTFail("Expected image inline")
        }

        if case let .image(url, alt) = image {
            XCTAssertEqual(url.absoluteString, "https://example.com/no-dim.png")
            XCTAssertEqual(alt, "No size", "Unexpected alt text: \(String(describing: alt))")
        } else {
            XCTFail("Expected image node")
        }
    }
}
