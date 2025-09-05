import Foundation

// MARK: - Core Node Model (minimal stub to start)

public enum BlockNode: Equatable, Sendable {
    case document(children: [BlockNode])
    case heading(level: Int, inlines: [InlineNode])
    case paragraph(inlines: [InlineNode])
    case list(kind: ListKind, items: [ListItem])
    case blockQuote(children: [BlockNode])
    case codeBlock(language: String?, code: String)
    case thematicBreak
    case table(headers: [TableCell], rows: [[TableCell]])
}

public enum InlineNode: Equatable, Sendable {
    case text(String)
    case emphasis([InlineNode])
    case strong([InlineNode])
    case strikethrough([InlineNode])
    case code(String)
    case link(url: URL, title: String?, children: [InlineNode])
    case image(url: URL, alt: String?)
    case softBreak
    case lineBreak
    case autolink(URL)
    // Note: HTML, highlight/mark and footnotes are not supported by swift-cmark
}

public enum ListKind: Equatable, Sendable {
    case bullet
    case ordered(start: Int)
    case task
}

public struct ListItem: Equatable, Sendable {
    public var checked: Bool?
    public var children: [BlockNode]
    public init(checked: Bool? = nil, children: [BlockNode]) {
        self.checked = checked
        self.children = children
    }
}

public struct TableCell: Equatable, Sendable {
    public enum Alignment: Sendable { case left, center, right }
    public var alignment: Alignment
    public var inlines: [InlineNode]
    public init(alignment: Alignment = .left, inlines: [InlineNode]) {
        self.alignment = alignment
        self.inlines = inlines
    }
}

// Simple document wrapper for convenience
public struct MarkdownDocument: Sendable {
    public var blocks: [BlockNode]
    public init(blocks: [BlockNode]) { self.blocks = blocks }
}

