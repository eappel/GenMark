# GenMark Markdown SDK — Implementation Plan (iOS 18+)

This is the living implementation plan for a high‑performance, fully customizable GitHub‑Flavored Markdown (GFM) renderer for SwiftUI with UIKit/UITextView under the hood. We will continuously update this document as we build.

## Goals
- **Performance**: off‑main parsing, lazy block rendering, UITextView (TextKit) for long rich text.
- **Streaming LLM Support**: Optimized for rendering streaming responses from Large Language Models with frequent content updates. Critical requirement: update UITextViews in-place rather than destroying and recreating views to maintain smooth streaming performance.
- **Completeness**: Full GFM feature set (tables, task lists, strikethrough, autolinks, footnotes, etc.).
- **Customization**: Result‑builder driven styling and component overrides at runtime; per‑node and per‑attribute control (e.g., link by destination).
- **Integration**: SwiftUI wrapper, mix UIKit via `UIViewRepresentable` where needed, tables via `LazyVGrid`.
- **Selection**: Selectable text globally (headings, paragraphs, lists, table cells, code blocks).
- **Links**: SDK does not auto‑open links; forwards to SwiftUI `openURL` environment for consumers to handle.
- **Theming**: System colors by default with dynamic type and dark mode support.
- **Images**: Default lightweight loader with protocol for custom loaders.
- **Typography**: System fonts with explicit point sizes. NEVER use SwiftUI semantic font modifiers like `.headline`, `.largeTitle`, `.body` etc. Always use explicit `UIFont.systemFont(ofSize:weight:)` for precise control.

## Scope & Constraints
- Platform: iOS 18 minimum (TextKit 2 APIs, `UIViewRepresentable.sizeThatFits`, modern SwiftUI behaviors guaranteed).
- Markdown: Entire GitHub‑Flavored Markdown scope. Parse via `cmark-gfm` + `cmark-gfm-extensions` from Apple’s `swift-cmark`, then map to an internal node model.
- Network: Image loading via injectable loader; default is lightweight, URLSession‑based with in‑memory cache.

## High‑Level Architecture
- Pipeline: `String` → `cmark-gfm` AST → Internal `MarkdownNode` tree → Layout/Render units → Views
- Layers:
  - Core (parse + model): `GenMarkCore`
  - UIKit bridge (UITextView/TextKit): `GenMarkUIKit`
  - SwiftUI facade and renderers: `GenMarkUI`
- Rendering strategy:
  - Blocks render in a `LazyVStack` for vertical content.
  - Tables render with `LazyVGrid` (dynamic columns) with cells embedding text views.
  - Inline content renders to `NSAttributedString` via style providers and UITextView/TextKit.
  - UIKit `UITextView` (non‑scrollable, selectable) embedded with `UIViewRepresentable` for heavy text blocks.

## Parser: `cmark-gfm` (swift-cmark)
- Integrate `cmark-gfm` + `cmark-gfm-extensions` via SPM and Tuist; wrap in `GenMarkCore`.
- **Reference**: See `swift-cmark-reference.txt` for implementation details from the swift-cmark library.
- Register and attach GFM extensions: `autolink`, `strikethrough`, `tagfilter`, `tasklist`, and `table`.
- **Configurable parser options**: Support for `sourcePos`, `hardBreaks`, `unsafe`, `noBreaks`, `validateUTF8`, and `smart` typography.
- **Customizable extensions**: Allow consumers to enable/disable specific GFM extensions as needed.
- Convert nodes to our internal model (blocks/inlines) decoupled from rendering.
- Extract GFM metadata where present (task list `checked`, code fence `language`, table columns/alignments).
- Use `UnsafeMutablePointer<cmark_node>` in Swift (imported as opaque pointers) with helpers; feed UTF‑8 bytes without relying on `strlen`.
- Preserve source ranges (byte offsets) when available to form stable IDs and support caching/diffing. (Planned)
- Parse off‑main; debounce and deliver to the main thread for UI updates. (Planned)

## Node Model
Block nodes:
- `Document`, `Heading(level:Int)`, `Paragraph`, `List(kind: ordered|bullet|task, start:Int?)`, `ListItem(checked: Bool?)`, `BlockQuote`, `CodeBlock(language:String?)`, `ThematicBreak`, `Table`, `TableRow(header: Bool)`, `TableCell(alignment: left|center|right)`

Inline nodes:
- `Text`, `Emphasis`, `Strong`, `Strikethrough`, `Code`, `Link(url: URL, title: String?)`, `Image(url: URL, alt: String?)`, `SoftBreak`, `LineBreak`, `Autolink`
- Note: HTML tags, `Highlight`/`Mark` (==text==) and `FootnoteReference` are NOT supported

Notes:
- Each node has `id` (stable), `children`, and optional source `range`.
- Node identity is hashed over type + range + textual content to enable memoization.

## Styling & Customization System
Two complementary systems for maximum flexibility:
- **Theme (baseline)**: `MarkdownTheme` using `NSAttributedString.Key` dictionaries for complete transparency in attribute construction
- **Runtime customization**: `MarkdownCustomization` with closure-based inline and block overrides

### Theme Architecture (NSAttributedString.Key Dictionaries)
The theme system uses attribute dictionaries directly for transparent and traceable styling:
```swift
public struct MarkdownTheme: @unchecked Sendable {
    // Base text attributes using NSAttributedString.Key dictionaries
    public var textAttributes: [NSAttributedString.Key: Any]
    public var h1Attributes: [NSAttributedString.Key: Any]
    public var codeAttributes: [NSAttributedString.Key: Any]
    public var linkAttributes: [NSAttributedString.Key: Any]
    // ... other attribute dictionaries
}
```

### Runtime Customization System
Simple closure-based system for node appearance overrides:
```swift
public struct MarkdownCustomization: Sendable {
    // Inline node customization - modifies NSAttributedString attributes
    public let inlineCustomizer: @Sendable (InlineNode, [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any]?
    
    // Block node customization - returns custom SwiftUI views
    public let blockCustomizer: @Sendable (BlockNode, MarkdownTheme) -> AnyView?
}
```

### Customization Examples:
```swift
// Inline customization - modify text attributes
.inline { node, attrs in
    if case .code = node {
        var newAttrs = attrs
        newAttrs[.foregroundColor] = UIColor.systemGreen
        newAttrs[.backgroundColor] = UIColor.systemGreen.withAlphaComponent(0.1)
        return newAttrs
    }
    return nil
}

// Block customization - replace entire block rendering
.block { node, theme in
    if case .blockQuote(_) = node {
        return AnyView(CustomBlockQuoteView())
    }
    return nil
}

// Combined customizations
MarkdownCustomization.combine(inlineCustomizer, blockCustomizer)
```

**Benefits of Dictionary-Based Approach:**
- **Complete transparency**: Easy to trace how attributed strings are constructed
- **Direct control**: No hidden conversions or intermediate abstractions  
- **Simple merging**: Straightforward attribute dictionary operations
- **UIKit compatibility**: Native NSAttributedString.Key usage throughout

## Public SwiftUI API
```swift
public struct MarkdownView: View {
  public init(
    _ markdown: String,
    theme: MarkdownTheme = .systemDefault,
    customization: MarkdownCustomization = .none,
    parserOptions: ParserOptions = [.smart, .validateUTF8],  // Standard features enabled by default
    extensions: Set<GFMExtension> = GFMExtension.all  // All extensions enabled by default
  )
  
  // Convenience minimal CommonMark parsing
  public static func minimal(
    _ markdown: String,
    theme: MarkdownTheme = .systemDefault,
    customization: MarkdownCustomization = .none
  ) -> MarkdownView
}
```

### Parser Defaults (Opt-Out Design)
By default, the parser includes standard features for maximum compatibility:
- **Default options enabled**: `.smart`, `.validateUTF8`
- **All extensions enabled**: Standard GFM extensions
- Features are opt-out rather than opt-in

### Convenience Initializers
```swift
// Default: All features enabled
let parser = CMarkParser()

// Minimal: CommonMark only, no extensions
let parser = CMarkParser.minimal()

// Standard GFM: Standard extensions, no smart typography
let parser = CMarkParser.standard()
```
Environment and protocols:
- `@Environment(\.openURL) private var openURL` used to forward link taps. SDK does not open links itself; it invokes `openURL(url)` and does nothing further.
- `EnvironmentKey` for `MarkdownImageLoader` (default provided).
- `EnvironmentKey` for `MarkdownTheme`.

Link handling behavior:
- When a link is tapped in `UITextView`, delegate calls `openURL(url)`. If consumer hasn’t provided a handler, system may decide; we do not force opening.

## UIKit/TextKit Bridge

### MarkdownTextView: UIViewRepresentable
Hosts a `UITextView` with TextKit stack optimized for streaming content updates:
- TextKit components: `NSTextStorage`, `NSLayoutManager`, `NSTextContainer`

### Configuration
- `isEditable = false`, `isScrollEnabled = false`, `isSelectable = true` (global selection requirement)
- `textDragInteraction?.isEnabled = true` where applicable (copy support)  
- Zero text container insets and line fragment padding to align with SwiftUI layout
- Link interaction via delegate `textView(_:shouldInteractWith:in:interaction:)` forwarding to `openURL`
- `preferredMaxLayoutWidth` style measurement via `sizeThatFits`/`intrinsicContentSize`; adopt `UIViewRepresentable.sizeThatFits(_:)` on iOS 18

### Streaming Performance Optimizations
- **UITextView persistence**: Maintain the same UITextView instance across content updates to preserve selection state and avoid re-layout costs
- **TextKit object reuse**: Never reallocate `NSLayoutManager` or `NSTextContainer` on `updateUIView`
- **Attributed text updates**: Use efficient `NSMutableAttributedString` operations when possible instead of full `attributedText` replacement
- **Selection preservation**: Maintain cursor position and text selection during streaming updates where appropriate
- **Layout stability**: Minimize layout thrashing by batching attribute changes and avoiding unnecessary `invalidateIntrinsicContentSize` calls

### AttributedText Generation
- Generate attributed text via `AttributedTextFactory` from inline node subtrees
- Cache attributed strings per node identity to avoid regenerating unchanged content
- Support incremental updates for append-only streaming scenarios

## Rendering Blocks
- Document → `LazyVStack(alignment: .leading, spacing: theme.blockSpacing) { ForEach(blocks) { render(block) } }`
- Paragraph/Heading/BlockQuote/List items/Table cells → `MarkdownTextView` configured with appropriate styles
- Lists:
  - Ordered: Numbers ("1.", "2.", etc.) rendered in HStack with proper alignment
  - Bullet: Bullet symbol ("•") in HStack with `.firstTextBaseline` alignment
  - Task list: SF Symbols checkboxes ("square" / "checkmark.square.fill") with theme colors
- Code blocks:
  - Monospaced fonts, selectable text, `textContentType = .sourceCode`
  - No syntax highlighting in v1 (optional future enhancement)
- Thematic break: thin `Rectangle` with system separator color
- Tables:
  - Parse GFM tables; infer column alignments
  - `LazyVGrid(columns: [GridItem] * N)` with spacing from theme
  - Header row styled via style provider; cells render with `MarkdownTextView`
  - Cell alignment via `frame(maxWidth: .infinity, alignment:)` based on GFM spec
  - Unique IDs for cells to prevent LazyVGrid collisions

## Images
- Protocol: `MarkdownImageLoader` with simple `load(url: URL, sizeHint: CGSize?, completion: (UIImage?) -> Void)`
- Default implementation: URLSession + in‑memory `NSCache<NSURL, UIImage>`; background decode
- SwiftUI wrapper view chooses loader from environment; renders placeholder and respects alt text for accessibility

## Caching & Performance

### Streaming LLM Optimization Strategy
**Critical for LLM streaming performance**: GenMark must excel at handling frequently changing markdown content without creating visual jank or performance degradation.

#### View Lifecycle Management
- **UITextView Reuse**: Never destroy and recreate UITextView instances during content updates. Always update `attributedText` in-place via `updateUIView(_:context:)`.
- **SwiftUI Identity Preservation**: Use stable IDs based on node structure rather than content to prevent SwiftUI from destroying and recreating view hierarchies.
- **Incremental Updates**: When possible, detect and apply minimal diffs to attributed strings rather than full replacement.

#### Performance Caches
- **Parse cache**: Cache `MarkdownNode` tree keyed by input content hash with LRU eviction
- **Attributed string cache**: Key on inline subtree identity + style signature + UITraitCollection  
- **Measurement cache**: Cache paragraph/heading measurements for faster `sizeThatFits` under stable width
- **Node identity cache**: Stable IDs from content structure (not byte ranges) to enable efficient diffing

#### Streaming-Specific Optimizations
- **Debounced parsing**: Coalesce rapid content changes with configurable debounce interval (default ~16ms for 60fps)
- **Partial invalidation**: When content changes, only re-parse and re-render affected subtrees
- **Background parsing**: Parse new content off-main thread while maintaining current render until ready
- **Smooth transitions**: Avoid visible flicker during content updates by maintaining view references

## Parser Options and Extensions

### Parser Options (Supported by cmark-gfm):

#### Currently Implemented in GenMark:
- **`.default`**: Standard CommonMark + GFM behavior (empty option set)
- **`.sourcePos`** (`CMARK_OPT_SOURCEPOS`): Include source position data on block elements
- **`.hardBreaks`** (`CMARK_OPT_HARDBREAKS`): Render soft breaks as hard line breaks
- **`.noBreaks`** (`CMARK_OPT_NOBREAKS`): Render soft breaks as spaces
- **`.validateUTF8`** (`CMARK_OPT_VALIDATE_UTF8`): Validate and sanitize UTF-8 input
- **`.smart`** (`CMARK_OPT_SMART`): Smart typography (curly quotes, em/en dashes)
- **`.unsafe`** (`CMARK_OPT_UNSAFE`): Allow raw HTML and unsafe links (currently just renders HTML as plain text)

#### Available in cmark-gfm but NOT Implemented:
- `CMARK_OPT_NORMALIZE`: Consolidate adjacent text nodes
- `CMARK_OPT_GITHUB_PRE_LANG`: Use GitHub-style language classes for code blocks
- `CMARK_OPT_LIBERAL_HTML_TAG`: More liberal HTML tag parsing
- `CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE`: Require exactly 2 tildes for strikethrough
- `CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES`: Use style attributes instead of align for tables
- `CMARK_OPT_FULL_INFO_STRING`: Include full info string in code block metadata
- `CMARK_OPT_UNSAFE`: Safe mode (inverse of unsafe) - deprecated
- `CMARK_OPT_INLINE_ONLY`: Parse only inline content
- `CMARK_OPT_PRESERVE_WHITESPACE`: Preserve leading/trailing whitespace
- `CMARK_OPT_TABLE_SPANS`: Support row/column spans in tables
- `CMARK_OPT_TABLE_ROWSPAN_DITTO`: Use "ditto" marks for row spans

### GFM Extensions (Available in swift-cmark):

#### Currently Enabled by Default:
- **`autolink`**: Auto-detect URLs and email addresses
- **`strikethrough`**: ~~text~~ syntax for strikethrough
- **`tagfilter`**: Filter dangerous HTML tags (script, style, etc.)
- **`tasklist`**: - [ ] and - [x] checkbox syntax for task lists
- **`table`**: Pipe table syntax with alignment support

### Features NOT Supported:
- **HTML Rendering**: HTML tags are displayed as plain text, not rendered
- **Highlight/Mark**: The ==text== syntax is NOT supported (no extension available)
- **Footnotes**: [^1] syntax is NOT supported (no extension available)
- **Definition Lists**: DL/DT/DD syntax is NOT supported
- **Abbreviations**: *[HTML]: HyperText Markup Language syntax is NOT supported
- **Custom IDs**: {#custom-id} syntax is NOT supported
- **Math**: $LaTeX$ syntax is NOT supported (would require KaTeX/MathJax)
- **Emoji**: :emoji: shortcodes are NOT supported
- **Mentions**: @username syntax is NOT supported
- **Wiki Links**: [[Page Name]] syntax is NOT supported

## Accessibility
- Dynamic Type: fonts via `UIFontMetrics`
- VoiceOver: link announcements from `NSAttributedString.Key.link`; images use alt text as accessibility label
- Increased contrast aware colors using system semantic colors
- Focus and selection: selectable text across all blocks

## Theming
- `MarkdownTheme.systemDefault` uses system semantic colors (e.g., `.label`, `.secondaryLabel`, `.separator`, `.systemBackground`, `.secondarySystemBackground`).
- Exposes spacing, indents, table paddings, rule thickness.
- Consumers can override via environment or initializer; result‑builder overrides remain the fine‑grained layer.

### Default Typography (Point Sizes)
- Body: `UIFont.systemFont(ofSize: 16, weight: .regular)`
- Code (inline): `UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)` with background inset
- Code block: `UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)`
- H1: `UIFont.systemFont(ofSize: 28, weight: .semibold)`
- H2: `UIFont.systemFont(ofSize: 24, weight: .semibold)`
- H3: `UIFont.systemFont(ofSize: 20, weight: .semibold)`
- H4: `UIFont.systemFont(ofSize: 17, weight: .semibold)`
- H5: `UIFont.systemFont(ofSize: 15, weight: .medium)`
- H6: `UIFont.systemFont(ofSize: 13, weight: .medium)`
- Quote: base on Body with `.italicSystemFont(ofSize: 16)` or `UIFontDescriptor` trait

## Example Usage
```swift
// Simple usage with defaults
MarkdownView(markdownContent)

// With custom theme
MarkdownView(markdownContent, theme: .systemDefault)

// With customization
MarkdownView(
    markdownContent,
    customization: .combine(
        .inline { node, attrs in
            // Custom link styling by destination
            if case .link(let url, _, _) = node, url.host == "internal.myco.com" {
                var newAttrs = attrs
                newAttrs[.foregroundColor] = UIColor.systemGreen
                newAttrs[.underlineStyle] = nil
                return newAttrs
            }
            return nil
        },
        .block { node, theme in
            // Custom heading rendering
            if case .heading(1, _) = node {
                return AnyView(CustomGradientHeading(node: node, theme: theme))
            }
            return nil
        }
    )
)
// Consumers handle links via SwiftUI environment
.environment(\.openURL, OpenURLAction { url in
    // Custom link handling logic
    return .handled
})
```

## Package Layout (SPM)
- `GenMarkCore`
  - `CMarkParser` wrapper (cmark-gfm with extensions)
  - Node model, transforms, caching keys
- `GenMarkUIKit`
  - `MarkdownTheme` (NSAttributedString.Key dictionary-based theming)
  - `MarkdownCustomization` (inline and block customization closures)
  - `AttributedTextFactory` (inline → NSAttributedString with transparent attribute merging)
  - `MarkdownTextView` (UIViewRepresentable)
  - TextKit helpers and measurement cache
- `GenMarkUI`
  - `MarkdownView` (SwiftUI facade)
  - Block renderers (paragraphs, headings, lists, quotes, code, tables, hr). Uses concrete `BlockRenderer`/`CellRenderer` views to avoid recursive opaque type issues.
  - Image view + loader environment

## Recent Decisions & Progress
- Parser: switched to `cmark-gfm` + extensions; attach GFM extensions on parse; map code fence language, task‑list check state, and table alignment.
- SwiftUI rendering: replaced recursive `blockView(_:)` with typed `BlockRenderer`/`CellRenderer` views to avoid self‑referential opaque return types.
- Targets/tooling: iOS 18 minimum and Swift 6; Tuist manifest updated to current DSL (`destinations`, `deploymentTargets`). Makefile builds via `tuist build`.
- Example app resources: fixtures are bundled under `App/Resources/Fixtures` and loaded via `Bundle.main`.
- Tests: added a Tuist unit‑test target mirroring SPM tests; added a small shim so `Bundle.module` pathing works under Tuist.
- Test configuration: Fixed Tuist test target setup with proper scheme configuration using `shared: true` and explicit test/run actions.
- UITextView sizing: Implemented `sizeThatFits(_:uiView:context:)` method to properly handle text wrapping and prevent overflow in UIViewRepresentable.
- List rendering: Implemented proper list markers using HStack approach with bullets ("•"), ordered numbers, and checkboxes (SF Symbols) for task lists.
- Table rendering: Fixed LazyVGrid ID collisions and implemented cell alignment (left/center/right) with proper frame modifiers.
- HTML support: HTML tags are now rendered as plain text (not parsed or rendered as HTML).

## Milestones
1) SPM scaffolding and targets; iOS 18 deployment settings
2) Tuist workspace/project + Dependencies.swift for `swift-cmark`
3) Author complex GFM fixtures (≥3 files) covering all component types
4) Integrate `swift-cmark`; AST → internal node model
5) Parser unit tests using fixtures (validate full GFM mapping)
6) Example app with Xcode Previews rendering fixtures for visual inspection
7) Inline attributed factory with baseline styles; link attributes
8) `MarkdownTextView` with UITextView (TextKit), selection, link delegate, sizeThatFits
9) Paragraphs, headings, quotes rendering via `LazyVStack`
10) Lists (ordered, bullet, task)
11) Code blocks (monospaced, selectable; no highlighting)
12) Tables with `LazyVGrid`; header styling; cell alignment
13) Styling result builders and theme; per‑destination link styling
14) Image loader (default) and view; environment injection
15) Caching/memoization + measurement cache
16) Accessibility pass + Dynamic Type tuning
17) Performance profiling and tuning on long docs
18) Documentation and examples

## TODO (Living Checklist)
- [x] Create SPM package with targets `GenMarkCore`, `GenMarkUIKit`, `GenMarkUI` (iOS 18)
- [x] SPM: Swift 6 tools and `platforms: [.iOS(.v18)]`
- [x] SPM: `swift-cmark` dependency using GFM products
- [x] Add `cmark-gfm` dependency and parser wrapper in Core (attach GFM extensions)
- [x] Define internal node model (blocks/inlines)
- [x] Structure: Keep Core UI‑agnostic; move `AttributedTextFactory` into UIKit target
- [x] Tuist: Workspace/Project using modern DSL (`destinations`, `deploymentTargets`)
- [x] Tuist: Dependencies.swift mapping GFM products (`cmark-gfm`, `cmark-gfm-extensions`)
- [x] Parser options: Added configurable parser options (sourcePos, hardBreaks, noBreaks, validateUTF8, smart)
- [x] Customizable extensions: Allow enabling/disabling specific GFM extensions
- [x] Author ≥3 complex GFM markdown fixtures (cover tables, lists, tasks, footnotes, autolinks, images, code)
- [x] Parser unit tests skeleton using fixtures; add Tuist unit‑test target
- [x] Test infrastructure: Tuist test targets working with proper scheme configuration
- [x] Implement `AttributedTextFactory` (baseline inline → NSAttributedString)
- [x] Build `MarkdownTextView` (UITextView/TextKit, selectable text, link delegate, zero insets)
- [x] UITextView text wrapping: Fixed overflow issue with `sizeThatFits` implementation
- [x] Integrate `@Environment(\.openURL)` for link taps via UITextView bridge
- [x] Design `MarkdownTheme` defaults (system colors, explicit fonts)
- [x] Implement customization system with transparent NSAttributedString.Key dictionaries
- [x] Replace TextStyle abstraction with direct attribute dictionary operations
- [x] Implement SwiftUI block renderers (paragraphs, headings, quotes) via `BlockRenderer`
- [x] List markers: Bullets ("•"), ordered numbers, and checkbox symbols for task lists
- [x] Implement lists (ordered, bullet, task list with proper markers and alignment)
- [x] Implement code blocks (monospaced, selectable; no highlighting)
- [x] Implement tables with `LazyVGrid` and alignment
- [x] Table cell alignment: Implemented left/center/right alignment from GFM spec
- [x] HTML handling: HTML tags are rendered as plain text (no HTML parsing/rendering)
- [x] Example app: Xcode Previews + fixture menu; fixtures bundled in app resources
- [x] Define `MarkdownImageLoader` protocol and default lightweight loader (URLSession + NSCache)
- [ ] Performance profiling on large README.md and table‑heavy docs
- [ ] Optimize UITextView reuse and in-place updates for streaming performance
- [ ] Add parse and attributed string caches (keys include trait collection) with LLM streaming optimizations
- [ ] Add measurement cache for paragraphs/headings
- [ ] Implement incremental content diffing for streaming updates
- [ ] Add debounced parsing for high-frequency content changes
- [ ] Accessibility review (VoiceOver, Dynamic Type, contrast)
- [ ] Documentation: Quick start, theming, overrides, performance tips

## Risks & Mitigations
- `swift-cmark` integration complexity: pin a known commit; add CI step to validate headers and symbols; abstract behind small parser API.
- UITextView sizing quirks: use `sizeThatFits` in representable and verify with layout tests; fallback to explicit layout manager sizing if needed.

## Open Decisions (to confirm later)
- Optional future: syntax highlighting approach if added later.
- Footnotes rendering style (inline vs. bottom list) and tap behavior.
- Copy interaction options (always on vs. long‑press menu customization).

---
Last updated: December 2024
- Fixed UITextView text overflow issue with proper `sizeThatFits` implementation
- Implemented list rendering with proper markers (bullets, numbers, checkboxes)
- Fixed table rendering: resolved LazyVGrid ID collisions and added cell alignment
- Added HTML tag support: `<br>` tags now properly render as line breaks
- Fixed Tuist test configuration with proper scheme setup
- All 46 tests passing including new test suites:
  - HTMLTagTests: Tests for HTML tag handling (<br> tags)
  - TableParsingTests: Tests for GFM table parsing with alignment
  - ParserOptionsTests: Tests for all configurable parser options
  - HighlightMarkTests: Tests for highlight/mark extension support
- Added configurable parser options (sourcePos, hardBreaks, unsafe, noBreaks, validateUTF8, smart)
- Parser defaults changed to opt-out: unsafe, validateUTF8, and smart enabled by default
- Strong typing for extensions via GFMExtension enum (all 5 available extensions enabled by default)
- Parser now supports customizable options and extensions via init parameters
- Important: Highlight/mark (==text==) and footnotes are NOT supported by swift-cmark
- **Styling System Refactored**: Replaced complex result-builder system with simple dictionary-based approach:
  - `MarkdownTheme` now uses NSAttributedString.Key dictionaries directly for complete transparency
  - `MarkdownCustomization` provides closure-based inline and block overrides
  - Removed intermediate TextStyle abstraction for direct attribute manipulation
  - All font modifications use proper UIFontDescriptor trait combining
  - Theme marked `@unchecked Sendable` for thread safety with documented constraints
- **LLM Streaming Requirements**: Added critical performance requirements for streaming LLM responses:
  - UITextView in-place updates to avoid destroying and recreating views
  - Stable view identity preservation during frequent content changes
  - Debounced parsing and incremental update strategies
  - Background parsing with smooth transition handling
- Next priorities: streaming performance optimizations, caching, and incremental diffing
