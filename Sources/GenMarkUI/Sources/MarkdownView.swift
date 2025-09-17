import SwiftUI
import UIKit
import GenMarkCore

public struct MarkdownView: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let customization: MarkdownCustomization
    private let parserOptions: ParserOptions
    private let extensions: Set<GFMExtension>
    // Test-only flag to compare cached vs. non-cached parsing
    internal let disableParsingCacheForTesting: Bool
    @State private var parsed: MarkdownDocument = MarkdownDocument(blocks: [])

    public init(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        customization: MarkdownCustomization = .none,
        parserOptions: ParserOptions = [.smart, .validateUTF8],
        extensions: Set<GFMExtension> = GFMExtension.all,
        disableParsingCacheForTesting: Bool = false
    ) {
        self.markdown = markdown
        self.theme = theme
        self.customization = customization
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
        customization: MarkdownCustomization = .none
    ) -> MarkdownView {
        return MarkdownView(
            markdown,
            theme: theme,
            customization: customization,
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
        ForEach(doc.blocks.indices, id: \.self) { i in
            BlockRenderer(node: doc.blocks[i], theme: theme, customization: customization)
                .padding(.bottom, theme.blockSpacing)
        }
        Spacer().frame(height: 1)
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
    let customization: MarkdownCustomization

    @ViewBuilder
    private func listMarker(for kind: ListKind, index: Int, checked: Bool?, theme: MarkdownTheme) -> some View {
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

    @ViewBuilder
    var body: some View {
        // Check for custom view first
        if let customView = customization.blockCustomizer(node, theme) {
            customView
        } else {
            // Default rendering
            defaultView
        }
    }
    
    @ViewBuilder
    private var defaultView: some View {
        switch node {
        case .paragraph(let inlines):
            if let image = standaloneImageInfo(from: inlines) {
                MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
            } else {
                let (textInlines, images) = splitTextAndImages(from: inlines)
                if images.isEmpty {
                    let factory = AttributedTextFactory(theme: theme, customization: customization)
                    let attr = factory.make(from: textInlines)
                    MarkdownTextView(attributedText: attr)
                } else {
                    VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                        if !textInlines.isEmpty {
                            let factory = AttributedTextFactory(theme: theme, customization: customization)
                            let attr = factory.make(from: textInlines)
                            MarkdownTextView(attributedText: attr)
                        }
                        ForEach(Array(images.enumerated()), id: \.0) { _, image in
                            MarkdownImageView(url: image.url, altText: image.alt, sizeHint: nil)
                        }
                    }
                }
            }
        case .heading(let level, let inlines):
            let factory = AttributedTextFactory(theme: theme, customization: customization)
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
        case .blockQuote(let children):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(children.indices, id: \.self) { i in
                    BlockRenderer(node: children[i], theme: theme, customization: customization)
                }
            }
            .padding(.leading, 8)
            .overlay(alignment: .leading) { Rectangle().fill(Color(theme.separatorColor)).frame(width: 2) }
        case .list(let kind, let items):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // Render the list marker
                        listMarker(for: kind, index: idx, checked: item.checked, theme: theme)
                            .frame(minWidth: 20, alignment: .trailing)
                        
                        // Render the item content
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(item.children.indices, id: \.self) { j in
                                BlockRenderer(node: item.children[j], theme: theme, customization: customization)
                            }
                        }
                    }
                }
            }
        case .codeBlock(_, let code):
            let attr = NSAttributedString(string: code, attributes: theme.codeBlockAttributes)
            MarkdownTextView(attributedText: attr)
                .padding(8)
                .background(Color(theme.secondaryBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .thematicBreak:
            Rectangle().fill(Color(theme.separatorColor)).frame(height: 1)
        case .table(let headers, let rows):
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: max(headers.count, 1))
            LazyVGrid(columns: columns, spacing: 0) {
                // Render headers with unique IDs
                ForEach(Array(headers.enumerated()), id: \.0) { index, cell in
                    CellRenderer(cell: cell, theme: theme, customization: customization, isHeader: true)
                        .id("header-\(index)")
                }
                // Render all row cells with unique IDs combining row and column indices
                ForEach(Array(rows.enumerated()), id: \.0) { rowIndex, row in
                    ForEach(Array(row.enumerated()), id: \.0) { colIndex, cell in
                        CellRenderer(cell: cell, theme: theme, customization: customization, isHeader: false)
                            .id("row-\(rowIndex)-col-\(colIndex)")
                    }
                }
            }
        case .document(let children):
            ForEach(children.indices, id: \.self) { i in
                BlockRenderer(node: children[i], theme: theme, customization: customization)
            }
        }
    }
}

public struct CellRenderer: View {
    let cell: TableCell
    let theme: MarkdownTheme
    let customization: MarkdownCustomization
    let isHeader: Bool
    
    public init(
        cell: TableCell,
        theme: MarkdownTheme,
        customization: MarkdownCustomization,
        isHeader: Bool
    ) {
        self.cell = cell
        self.theme = theme
        self.customization = customization
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
        let factory = AttributedTextFactory(theme: theme, customization: customization)
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
