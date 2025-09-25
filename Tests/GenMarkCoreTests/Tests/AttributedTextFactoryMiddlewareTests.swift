import XCTest
import GenMarkCore
import GenMarkUI
import UIKit

final class AttributedTextFactoryMiddlewareTests: XCTestCase {
    @MainActor
    func testInlineCustomizerStillAppliesAttributes() {
        let expectedColor = UIColor.systemPink
        let factory = AttributedTextFactory(
            theme: .systemDefault,
            inlineAttributeAdjuster: { node, attributes in
                guard case .text = node else { return nil }
                var updated = attributes
                updated[.foregroundColor] = expectedColor
                return updated
            }
        )

        let result = factory.make(from: [.text("hello")])
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertEqual(color, expectedColor)
    }

    @MainActor
    func testMiddlewareCanReplaceRenderedOutput() {
        let attachment = NSTextAttachment()
        let middleware: MarkdownInlineRenderer = { node, _, _ in
            guard case .link = node else { return NSAttributedString() }
            return NSAttributedString(attachment: attachment)
        }

        let factory = AttributedTextFactory(
            theme: .systemDefault,
            inlineRenderer: middleware
        )

        let inlines: [InlineNode] = [
            .link(
                url: URL(string: "https://example.com")!,
                title: nil,
                children: [.text("example")]
            )
        ]
        let result = factory.make(from: inlines)
        XCTAssertEqual(result.length, 1)
        let extracted = result.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        XCTAssertTrue(extracted === attachment)
    }

    @MainActor
    func testMiddlewareCanAdjustAttributesBeforeDefaultRendering() {
        let expectedColor = UIColor.systemTeal
        let middleware: MarkdownInlineRenderer = { node, context, render in
            guard case .text = node else { return render(nil) }
            var updated = context.defaultAttributes
            updated[.foregroundColor] = expectedColor
            return render(updated)
        }

        let factory = AttributedTextFactory(
            theme: .systemDefault,
            inlineRenderer: middleware
        )

        let result = factory.make(from: [.text("hello")])
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertEqual(color, expectedColor)
    }

    @MainActor
    func testInlineCustomizerAttributesAvailableInMiddlewareContext() {
        let expectedColor = UIColor.systemBlue
        let factory = AttributedTextFactory(
            theme: .systemDefault,
            inlineAttributeAdjuster: { node, attributes in
                guard case .text = node else { return nil }
                var updated = attributes
                updated[.foregroundColor] = expectedColor
                return updated
            },
            inlineRenderer: { node, context, render in
                guard case .text = node else { return render(nil) }
                let color = context.defaultAttributes[.foregroundColor] as? UIColor
                XCTAssertEqual(color, expectedColor)
                return render(nil)
            }
        )

        let result = factory.make(from: [.text("hello")])
        let attributes = result.attributes(at: 0, effectiveRange: nil)
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertEqual(color, expectedColor)
    }
}
