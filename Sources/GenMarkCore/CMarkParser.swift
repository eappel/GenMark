import Foundation

public protocol MarkdownParsing: Sendable {
    func parse(markdown: String) -> MarkdownDocument
}

public struct CMarkParser: MarkdownParsing, Sendable {
    public init() {}

    public func parse(markdown: String) -> MarkdownDocument {
        #if canImport(cmark_gfm)
        return CMarkBridge().parse(markdown: markdown)
        #else
        // Fallback: return a trivial paragraph so previews/tests can compile without cmark
        let placeholder: [BlockNode] = [
            .paragraph(inlines: [.text(markdown)])
        ]
        return MarkdownDocument(blocks: placeholder)
        #endif
    }
}

#if canImport(cmark_gfm)
@_implementationOnly import cmark_gfm
@_implementationOnly import cmark_gfm_extensions

private typealias UnsafeNode = UnsafeMutablePointer<cmark_node>

private struct CMarkBridge {
    func parse(markdown: String) -> MarkdownDocument {
        // Register core GFM extensions and attach them to the parser
        cmark_gfm_core_extensions_ensure_registered()
        let options = CMARK_OPT_DEFAULT
        guard let parser = cmark_parser_new(options) else {
            return MarkdownDocument(blocks: [.paragraph(inlines: [.text(markdown)])])
        }
        defer { cmark_parser_free(parser) }

        // Attach commonly-used GitHub extensions
        let extensionNames: [String]
        if #available(iOS 18.0, *) {
            extensionNames = ["autolink", "strikethrough", "tagfilter", "tasklist", "table"]
        } else {
            extensionNames = ["autolink", "strikethrough", "tagfilter", "tasklist"]
        }
        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        // Feed UTF-8 bytes
        let byteCount = markdown.lengthOfBytes(using: .utf8)
        markdown.withCString { cstr in
            cmark_parser_feed(parser, cstr, byteCount)
        }

        guard let root = cmark_parser_finish(parser) else {
            return MarkdownDocument(blocks: [])
        }
        defer { cmark_node_free(root) }

        var blocks: [BlockNode] = []
        var child: UnsafeNode? = cmark_node_first_child(root)
        while let node = child {
            if let block = mapBlock(node) { blocks.append(block) }
            child = cmark_node_next(node)
        }
        return MarkdownDocument(blocks: blocks)
    }

    private func mapBlock(_ node: UnsafeNode?) -> BlockNode? {
        guard let node else { return nil }
        switch cmark_node_get_type(node) {
        case CMARK_NODE_PARAGRAPH:
            return .paragraph(inlines: collectInlines(from: node))
        case CMARK_NODE_HEADING:
            let level = Int(cmark_node_get_heading_level(node))
            return .heading(level: level, inlines: collectInlines(from: node))
        case CMARK_NODE_BLOCK_QUOTE:
            var children: [BlockNode] = []
            var c: UnsafeNode? = cmark_node_first_child(node)
            while let n = c {
                if let mapped = mapBlock(n) { children.append(mapped) }
                c = cmark_node_next(n)
            }
            return .blockQuote(children: children)
        case CMARK_NODE_CODE_BLOCK:
            let literal = stringOrEmpty(cmark_node_get_literal(node))
            let lang = stringOrNil(cmark_node_get_fence_info(node))
            return .codeBlock(language: lang, code: literal)
        case CMARK_NODE_THEMATIC_BREAK:
            return .thematicBreak
        case CMARK_NODE_LIST:
            var items: [ListItem] = []
            var it: UnsafeNode? = cmark_node_first_child(node)
            while let itemNode = it {
                if let listItem = mapListItem(itemNode) { items.append(listItem) }
                it = cmark_node_next(itemNode)
            }
            // Determine list kind; if any item is a task, model as task list
            let hasTask = items.contains(where: { $0.checked != nil })
            let kind: ListKind
            switch cmark_node_get_list_type(node) {
            case CMARK_BULLET_LIST:
                kind = hasTask ? .task : .bullet
            case CMARK_ORDERED_LIST:
                let start = Int(cmark_node_get_list_start(node))
                kind = hasTask ? .task : .ordered(start: max(1, start))
            default:
                kind = hasTask ? .task : .bullet
            }
            return .list(kind: kind, items: items)
        default:
            // Handle GFM tables by type string
            let typeStr = nodeTypeString(node)
            if typeStr == "table" {
                return mapTable(node)
            }
            // Fallback: render literal if any
            if let lit = stringOrNil(cmark_node_get_literal(node)), !lit.isEmpty {
                return .paragraph(inlines: [.text(lit)])
            }
            // Or collect children paragraphs
            var children: [BlockNode] = []
            var c: UnsafeNode? = cmark_node_first_child(node)
            while let n = c {
                if let mapped = mapBlock(n) { children.append(mapped) }
                c = cmark_node_next(n)
            }
            if !children.isEmpty { return .document(children: children) }
            return nil
        }
    }

    private func mapListItem(_ node: UnsafeNode) -> ListItem? {
        guard cmark_node_get_type(node) == CMARK_NODE_ITEM else { return nil }
        var children: [BlockNode] = []
        var c: UnsafeNode? = cmark_node_first_child(node)
        while let n = c {
            if let mapped = mapBlock(n) { children.append(mapped) }
            c = cmark_node_next(n)
        }
        // On GFM branches, the API returns `bool`. Non-task items won't have the
        // "tasklist" type string set; use that to disambiguate nil vs false.
        let isTaskItem = (nodeTypeString(node) == "tasklist")
        let checked: Bool? = isTaskItem ? cmark_gfm_extensions_get_tasklist_item_checked(node) : nil
        return ListItem(checked: checked, children: children)
    }

    private func collectInlines(from node: UnsafeNode) -> [InlineNode] {
        var result: [InlineNode] = []
        var child: UnsafeNode? = cmark_node_first_child(node)
        while let n = child {
            if let inline = mapInline(n) { result.append(inline) }
            child = cmark_node_next(n)
        }
        return result
    }

    private func mapInline(_ node: UnsafeNode) -> InlineNode? {
        switch cmark_node_get_type(node) {
        case CMARK_NODE_TEXT:
            return .text(stringOrEmpty(cmark_node_get_literal(node)))
        case CMARK_NODE_EMPH:
            return .emphasis(collectInlines(from: node))
        case CMARK_NODE_STRONG:
            return .strong(collectInlines(from: node))
        case CMARK_NODE_SOFTBREAK:
            return .softBreak
        case CMARK_NODE_LINEBREAK:
            return .lineBreak
        case CMARK_NODE_CODE:
            return .code(stringOrEmpty(cmark_node_get_literal(node)))
        case CMARK_NODE_LINK:
            let urlString = stringOrNil(cmark_node_get_url(node)) ?? ""
            let title = stringOrNil(cmark_node_get_title(node))
            if let url = URL(string: urlString) {
                return .link(url: url, title: title, children: collectInlines(from: node))
            } else {
                return .text(urlString)
            }
        case CMARK_NODE_IMAGE:
            let urlString = stringOrNil(cmark_node_get_url(node)) ?? ""
            let alt: String? = {
                // Alt text is represented by child inlines; join literals for now
                let parts = collectInlines(from: node)
                if parts.isEmpty { return nil }
                return parts.compactMap { if case let .text(s) = $0 { return s } else { return nil } }.joined()
            }()
            if let url = URL(string: urlString) {
                return .image(url: url, alt: alt)
            } else {
                return .text(alt ?? urlString)
            }
        default:
            // Strikethrough from GFM may not have a dedicated enum; check type string
            if nodeTypeString(node) == "strikethrough" {
                return .strikethrough(collectInlines(from: node))
            }
            if let lit = stringOrNil(cmark_node_get_literal(node)) { return .text(lit) }
            return nil
        }
    }

    private func mapTable(_ node: UnsafeNode) -> BlockNode? {
        var headers: [TableCell] = []
        var rows: [[TableCell]] = []

        var section: UnsafeNode? = cmark_node_first_child(node)
        while let sec = section {
            let type = nodeTypeString(sec)
            if type == "table_header" || type == "table_row" {
                var rowCells: [TableCell] = []
                var cell: UnsafeNode? = cmark_node_first_child(sec)
                while let cn = cell {
                    if let cellModel = mapTableCell(cn) { rowCells.append(cellModel) }
                    cell = cmark_node_next(cn)
                }
                if type == "table_header" && headers.isEmpty {
                    headers = rowCells
                } else if type == "table_row" {
                    rows.append(rowCells)
                } else if headers.isEmpty {
                    // Fallback: if there is no explicit header node, use the first row as header
                    headers = rowCells
                } else {
                    rows.append(rowCells)
                }
            }
            section = cmark_node_next(sec)
        }
        return .table(headers: headers, rows: rows)
    }

    private func mapTableCell(_ node: UnsafeNode) -> TableCell? {
        guard nodeTypeString(node) == "table_cell" else { return nil }
        // Determine the index of this cell within its row
        let row = cmark_node_parent(node)
        var index = 0
        var walker: UnsafeNode? = cmark_node_first_child(row)
        while let w = walker, w != node {
            if nodeTypeString(w) == "table_cell" { index += 1 }
            walker = cmark_node_next(w)
        }

        // The table node is the parent of the row
        let table = cmark_node_parent(row)
        var alignment: TableCell.Alignment = .left
        let columnCount = Int(cmark_gfm_extensions_get_table_columns(table))
        if columnCount > 0, let ptr = cmark_gfm_extensions_get_table_alignments(table), index < columnCount {
            let ascii = ptr[index]
            switch Character(UnicodeScalar(UInt8(ascii))) {
            case "c": alignment = .center
            case "r": alignment = .right
            default: alignment = .left
            }
        }
        let inlines = collectInlines(from: node)
        return TableCell(alignment: alignment, inlines: inlines)
    }

    private func nodeTypeString(_ node: UnsafeNode) -> String {
        String(cString: cmark_node_get_type_string(node))
    }

    private func stringOrEmpty(_ cstr: UnsafePointer<CChar>!) -> String {
        guard let cstr else { return "" }
        return String(cString: cstr)
    }

    private func stringOrNil(_ cstr: UnsafePointer<CChar>!) -> String? {
        guard let cstr else { return nil }
        let s = String(cString: cstr)
        return s.isEmpty ? nil : s
    }
}
#endif
