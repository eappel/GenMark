import Foundation

public protocol MarkdownParsing: Sendable {
    func parse(markdown: String) -> MarkdownDocument
}

/// GitHub Flavored Markdown extensions that can be enabled
/// These are the extensions available in swift-cmark (release/5.7-gfm)
public enum GFMExtension: String, CaseIterable, Sendable {
    /// Automatically detect and link URLs and email addresses
    case autolink = "autolink"
    
    /// Support for ~~strikethrough~~ syntax
    case strikethrough = "strikethrough"
    
    /// Filter potentially dangerous HTML tags
    case tagfilter = "tagfilter"
    
    /// Support for task list items with checkboxes
    case tasklist = "tasklist"
    
    /// Support for pipe tables
    case table = "table"
    
    /// All available GFM extensions in swift-cmark
    public static var all: Set<GFMExtension> {
        Set(GFMExtension.allCases)
    }
    
    /// Standard GFM extensions (same as all, since all are standard)
    public static var standard: Set<GFMExtension> {
        Set(GFMExtension.allCases)
    }
}

/// Options for configuring the cmark-gfm parser behavior
public struct ParserOptions: OptionSet, Sendable {
    public let rawValue: CInt
    
    public init(rawValue: CInt) {
        self.rawValue = rawValue
    }
    
    /// Default options (no special behavior)
    public static let `default` = ParserOptions([])
    
    /// Include source position data on block elements
    public static let sourcePos = ParserOptions(rawValue: 1 << 1)
    
    /// Render soft breaks as hard line breaks
    public static let hardBreaks = ParserOptions(rawValue: 1 << 2)
    
    /// Allow raw HTML and unsafe links (javascript:, data:, etc)
    public static let unsafe = ParserOptions(rawValue: 1 << 17)
    
    /// Render soft breaks as spaces
    public static let noBreaks = ParserOptions(rawValue: 1 << 4)
    
    /// Validate UTF-8 input, replacing invalid sequences with U+FFFD
    public static let validateUTF8 = ParserOptions(rawValue: 1 << 9)
    
    /// Convert straight quotes to curly, --- to em dashes, -- to en dashes
    public static let smart = ParserOptions(rawValue: 1 << 10)
    
    // GFM-specific options (commented for documentation, not all may be available)
    // These would require additional implementation:
    // - STRIKETHROUGH_DOUBLE_TILDE: Require exactly 2 tildes for strikethrough
    // - TABLE_PREFER_STYLE_ATTRIBUTES: Use style attributes for table alignment
    // - FULL_INFO_STRING: Include full info string in code blocks
}

public struct CMarkParser: MarkdownParsing, Sendable {
    private let options: ParserOptions
    private let enabledExtensions: Set<GFMExtension>
    
    /// Initialize parser with custom options and extensions
    /// - Parameters:
    ///   - options: Parser options to control parsing behavior. Default includes all useful options
    ///   - extensions: GFM extensions to enable. Default includes all available extensions
    public init(
        options: ParserOptions = [.smart, .validateUTF8],
        extensions: Set<GFMExtension> = GFMExtension.all
    ) {
        self.options = options
        self.enabledExtensions = extensions
    }
    
    /// Initializer for minimal parsing (CommonMark only, no extensions)
    public static func minimal() -> CMarkParser {
        return CMarkParser(options: [], extensions: [])
    }
    
    /// Initializer for standard GitHub Flavored Markdown (without smart typography)
    public static func standard() -> CMarkParser {
        return CMarkParser(options: [.validateUTF8], extensions: GFMExtension.standard)
    }
    
    /// Initializer for maximum compatibility (all features enabled)
    public static func maximal() -> CMarkParser {
        return CMarkParser(options: [.smart, .validateUTF8], extensions: GFMExtension.all)
    }

    public func parse(markdown: String) -> MarkdownDocument {
        #if canImport(cmark_gfm)
        return CMarkBridge(options: options, extensions: enabledExtensions).parse(markdown: markdown)
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
import cmark_gfm
import cmark_gfm_extensions

private typealias UnsafeNode = UnsafeMutablePointer<cmark_node>

private struct CMarkBridge {
    let options: ParserOptions
    let extensions: Set<GFMExtension>
    
    init(options: ParserOptions, extensions: Set<GFMExtension>) {
        self.options = options
        self.extensions = extensions
    }
    
    func parse(markdown: String) -> MarkdownDocument {
        // Register core GFM extensions and attach them to the parser
        cmark_gfm_core_extensions_ensure_registered()
        
        // Convert our ParserOptions to cmark options
        var cmarkOptions = CMARK_OPT_DEFAULT
        if options.contains(.sourcePos) {
            cmarkOptions |= CMARK_OPT_SOURCEPOS
        }
        if options.contains(.hardBreaks) {
            cmarkOptions |= CMARK_OPT_HARDBREAKS
        }
        if options.contains(.unsafe) {
            cmarkOptions |= CMARK_OPT_UNSAFE
        }
        if options.contains(.noBreaks) {
            cmarkOptions |= CMARK_OPT_NOBREAKS
        }
        if options.contains(.validateUTF8) {
            cmarkOptions |= CMARK_OPT_VALIDATE_UTF8
        }
        if options.contains(.smart) {
            cmarkOptions |= CMARK_OPT_SMART
        }
        
        guard let parser = cmark_parser_new(cmarkOptions) else {
            return MarkdownDocument(blocks: [.paragraph(inlines: [.text(markdown)])])
        }
        defer { cmark_parser_free(parser) }

        // Attach requested extensions
        for gfmExtension in extensions {
            let name = gfmExtension.rawValue
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
        // Flatten any nested document nodes produced by fallback mapping
        let flat = flattenBlocks(blocks)
        return MarkdownDocument(blocks: flat)
    }

    private func flattenBlocks(_ blocks: [BlockNode]) -> [BlockNode] {
        var result: [BlockNode] = []
        for block in blocks {
            switch block {
            case .document(let children):
                result.append(contentsOf: flattenBlocks(children))
            case .blockQuote(let children):
                result.append(.blockQuote(children: flattenBlocks(children)))
            case .list(let kind, let items):
                let newItems = items.map { item in
                    ListItem(checked: item.checked, children: flattenBlocks(item.children))
                }
                result.append(.list(kind: kind, items: newItems))
            default:
                result.append(block)
            }
        }
        return result
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
            var literal = stringOrEmpty(cmark_node_get_literal(node))
            // Remove trailing newline if present (cmark adds one)
            if literal.hasSuffix("\n") {
                literal.removeLast()
            }
            let lang = stringOrNil(cmark_node_get_fence_info(node))
            return .codeBlock(language: lang, code: literal)
        case CMARK_NODE_THEMATIC_BREAK:
            return .thematicBreak
        case CMARK_NODE_HTML_BLOCK:
            // HTML blocks are not supported - skip them
            return nil
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
        // Use the GFM API to detect tasklist items and checked state
        // Getter returns false for both unchecked and non-task items; use setter to detect presence without changing state
        let currentChecked = cmark_gfm_extensions_get_tasklist_item_checked(node)
        let isTaskItem = cmark_gfm_extensions_set_tasklist_item_checked(node, currentChecked) == 1
        let checked: Bool? = isTaskItem ? currentChecked : nil
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
        case CMARK_NODE_HTML_INLINE:
            // Convert common <br> variants to a line break; otherwise return as text
            let html = stringOrEmpty(cmark_node_get_literal(node))
            if isHTMLBreak(html) { return .lineBreak }
            return .text(html)
        case CMARK_NODE_CODE:
            return .code(stringOrEmpty(cmark_node_get_literal(node)))
        case CMARK_NODE_LINK:
            let urlString = stringOrNil(cmark_node_get_url(node)) ?? ""
            let title = stringOrNil(cmark_node_get_title(node))
            if let url = URL(string: urlString) {
                return .link(url: url, title: title, children: collectInlines(from: node))
            } else {
                // Invalid URL: render children as plain text to avoid losing content
                let children = collectInlines(from: node)
                let plain = children.map(inlinePlainText).joined()
                return .text(plain.isEmpty ? urlString : plain)
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
            // Handle GFM extensions by checking type string
            let typeStr = nodeTypeString(node)
            switch typeStr {
            case "strikethrough":
                return .strikethrough(collectInlines(from: node))
            default:
                if let lit = stringOrNil(cmark_node_get_literal(node)) { 
                    return .text(lit) 
                }
                return nil
            }
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

    private func isHTMLBreak(_ html: String) -> Bool {
        // Match <br>, <br/>, <br /> in any case with optional whitespace
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return lower == "<br>" || lower == "<br/>" || lower == "<br />"
    }

    private func inlinePlainText(_ inline: InlineNode) -> String {
        switch inline {
        case .text(let s):
            return s
        case .code(let s):
            return s
        case .softBreak:
            return " "
        case .lineBreak:
            return "\n"
        case .image(_, let alt):
            return alt ?? ""
        case .emphasis(let children), .strong(let children), .strikethrough(let children):
            return children.map(inlinePlainText).joined()
        case .link(_, _, let children):
            return children.map(inlinePlainText).joined()
        }
    }
}
#endif
