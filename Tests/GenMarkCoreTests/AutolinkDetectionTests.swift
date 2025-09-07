import XCTest
@testable import GenMarkCore

final class AutolinkDetectionTests: XCTestCase {
    func test_www_autolink_detected() {
        let parser = CMarkParser()
        let md = "Visit www.example.com for details"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        XCTAssertTrue(inlines.contains { if case .link = $0 { return true } else { return false } })
    }

    func test_email_autolink_detected() {
        let parser = CMarkParser()
        let md = "Contact support@example.com for help"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        let hasMailto = inlines.contains { inline in
            if case .link(let url, _, _) = inline { return url.absoluteString.contains("mailto:") || url.absoluteString.contains("@") }
            return false
        }
        XCTAssertTrue(hasMailto)
    }

    func test_protocol_autolink_detected() {
        let parser = CMarkParser()
        let md = "https://swift.org is great"
        let doc = parser.parse(markdown: md)
        guard case .paragraph(let inlines) = doc.blocks.first else { return XCTFail("Expected paragraph") }
        XCTAssertTrue(inlines.contains { if case .link = $0 { return true } else { return false } })
    }
}

