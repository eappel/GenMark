import UIKit
import GenMarkCore

public struct InlineTextStyle {
    public var font: UIFont
    public var foreground: UIColor
    public var underline: Bool
    public var strikethrough: Bool
    public init(font: UIFont, foreground: UIColor, underline: Bool = false, strikethrough: Bool = false) {
        self.font = font
        self.foreground = foreground
        self.underline = underline
        self.strikethrough = strikethrough
    }
}

public struct AttributedTextFactory {
    public init() {}

    public func make(from inlines: [InlineNode], base: InlineTextStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for inline in inlines {
            switch inline {
            case .text(let s):
                result.append(NSAttributedString(string: s, attributes: base.attributes))
            case .emphasis(let children):
                var italic = base
                italic.font = UIFont.italicSystemFont(ofSize: base.font.pointSize)
                result.append(make(from: children, base: italic))
            case .strong(let children):
                var bold = base
                bold.font = UIFont.systemFont(ofSize: base.font.pointSize, weight: .semibold)
                result.append(make(from: children, base: bold))
            case .strikethrough(let children):
                var s = base
                s.strikethrough = true
                result.append(make(from: children, base: s))
            case .code(let code):
                let font = UIFont.monospacedSystemFont(ofSize: max(12, base.font.pointSize - 2), weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: base.foreground,
                    .baselineOffset: 0
                ]
                result.append(NSAttributedString(string: code, attributes: attrs))
            case .link(let url, _, let children):
                var linkStyle = base
                linkStyle.underline = true
                let child = make(from: children, base: linkStyle)
                let range = NSRange(location: result.length, length: child.length)
                result.append(child)
                result.addAttribute(.link, value: url, range: range)
            case .image(let url, let alt):
                let altText = alt ?? url.absoluteString
                result.append(NSAttributedString(string: altText, attributes: base.attributes))
            case .softBreak:
                result.append(NSAttributedString(string: " ", attributes: base.attributes))
            case .lineBreak:
                result.append(NSAttributedString(string: "\n", attributes: base.attributes))
            case .autolink(let url):
                let s = NSAttributedString(string: url.absoluteString, attributes: base.attributes)
                let range = NSRange(location: result.length, length: s.length)
                result.append(s)
                result.addAttribute(.link, value: url, range: range)
            case .footnoteReference(let label):
                result.append(NSAttributedString(string: "[", attributes: base.attributes))
                result.append(NSAttributedString(string: label, attributes: base.attributes))
                result.append(NSAttributedString(string: "]", attributes: base.attributes))
            }
        }
        return result
    }
}

private extension InlineTextStyle {
    var attributes: [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foreground
        ]
        if underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return attrs
    }
}
