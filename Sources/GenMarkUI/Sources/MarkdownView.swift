import SwiftUI
import UIKit
import GenMarkCore

public struct MarkdownView: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let inlineCustomizer: MarkdownInlineCustomizer?
    private let blockCustomizer: MarkdownBlockCustomizer?
    private let parserOptions: ParserOptions
    private let extensions: Set<GFMExtension>
    // Test-only flag to compare cached vs. non-cached parsing
    internal let disableParsingCacheForTesting: Bool
    @State private var parsed: MarkdownDocument = MarkdownDocument(blocks: [])

    public init(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        inlineCustomizer: MarkdownInlineCustomizer? = nil,
        blockCustomizer: MarkdownBlockCustomizer? = nil,
        parserOptions: ParserOptions = [.smart, .validateUTF8],
        extensions: Set<GFMExtension> = GFMExtension.all,
        disableParsingCacheForTesting: Bool = false
    ) {
        self.markdown = markdown
        self.theme = theme
        self.inlineCustomizer = inlineCustomizer
        self.blockCustomizer = blockCustomizer
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
        inlineCustomizer: MarkdownInlineCustomizer? = nil,
        blockCustomizer: MarkdownBlockCustomizer? = nil
    ) -> MarkdownView {
        return MarkdownView(
            markdown,
            theme: theme,
            inlineCustomizer: inlineCustomizer,
            blockCustomizer: blockCustomizer,
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
        Color.clear.frame(height: theme.padding.top)
        ForEach(Array(doc.blocks.enumerated()), id: \.offset) { _, block in
            BlockRenderer(
                node: block,
                theme: theme,
                inlineCustomizer: inlineCustomizer,
                blockCustomizer: blockCustomizer
            )
                .padding(.bottom, theme.blockSpacing)
        }
        Color.clear.frame(height: theme.padding.bottom)
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
    let inlineCustomizer: MarkdownInlineCustomizer?
    let blockCustomizer: MarkdownBlockCustomizer?

    var body: some View {
        if let blockCustomizer, let customView = blockCustomizer(node, theme) {
            customView
        } else {
            BlockContentView(
                node: node,
                theme: theme,
                inlineCustomizer: inlineCustomizer,
                blockCustomizer: blockCustomizer
            )
            .padding(.leading, theme.padding.leading)
            .padding(.trailing, theme.padding.trailing)
        }
    }
}

private struct BlockContentView: View {
    let node: BlockNode
    let theme: MarkdownTheme
    let inlineCustomizer: MarkdownInlineCustomizer?
    let blockCustomizer: MarkdownBlockCustomizer?

    @ViewBuilder
    var body: some View {
        switch node {
        case .paragraph(let inlines):
            ParagraphBlockView(inlines: inlines, theme: theme, inlineCustomizer: inlineCustomizer)
        case .heading(let level, let inlines):
            HeadingBlockView(level: level, inlines: inlines, theme: theme, inlineCustomizer: inlineCustomizer)
        case .blockQuote(let children):
            BlockQuoteBlockView(
                children: children,
                theme: theme,
                inlineCustomizer: inlineCustomizer,
                blockCustomizer: blockCustomizer
            )
        case .list(let kind, let items):
            ListBlockView(
                kind: kind,
                items: items,
                theme: theme,
                inlineCustomizer: inlineCustomizer,
                blockCustomizer: blockCustomizer
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
                inlineCustomizer: inlineCustomizer
            )
        case .document(let children):
            DocumentBlockView(
                children: children,
                theme: theme,
                inlineCustomizer: inlineCustomizer,
                blockCustomizer: blockCustomizer
            )
        }
    }
}

private struct ParagraphBlockView: View {
    let inlines: [InlineNode]
    let theme: MarkdownTheme
    let inlineCustomizer: MarkdownInlineCustomizer?

    @ViewBuilder
    var body: some View {
        if let image = standaloneImageInfo(from: inlines) {
            MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
        } else {
            let (textInlines, images) = splitTextAndImages(from: inlines)
            if images.isEmpty {
                let factory = AttributedTextFactory(theme: theme, inlineCustomizer: inlineCustomizer)
                let attr = factory.make(from: textInlines)
                MarkdownTextView(attributedText: attr)
            } else {
                VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                    if !textInlines.isEmpty {
                        let factory = AttributedTextFactory(theme: theme, inlineCustomizer: inlineCustomizer)
                        let attr = factory.make(from: textInlines)
                        MarkdownTextView(attributedText: attr)
                    }
                    ForEach(Array(images.enumerated()), id: \.0) { _, image in
                        MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                    }
                }
            }
        }
    }
}

private struct HeadingBlockView: View {
    let level: Int
    let inlines: [InlineNode]
    let theme: MarkdownTheme
    let inlineCustomizer: MarkdownInlineCustomizer?

    @ViewBuilder
    var body: some View {
        let factory = AttributedTextFactory(theme: theme, inlineCustomizer: inlineCustomizer)
        let headingAttrs = theme.headingAttributes(for: level)
        let (textInlines, images) = splitTextAndImages(from: inlines)

        if images.isEmpty {
            let attr = factory.make(from: textInlines, baseAttributes: headingAttrs)
            MarkdownTextView(attributedText: attr)
        } else {
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                if !textInlines.isEmpty {
                    let attr = factory.make(from: textInlines, baseAttributes: headingAttrs)
                    MarkdownTextView(attributedText: attr)
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
    let inlineCustomizer: MarkdownInlineCustomizer?
    let blockCustomizer: MarkdownBlockCustomizer?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                BlockRenderer(
                    node: child,
                    theme: theme,
                    inlineCustomizer: inlineCustomizer,
                    blockCustomizer: blockCustomizer
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
    let inlineCustomizer: MarkdownInlineCustomizer?
    let blockCustomizer: MarkdownBlockCustomizer?

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ListMarkerView(kind: kind, index: index, checked: item.checked, theme: theme)
                    .frame(width: 20, alignment: .trailing)
                BlockRenderer(
                    node: item.children[0],
                    theme: theme,
                    inlineCustomizer: inlineCustomizer,
                    blockCustomizer: blockCustomizer
                )
            }
            ForEach(Array(item.children[1...].enumerated()), id: \.offset) { _, child in
                BlockRenderer(
                    node: child,
                    theme: theme,
                    inlineCustomizer: inlineCustomizer,
                    blockCustomizer: blockCustomizer
                )
                .padding(.leading, 20)
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
    let code: String
    let theme: MarkdownTheme

    var body: some View {
        let attr = NSAttributedString(string: code, attributes: theme.codeBlockAttributes)
        return MarkdownTextView(attributedText: attr)
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
    let inlineCustomizer: MarkdownInlineCustomizer?

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: max(headers.count, 1))
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.0) { index, cell in
                CellRenderer(
                    cell: cell,
                    theme: theme,
                    inlineCustomizer: inlineCustomizer,
                    isHeader: true
                )
                .id("header-\(index)")
            }
            ForEach(Array(rows.enumerated()), id: \.0) { rowIndex, row in
                ForEach(Array(row.enumerated()), id: \.0) { colIndex, cell in
                    CellRenderer(
                        cell: cell,
                        theme: theme,
                        inlineCustomizer: inlineCustomizer,
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
    let inlineCustomizer: MarkdownInlineCustomizer?
    let blockCustomizer: MarkdownBlockCustomizer?

    var body: some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
            BlockRenderer(
                node: child,
                theme: theme,
                inlineCustomizer: inlineCustomizer,
                blockCustomizer: blockCustomizer
            )
        }
    }
}

public struct CellRenderer: View {
    let cell: TableCell
    let theme: MarkdownTheme
    let inlineCustomizer: MarkdownInlineCustomizer?
    let isHeader: Bool
    
    public init(
        cell: TableCell,
        theme: MarkdownTheme,
        inlineCustomizer: MarkdownInlineCustomizer?,
        isHeader: Bool
    ) {
        self.cell = cell
        self.theme = theme
        self.inlineCustomizer = inlineCustomizer
        self.isHeader = isHeader
    }
    
    public var body: some View {
        Group {
            if let image = standaloneImageInfo(from: cell.inlines) {
                MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let (textInlines, images) = splitTextAndImages(from: cell.inlines)
                if images.isEmpty {
                    renderText(for: textInlines, isHeader: isHeader)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                        if !textInlines.isEmpty {
                            renderText(for: textInlines, isHeader: isHeader)
                        }
                        ForEach(Array(images.enumerated()), id: \.0) { _, image in
                            MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .border(.secondary)
    }
    
    @ViewBuilder
    private func renderText(for inlines: [InlineNode], isHeader: Bool) -> some View {
        let factory = AttributedTextFactory(theme: theme, inlineCustomizer: inlineCustomizer)
        if isHeader {
            let baseFont = theme.textAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            let boldFont = boldFont(from: baseFont)
            let attr = factory.make(from: inlines, baseFont: boldFont)
            let mutable: NSAttributedString = {
                let mutable = NSMutableAttributedString(attributedString: attr)
                mutable.addAttribute(
                    NSAttributedString.Key.paragraphStyle,
                    value: {
                        let mutableParagraphStyle = NSMutableParagraphStyle()
                        mutableParagraphStyle.alignment = cellAlignment
                        return mutableParagraphStyle
                    }(),
                    range: .init(location: 0, length: attr.length)
                )
                return mutable
            }()
            MarkdownTextView(attributedText: mutable)
        } else {
            let attr = factory.make(from: inlines)
            MarkdownTextView(attributedText: attr)
        }
    }

    /// Creates a bold version of the given font
    private func boldFont(from font: UIFont) -> UIFont {
        let existingTraits = font.fontDescriptor.symbolicTraits
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(existingTraits.union(.traitBold)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    
    private var cellAlignment: NSTextAlignment {
        switch cell.alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}
