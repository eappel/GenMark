import SwiftUI
import UIKit
import GenMarkCore
import GenMarkUIKit

public struct MarkdownView: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let style: MarkdownStyle
    private let overrides: MarkdownRenderOverrides

    public init(
        _ markdown: String,
        theme: MarkdownTheme = .systemDefault,
        @MarkdownStyleBuilder style: () -> MarkdownStyle = { .default },
        @MarkdownRendererBuilder renderers: () -> MarkdownRenderOverrides = { .empty }
    ) {
        self.markdown = markdown
        self.theme = theme
        self.style = style()
        self.overrides = renderers()
    }

    public var body: some View {
        let doc = CMarkParser().parse(markdown: markdown)
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
        case .list(_, let items):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.children.indices, id: \.self) { j in
                            BlockRenderer(node: item.children[j], theme: theme)
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
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: max(headers.count, 1))
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(headers.indices, id: \.self) { i in
                    CellRenderer(cell: headers[i], theme: theme).font(.headline)
                }
                ForEach(rows.indices, id: \.self) { ri in
                    let row = rows[ri]
                    ForEach(row.indices, id: \.self) { ci in
                        CellRenderer(cell: row[ci], theme: theme)
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
    }
}
