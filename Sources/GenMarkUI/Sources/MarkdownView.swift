import SwiftUI
import UIKit
import GenMarkCore

public struct MarkdownView: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    private let inlineRenderer: MarkdownInlineRenderer?
    private let blockRenderer: MarkdownBlockRenderer?
    private let parserOptions: ParserOptions
    private let extensions: Set<GFMExtension>
    // Test-only flag to compare cached vs. non-cached parsing
    internal let disableParsingCacheForTesting: Bool
    @State private var parsed: MarkdownDocument = MarkdownDocument(blocks: [])

    public init(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster? = nil,
        inlineRenderer: MarkdownInlineRenderer? = nil,
        blockRenderer: MarkdownBlockRenderer? = nil,
        parserOptions: ParserOptions = [.smart, .validateUTF8],
        extensions: Set<GFMExtension> = GFMExtension.all,
        disableParsingCacheForTesting: Bool = false
    ) {
        self.markdown = markdown
        self.theme = theme
        self.inlineAttributeAdjuster = inlineAttributeAdjuster
        self.inlineRenderer = inlineRenderer
        self.blockRenderer = blockRenderer
        self.parserOptions = parserOptions
        self.extensions = extensions
        self.disableParsingCacheForTesting = disableParsingCacheForTesting
        // Eagerly parse once for initial state
        _parsed = State(initialValue: CMarkParser(options: parserOptions, extensions: extensions).parse(markdown: markdown))
    }
    
    // Convenience initializer for minimal CommonMark parsing
    public static func minimal(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster? = nil,
        inlineRenderer: MarkdownInlineRenderer? = nil,
        blockRenderer: MarkdownBlockRenderer? = nil
    ) -> MarkdownView {
        return MarkdownView(
            markdown,
            theme: theme,
            inlineAttributeAdjuster: inlineAttributeAdjuster,
            inlineRenderer: inlineRenderer,
            blockRenderer: blockRenderer,
            parserOptions: [],
            extensions: []
        )
    }

    public var body: some View {
        // Use cached parse unless testing requests to disable
        let doc: MarkdownDocument = {
            if disableParsingCacheForTesting {
                let parser = CMarkParser(options: parserOptions, extensions: extensions)
                return parser.parse(markdown: markdown)
            } else {
                return parsed
            }
        }()
        ForEach(Array(doc.blocks.enumerated()), id: \.offset) { offset, block in
            BlockRenderer(
                node: block,
                theme: theme,
                applyPadding: true,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer,
                blockRenderer: blockRenderer
            )
            .padding(.bottom, offset < (doc.blocks.count - 1) ? theme.blockSpacing : 0)
        }
        Color.clear.frame(height: 0)
            .onChange(of: markdown) { _, newValue in
                let parser = CMarkParser(options: parserOptions, extensions: extensions)
                parsed = parser.parse(markdown: newValue)
            }
    }
}

private func standaloneImageInfo(from inlines: [InlineNode]) -> (url: URL, alt: String?)? {
    let filtered = inlines.filter { inline -> Bool in
        switch inline {
        case .softBreak, .lineBreak:
            return false
        default:
            return true
        }
    }
    guard filtered.count == 1 else { return nil }
    if case let .image(url, alt) = filtered[0] {
        return (url, alt)
    }
    return nil
}

private func splitTextAndImages(from inlines: [InlineNode]) -> (text: [InlineNode], images: [(url: URL, alt: String?)]) {
    var text: [InlineNode] = []
    var images: [(URL, String?)] = []

    for inline in inlines {
        switch inline {
        case .image(let url, let alt):
            images.append((url, alt))
        default:
            text.append(inline)
        }
    }
    return (text, images)
}

private struct BlockRenderer: View {
    let node: BlockNode
    let theme: MarkdownTheme
    let applyPadding: Bool
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?
    let blockRenderer: MarkdownBlockRenderer?

    var body: some View {
        if let blockRenderer, let customView = blockRenderer(node, theme) {
            customView
        } else {
            BlockContentView(
                node: node,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer,
                blockRenderer: blockRenderer
            )
            .padding(.leading, applyPadding ? theme.leadingPadding : 0)
            .padding(.trailing, applyPadding ? theme.trailingPadding : 0)
        }
    }
}

private struct BlockContentView: View {
    let node: BlockNode
    let theme: MarkdownTheme
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?
    let blockRenderer: MarkdownBlockRenderer?

    @ViewBuilder
    var body: some View {
        switch node {
        case .paragraph(let inlines):
            ParagraphBlockView(
                inlines: inlines,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer
            )
        case .heading(let level, let inlines):
            HeadingBlockView(
                level: level,
                inlines: inlines,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer
            )
        case .blockQuote(let children):
            BlockQuoteBlockView(
                children: children,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer,
                blockRenderer: blockRenderer
            )
        case .list(let kind, let items):
            ListBlockView(
                kind: kind,
                items: items,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer,
                blockRenderer: blockRenderer
            )
        case .codeBlock(_, let code):
            CodeBlockView(code: code, theme: theme)
        case .thematicBreak:
            ThematicBreakView(theme: theme)
        case .table(let headers, let rows):
            TableBlockView(
                headers: headers,
                rows: rows,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer
            )
        case .document(let children):
            DocumentBlockView(
                children: children,
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer,
                blockRenderer: blockRenderer
            )
        }
    }
}

private struct ParagraphBlockView: View {
    private enum Content {
        case imageOnly(URL, String?)
        case textOnly(NSAttributedString)
        case textWithImages(text: NSAttributedString?, images: [(url: URL, alt: String?)])
    }

    private let content: Content
    private let theme: MarkdownTheme

    init(
        inlines: [InlineNode],
        theme: MarkdownTheme,
        inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?,
        inlineRenderer: MarkdownInlineRenderer?
    ) {
        self.theme = theme
        if let image = standaloneImageInfo(from: inlines) {
            self.content = .imageOnly(image.url, image.alt)
        } else {
            let (textInlines, images) = splitTextAndImages(from: inlines)
            let factory = AttributedTextFactory(
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer
            )
            if images.isEmpty {
                self.content = .textOnly(factory.make(from: textInlines))
            } else {
                let text = textInlines.isEmpty ? nil : factory.make(from: textInlines)
                self.content = .textWithImages(text: text, images: images)
            }
        }
    }

    @ViewBuilder
    var body: some View {
        switch content {
        case .imageOnly(let url, let alt):
            MarkdownImageView(url: url, altText: alt, sizeHint: nil)
        case .textOnly(let text):
            MarkdownTextView(attributedText: text)
        case .textWithImages(let text, let images):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                if let text {
                    MarkdownTextView(attributedText: text)
                }
                ForEach(Array(images.enumerated()), id: \.0) { _, image in
                    MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                }
            }
        }
    }
}

private struct HeadingBlockView: View {
    private enum Content {
        case textOnly(NSAttributedString)
        case textWithImages(text: NSAttributedString?, images: [(url: URL, alt: String?)])
    }

    private let content: Content
    private let theme: MarkdownTheme

    init(
        level: Int,
        inlines: [InlineNode],
        theme: MarkdownTheme,
        inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?,
        inlineRenderer: MarkdownInlineRenderer?
    ) {
        self.theme = theme
        let factory = AttributedTextFactory(
            theme: theme,
            inlineAttributeAdjuster: inlineAttributeAdjuster,
            inlineRenderer: inlineRenderer
        )
        let headingAttrs = theme.headingAttributes(for: level)
        let (textInlines, images) = splitTextAndImages(from: inlines)

        if images.isEmpty {
            self.content = .textOnly(factory.make(from: textInlines, baseAttributes: headingAttrs))
        } else {
            let text = textInlines.isEmpty ? nil : factory.make(from: textInlines, baseAttributes: headingAttrs)
            self.content = .textWithImages(text: text, images: images)
        }
    }

    @ViewBuilder
    var body: some View {
        switch content {
        case .textOnly(let text):
            MarkdownTextView(attributedText: text)
        case .textWithImages(let text, let images):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                if let text {
                    MarkdownTextView(attributedText: text)
                }
                ForEach(Array(images.enumerated()), id: \.0) { _, image in
                    MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                }
            }
        }
    }
}

private struct BlockQuoteBlockView: View {
    let children: [BlockNode]
    let theme: MarkdownTheme
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?
    let blockRenderer: MarkdownBlockRenderer?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                BlockRenderer(
                    node: child,
                    theme: theme,
                    applyPadding: false,
                    inlineAttributeAdjuster: inlineAttributeAdjuster,
                    inlineRenderer: inlineRenderer,
                    blockRenderer: blockRenderer
                )
            }
        }
        .padding(.leading, 8)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(theme.separatorColor))
                .frame(width: 2)
        }
    }
}

private struct ListBlockView: View {
    let kind: ListKind
    let items: [ListItem]
    let theme: MarkdownTheme
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?
    let blockRenderer: MarkdownBlockRenderer?

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            if !item.children.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ListMarkerView(kind: kind, index: index, checked: item.checked, theme: theme)
                        .frame(width: 20, alignment: .trailing)
                    BlockRenderer(
                        node: item.children[0],
                        theme: theme,
                        applyPadding: false,
                        inlineAttributeAdjuster: inlineAttributeAdjuster,
                        inlineRenderer: inlineRenderer,
                        blockRenderer: blockRenderer
                    )
                }
                ForEach(Array(item.children[1...].enumerated()), id: \.offset) { _, child in
                    BlockRenderer(
                        node: child,
                        theme: theme,
                        applyPadding: false,
                        inlineAttributeAdjuster: inlineAttributeAdjuster,
                        inlineRenderer: inlineRenderer,
                        blockRenderer: blockRenderer
                    )
                    .padding(.leading, 20)
                }
            }
        }
    }
}

private struct ListMarkerView: View {
    let kind: ListKind
    let index: Int
    let checked: Bool?
    let theme: MarkdownTheme

    @ViewBuilder
    var body: some View {
        let textFont = theme.textAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
        let textColor = theme.textAttributes[.foregroundColor] as? UIColor ?? UIColor.label
        let linkColor = theme.linkAttributes[.foregroundColor] as? UIColor ?? UIColor.link

        switch kind {
        case .bullet:
            Text("•")
                .font(.system(size: textFont.pointSize))
                .foregroundColor(Color(textColor))
        case .ordered(let start):
            Text("\(start + index).")
                .font(.system(size: textFont.pointSize))
                .foregroundColor(Color(textColor))
        case .task:
            Image(systemName: checked == true ? "checkmark.square.fill" : "square")
                .foregroundColor(Color(checked == true ? linkColor : textColor))
                .imageScale(.medium)
        }
    }
}

private struct CodeBlockView: View {
    private let attributed: NSAttributedString
    private let theme: MarkdownTheme

    init(code: String, theme: MarkdownTheme) {
        self.theme = theme
        self.attributed = NSAttributedString(string: code, attributes: theme.codeBlockAttributes)
    }

    var body: some View {
        MarkdownTextView(attributedText: attributed)
            .padding(8)
            .background(Color(theme.secondaryBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ThematicBreakView: View {
    let theme: MarkdownTheme

    var body: some View {
        Rectangle()
            .fill(Color(theme.separatorColor))
            .frame(height: 1)
    }
}

private struct TableBlockView: View {
    let headers: [TableCell]
    let rows: [[TableCell]]
    let theme: MarkdownTheme
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: max(headers.count, 1))
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.0) { index, cell in
                CellRenderer(
                    cell: cell,
                    theme: theme,
                    inlineAttributeAdjuster: inlineAttributeAdjuster,
                    inlineRenderer: inlineRenderer,
                    isHeader: true
                )
                .id("header-\(index)")
            }
            ForEach(Array(rows.enumerated()), id: \.0) { rowIndex, row in
                ForEach(Array(row.enumerated()), id: \.0) { colIndex, cell in
                    CellRenderer(
                        cell: cell,
                        theme: theme,
                        inlineAttributeAdjuster: inlineAttributeAdjuster,
                        inlineRenderer: inlineRenderer,
                        isHeader: false
                    )
                    .id("row-\(rowIndex)-col-\(colIndex)")
                }
            }
        }
    }
}

private struct DocumentBlockView: View {
    let children: [BlockNode]
    let theme: MarkdownTheme
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?
    let blockRenderer: MarkdownBlockRenderer?

    var body: some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
            BlockRenderer(
                node: child,
                theme: theme,
                applyPadding: false,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer,
                blockRenderer: blockRenderer
            )
        }
    }
}

public struct CellRenderer: View {
    private enum Content {
        case imageOnly(URL, String?)
        case textOnly(NSAttributedString)
        case textWithImages(text: NSAttributedString?, images: [(url: URL, alt: String?)])
    }

    private let content: Content
    private let theme: MarkdownTheme
    private let alignment: NSTextAlignment

    public init(
        cell: TableCell,
        theme: MarkdownTheme,
        inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?,
        inlineRenderer: MarkdownInlineRenderer? = nil,
        isHeader: Bool
    ) {
        self.theme = theme
        self.alignment = {
            switch cell.alignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }()

        if let image = standaloneImageInfo(from: cell.inlines) {
            self.content = .imageOnly(image.url, image.alt)
        } else {
            let factory = AttributedTextFactory(
                theme: theme,
                inlineAttributeAdjuster: inlineAttributeAdjuster,
                inlineRenderer: inlineRenderer
            )
            let (textInlines, images) = splitTextAndImages(from: cell.inlines)
            if images.isEmpty {
                let text = Self.makeText(
                    from: textInlines,
                    factory: factory,
                    theme: theme,
                    alignment: alignment,
                    isHeader: isHeader
                )
                self.content = .textOnly(text)
            } else {
                let text = textInlines.isEmpty ? nil : Self.makeText(
                    from: textInlines,
                    factory: factory,
                    theme: theme,
                    alignment: alignment,
                    isHeader: isHeader
                )
                self.content = .textWithImages(text: text, images: images)
            }
        }
    }
    
    public var body: some View {
        Group {
            switch content {
            case .imageOnly(let url, let alt):
                MarkdownImageView(url: url, altText: alt, sizeHint: nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .textOnly(let text):
                MarkdownTextView(attributedText: text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .textWithImages(let text, let images):
                VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                    if let text {
                        MarkdownTextView(attributedText: text)
                    }
                    ForEach(Array(images.enumerated()), id: \.0) { _, image in
                        MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .border(.secondary)
    }

    private static func makeText(
        from inlines: [InlineNode],
        factory: AttributedTextFactory,
        theme: MarkdownTheme,
        alignment: NSTextAlignment,
        isHeader: Bool
    ) -> NSAttributedString {
        if isHeader {
            let baseFont = theme.textAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            let boldFont = boldFont(from: baseFont)
            let attr = factory.make(from: inlines, baseFont: boldFont)
            let mutable = NSMutableAttributedString(attributedString: attr)
            let style = NSMutableParagraphStyle()
            style.alignment = alignment
            mutable.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attr.length))
            return mutable
        } else {
            return factory.make(from: inlines)
        }
    }

    private static func boldFont(from font: UIFont) -> UIFont {
        let existingTraits = font.fontDescriptor.symbolicTraits
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(existingTraits.union(.traitBold)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
