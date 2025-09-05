import SwiftUI
import UIKit
import GenMarkCore
import GenMarkUIKit

public struct MarkdownView: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let customization: MarkdownCustomization
    private let parserOptions: ParserOptions
    private let extensions: Set<GFMExtension>

    public init(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        customization: MarkdownCustomization = .none,
        parserOptions: ParserOptions = [.smart, .validateUTF8],
        extensions: Set<GFMExtension> = GFMExtension.all
    ) {
        self.markdown = markdown
        self.theme = theme
        self.customization = customization
        self.parserOptions = parserOptions
        self.extensions = extensions
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
        let parser = CMarkParser(options: parserOptions, extensions: extensions)
        let doc = parser.parse(markdown: markdown)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.blockSpacing) {
                ForEach(doc.blocks.indices, id: \.self) { i in
                    BlockRenderer(node: doc.blocks[i], theme: theme, customization: customization)
                }
            }
            .padding()
        }
    }
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
            let factory = AttributedTextFactory(theme: theme, customization: customization)
            let attr = factory.make(from: inlines)
            OpenURLMarkdownTextView(attributedText: attr)
        case .heading(let level, let inlines):
            let factory = AttributedTextFactory(theme: theme, customization: customization)
            let headingAttrs = theme.headingAttributes(for: level)
            let attr = factory.make(from: inlines, baseAttributes: headingAttrs)
            OpenURLMarkdownTextView(attributedText: attr)
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
            OpenURLMarkdownTextView(attributedText: attr)
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


private struct CellRenderer: View {
    let cell: TableCell
    let theme: MarkdownTheme
    let customization: MarkdownCustomization
    let isHeader: Bool
    
    var body: some View {
        let factory = AttributedTextFactory(theme: theme, customization: customization)
        if isHeader {
            // For headers, create bold font and use it
            let baseFont = theme.textAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            let boldFont = boldFont(from: baseFont)
            let attr = factory.make(from: cell.inlines, baseFont: boldFont)
            OpenURLMarkdownTextView(attributedText: attr)
                .frame(maxWidth: .infinity, alignment: cellAlignment)
                .border(.secondary)
        } else {
            // For regular cells, use default text attributes
            let attr = factory.make(from: cell.inlines)
            OpenURLMarkdownTextView(attributedText: attr)
                .frame(maxWidth: .infinity, alignment: cellAlignment)
                .border(.secondary)
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
    
    private var cellAlignment: Alignment {
        switch cell.alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
