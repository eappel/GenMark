# GenMark Markdown SDK — Implementation Plan (iOS 18+)

This is the living implementation plan for a high‑performance, fully customizable GitHub‑Flavored Markdown (GFM) renderer for SwiftUI with UIKit/UITextView under the hood. We will continuously update this document as we build.

## Goals
- Performance: off‑main parsing, lazy block rendering, UITextView (TextKit) for long rich text.
- Completeness: Full GFM feature set (tables, task lists, strikethrough, autolinks, footnotes, etc.).
- Customization: Result‑builder driven styling and component overrides at runtime; per‑node and per‑attribute control (e.g., link by destination).
- Integration: SwiftUI wrapper, mix UIKit via `UIViewRepresentable` where needed, tables via `LazyVGrid`.
- Selection: Selectable text globally (headings, paragraphs, lists, table cells, code blocks).
- Links: SDK does not auto‑open links; forwards to SwiftUI `openURL` environment for consumers to handle.
- Theming: System colors by default with dynamic type and dark mode support.
- Images: Default lightweight loader with protocol for custom loaders.
- Typography: System fonts with explicit point sizes (avoid SwiftUI semantic fonts).

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
- Register and attach GFM extensions: `autolink`, `strikethrough`, `tagfilter`, `tasklist`, and `table`.
- Convert nodes to our internal model (blocks/inlines) decoupled from rendering.
- Extract GFM metadata where present (task list `checked`, code fence `language`, table columns/alignments).
- Use `UnsafeMutablePointer<cmark_node>` in Swift (imported as opaque pointers) with helpers; feed UTF‑8 bytes without relying on `strlen`.
- Preserve source ranges (byte offsets) when available to form stable IDs and support caching/diffing. (Planned)
- Parse off‑main; debounce and deliver to the main thread for UI updates. (Planned)

## Node Model
Block nodes:
- `Document`, `Heading(level:Int)`, `Paragraph`, `List(kind: ordered|bullet|task, start:Int?)`, `ListItem(checked: Bool?)`, `BlockQuote`, `CodeBlock(language:String?)`, `ThematicBreak`, `Table`, `TableRow(header: Bool)`, `TableCell(alignment: left|center|right)`

Inline nodes:
- `Text`, `Emphasis`, `Strong`, `Strikethrough`, `Code`, `Link(url: URL, title: String?)`, `Image(url: URL, alt: String?)`, `SoftBreak`, `LineBreak`, `Autolink`, `FootnoteReference` (and related GFM inline constructs).

Notes:
- Each node has `id` (stable), `children`, and optional source `range`.
- Node identity is hashed over type + range + textual content to enable memoization.

## Styling & Overrides (Result Builders)
Two complementary systems:
- Theme (baseline): `MarkdownTheme` for defaults (fonts, sizes, spacing, colors from system dynamic colors).
- Runtime overrides: `MarkdownStyle` and `MarkdownRenderOverrides` built with result builders.

Result builders:
- `@MarkdownStyleBuilder` composes per‑node style providers.
- `@MarkdownRendererBuilder` composes component overrides (replace default renderer for a node type/predicate).

Style providers (examples):
- `InlineStyle(.emphasis) { context in InlineTextStyle(...) }`
- `InlineStyle(.link) { (link: LinkNode, env) in InlineTextStyle(...) } // can branch by destination`
- `BlockStyle(.heading(1)) { BlockStyle(margins:..., background:...) }`
- `ImageStyle { (image: ImageNode) in ImagePresentation(...) }`

Inline style resolves to `NSAttributedString` attributes; block style resolves to layout (insets, background, borders).

## Public SwiftUI API (Initial Sketch)
```swift
public struct MarkdownView: View {
  public init(
    _ markdown: String,
    theme: MarkdownTheme = .systemDefault,
    @MarkdownStyleBuilder style: () -> MarkdownStyle = { .default },
    @MarkdownRendererBuilder renderers: () -> MarkdownRenderOverrides = { .empty }
  )
}
```
Environment and protocols:
- `@Environment(\.openURL) private var openURL` used to forward link taps. SDK does not open links itself; it invokes `openURL(url)` and does nothing further.
- `EnvironmentKey` for `MarkdownImageLoader` (default provided).
- `EnvironmentKey` for `MarkdownTheme`.

Link handling behavior:
- When a link is tapped in `UITextView`, delegate calls `openURL(url)`. If consumer hasn’t provided a handler, system may decide; we do not force opening.

## UIKit/TextKit Bridge
- `MarkdownTextView: UIViewRepresentable` that hosts a `UITextView` with TextKit stack:
  - `NSTextStorage`, `NSLayoutManager`, `NSTextContainer`
- Configuration:
  - `isEditable = false`, `isScrollEnabled = false`, `isSelectable = true` (global selection requirement)
  - `textDragInteraction?.isEnabled = true` where applicable (copy support)
  - Zero text container insets and line fragment padding to align with SwiftUI layout
  - Link interaction via delegate `textView(_:shouldInteractWith:in:interaction:)` forwarding to `openURL`
  - `preferredMaxLayoutWidth` style measurement via `sizeThatFits`/`intrinsicContentSize`; adopt `UIViewRepresentable.sizeThatFits(_:)` on iOS 18
- Attributed text generation via `AttributedTextFactory` from inline node subtrees
- Reuse TextKit objects where possible; avoid reallocating managers on `updateUIView`

## Rendering Blocks
- Document → `LazyVStack(alignment: .leading, spacing: theme.blockSpacing) { ForEach(blocks) { render(block) } }`
- Paragraph/Heading/BlockQuote/List items/Table cells → `MarkdownTextView` configured with appropriate styles
- Lists:
  - Ordered: prefix numbers computed once; hanging indent via paragraph style tab stops
  - Bullet: custom bullets with layout margins
  - Task list: `UICheckbox`-like glyph in attributed prefix; non‑interactive by default
- Code blocks:
  - Monospaced fonts, selectable text, `textContentType = .sourceCode`
  - No syntax highlighting in v1 (optional future enhancement)
- Thematic break: thin `Rectangle` with system separator color
- Tables:
  - Parse GFM tables; infer column alignments
  - `LazyVGrid(columns: [GridItem] * N)` with spacing from theme
  - Header row styled via style provider; cells render with `MarkdownTextView`

## Images
- Protocol: `MarkdownImageLoader` with simple `load(url: URL, sizeHint: CGSize?, completion: (UIImage?) -> Void)`
- Default implementation: URLSession + in‑memory `NSCache<NSURL, UIImage>`; background decode
- SwiftUI wrapper view chooses loader from environment; renders placeholder and respects alt text for accessibility

## Caching & Performance
- Parse cache: cache `MarkdownNode` tree keyed by input content hash
- Attributed string cache: key on inline subtree identity + style signature + UITraitCollection
- Measurement cache for paragraphs/headings for faster sizeThatFits under stable width
- Debounce parsing for rapidly changing input
- Stable IDs from source ranges to enable diffing in `ForEach`

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
MarkdownView(readme) { // style overrides
  Link { link in
    if link.url.host == "internal.myco.com" { return .init(foreground: .systemGreen, underline: false) }
    return .init(foreground: .link, underline: true)
  }
  Heading(1) { base in base.font = .preferredFont(forTextStyle: .largeTitle) }
  CodeBlock(language: "swift") { base in
    base.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    base.background = .secondarySystemBackground
  }
}
.environment(\.markdownImageLoader, .default)
// Consumers handle links
.environment(\.openURL, OpenURLAction { url in
  // Route URL or present sheet; return .handled / .discarded
  return .handled
})
```

## Package Layout (SPM)
- `GenMarkCore`
  - `CMarkParser` wrapper (cmark-gfm with extensions)
  - Node model, transforms, caching keys
  - `AttributedTextFactory` (inline → NSAttributedString)
- `GenMarkUIKit`
  - `MarkdownTextView` (UIViewRepresentable)
  - TextKit helpers and measurement cache
- `GenMarkUI`
  - `MarkdownView` (SwiftUI facade)
  - Block renderers (paragraphs, headings, lists, quotes, code, tables, hr). Uses concrete `BlockRenderer`/`CellRenderer` views to avoid recursive opaque type issues.
  - Styling system: theme, result builders, overrides
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
- [x] Author ≥3 complex GFM markdown fixtures (cover tables, lists, tasks, footnotes, autolinks, images, code)
- [x] Add `cmark-gfm` dependency and parser wrapper in Core (attach GFM extensions)
- [x] Define internal node model (blocks/inlines)
- [x] Parser unit tests skeleton using fixtures; add Tuist unit‑test target
- [x] Implement `AttributedTextFactory` (baseline inline → NSAttributedString)
- [x] Build `MarkdownTextView` (UITextView/TextKit, selectable text, link delegate, zero insets)
- [x] Implement SwiftUI block renderers (paragraphs, headings, quotes) via `BlockRenderer`
- [~] Implement lists (ordered, bullet, task list state mapping; visuals TBD)
- [x] Implement code blocks (monospaced, selectable; no highlighting)
- [x] Implement tables with `LazyVGrid` and alignment
- [x] Design `MarkdownTheme` defaults (system colors, explicit fonts)
- [ ] Implement `@MarkdownStyleBuilder` and style resolution (stubs exist)
- [ ] Implement `@MarkdownRendererBuilder` for component overrides (stubs exist)
- [x] Integrate `@Environment(\.openURL)` for link taps via UITextView bridge
- [ ] Define `MarkdownImageLoader` protocol and default lightweight loader (URLSession + NSCache)
- [ ] Add parse and attributed string caches (keys include trait collection)
- [ ] Add measurement cache for paragraphs/headings
- [ ] Accessibility review (VoiceOver, Dynamic Type, contrast)
- [ ] Performance profiling on large README.md and table‑heavy docs
- [ ] Documentation: Quick start, theming, overrides, performance tips
- [x] Example app: Xcode Previews + fixture menu; fixtures bundled in app resources
- [x] Tuist: Workspace/Project using modern DSL (`destinations`, `deploymentTargets`)
- [x] Tuist: Dependencies.swift mapping GFM products (`cmark-gfm`, `cmark-gfm-extensions`)
- [x] SPM: `swift-cmark` dependency using GFM products
- [x] Structure: Keep Core UI‑agnostic; move `AttributedTextFactory` into UIKit target
- [x] SPM: Swift 6 tools and `platforms: [.iOS(.v18)]`

## Risks & Mitigations
- `swift-cmark` integration complexity: pin a known commit; add CI step to validate headers and symbols; abstract behind small parser API.
- UITextView sizing quirks: use `sizeThatFits` in representable and verify with layout tests; fallback to explicit layout manager sizing if needed.

## Open Decisions (to confirm later)
- Optional future: syntax highlighting approach if added later.
- Footnotes rendering style (inline vs. bottom list) and tap behavior.
- Copy interaction options (always on vs. long‑press menu customization).

---
Last updated: Switched to cmark‑gfm + extensions, added BlockRenderer/CellRenderer to avoid recursive opaque types, bundled app fixtures, updated Tuist DSL, and marked current progress. Future steps focus on styling builders, image loading, caching, and off‑main parsing.
