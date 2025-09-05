import SwiftUI
import UIKit
import GenMarkCore
import GenMarkUIKit

public struct MarkdownView: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let style: MarkdownStyle
    private let overrides: MarkdownRenderOverrides
    private let parserOptions: ParserOptions
    private let extensions: Set<GFMExtension>

    public init(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        parserOptions: ParserOptions = [.smart, .validateUTF8],
        extensions: Set<GFMExtension> = GFMExtension.all,
        @MarkdownStyleBuilder style: () -> MarkdownStyle = { .default },
        @MarkdownRendererBuilder renderers: () -> MarkdownRenderOverrides = { .empty }
    ) {
        self.markdown = markdown
        self.theme = theme
        self.parserOptions = parserOptions
        self.extensions = extensions
        self.style = style()
        self.overrides = renderers()
    }
    
    // Convenience initializer for minimal CommonMark parsing
    public static func minimal(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        @MarkdownStyleBuilder style: () -> MarkdownStyle = { .default },
        @MarkdownRendererBuilder renderers: () -> MarkdownRenderOverrides = { .empty }
    ) -> MarkdownView {
        return MarkdownView(
            markdown,
            theme: theme,
            parserOptions: [],
            extensions: [],
            style: style,
            renderers: renderers
        )
    }

    public var body: some View {
        let parser = CMarkParser(options: parserOptions, extensions: extensions)
        let doc = parser.parse(markdown: markdown)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.blockSpacing) {
                ForEach(doc.blocks.indices, id: \.self) { i in
                    BlockRenderer(node: doc.blocks[i], theme: theme)
                }
            }
            .padding()
        }
    }
}

private struct BlockRenderer: View {
    let node: BlockNode
    let theme: MarkdownTheme
    
    @ViewBuilder
    private func listMarker(for kind: ListKind, index: Int, checked: Bool?, theme: MarkdownTheme) -> some View {
        switch kind {
        case .bullet:
            Text("•")
                .font(.system(size: theme.bodyFont.pointSize))
                .foregroundColor(Color(theme.foreground))
        case .ordered(let start):
            Text("\(start + index).")
                .font(.system(size: theme.bodyFont.pointSize))
                .foregroundColor(Color(theme.foreground))
        case .task:
            Image(systemName: checked == true ? "checkmark.square.fill" : "square")
                .foregroundColor(Color(checked == true ? theme.link : theme.foreground))
                .imageScale(.medium)
        }
    }

    var body: some View {
        switch node {
        case .paragraph(let inlines):
            let base = InlineTextStyle(font: theme.bodyFont, foreground: theme.foreground)
            let attr = AttributedTextFactory().make(from: inlines, base: base)
            OpenURLMarkdownTextView(attributedText: attr)
        case .heading(let level, let inlines):
            let font: UIFont = {
                switch level {
                case 1: return theme.h1
                case 2: return theme.h2
                case 3: return theme.h3
                case 4: return theme.h4
                case 5: return theme.h5
                default: return theme.h6
                }
            }()
            let base = InlineTextStyle(font: font, foreground: theme.foreground)
            let attr = AttributedTextFactory().make(from: inlines, base: base)
            OpenURLMarkdownTextView(attributedText: attr)
        case .blockQuote(let children):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(children.indices, id: \.self) { i in
                    BlockRenderer(node: children[i], theme: theme)
                }
            }
            .padding(.leading, 8)
            .overlay(alignment: .leading) { Rectangle().fill(Color(theme.separator)).frame(width: 2) }
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
                                BlockRenderer(node: item.children[j], theme: theme)
                            }
                        }
                    }
                }
            }
        case .codeBlock(_, let code):
            let attr = NSAttributedString(string: code, attributes: [
                .font: theme.codeBlockFont,
                .foregroundColor: theme.foreground
            ])
            OpenURLMarkdownTextView(attributedText: attr)
                .padding(8)
                .background(Color(theme.secondaryBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .thematicBreak:
            Rectangle().fill(Color(theme.separator)).frame(height: 1)
        case .table(let headers, let rows):
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: max(headers.count, 1))
            LazyVGrid(columns: columns, spacing: 0) {
                // Render headers with unique IDs
                ForEach(Array(headers.enumerated()), id: \.0) { index, cell in
                    CellRenderer(cell: cell, theme: theme)
                        .font(.headline)
                        .id("header-\(index)")
                }
                // Render all row cells with unique IDs combining row and column indices
                ForEach(Array(rows.enumerated()), id: \.0) { rowIndex, row in
                    ForEach(Array(row.enumerated()), id: \.0) { colIndex, cell in
                        CellRenderer(cell: cell, theme: theme)
                            .id("row-\(rowIndex)-col-\(colIndex)")
                    }
                }
            }
        case .document(let children):
            ForEach(children.indices, id: \.self) { i in
                BlockRenderer(node: children[i], theme: theme)
            }
        }
    }
}

private struct CellRenderer: View {
    let cell: TableCell
    let theme: MarkdownTheme
    var body: some View {
        let base = InlineTextStyle(font: theme.bodyFont, foreground: theme.foreground)
        let attr = AttributedTextFactory().make(from: cell.inlines, base: base)
        OpenURLMarkdownTextView(attributedText: attr)
            .frame(maxWidth: .infinity, alignment: cellAlignment)
            .border(.secondary)
    }
    
    private var cellAlignment: Alignment {
        switch cell.alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
