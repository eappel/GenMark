Here’s how to put sourcePos to work in GenMark, with concrete uses and a lean im
plementation plan.

Recommended Uses
- Stable IDs: Use source positions to derive stable, content-anchored IDs for `F
orEach` in SwiftUI (no more index-based churn).
- Incremental diffing: On re-parse, match blocks by source positions to preserve
 view identity, selections, and scroll position.
- Caching keys: Key attributed-string caches by `(node type, sourcePos, trait en
v)` to avoid rebuilding unchanged text.
- Selection mapping: Map `NSRange` in the rendered text back to source lines/col
umns for features like jump-to-source or editor sync.
- Diagnostics: Highlight problematic spans (lint, validation) by mapping source
spans to rendered ranges.
- Scroll restoration: Remember the top-visible block’s sourcePos and restore nea
r it after content updates.
- Developer tooling: Optional overlay showing `data-sourcepos` for debugging.

Data Model Additions
- Add `SourcePos`:
  - Fields: `startLine`, `startColumn`, `endLine`, `endColumn`.
  - Optional fields (later): derived UTF-8/UTF-16 `Range<Int>` if/when needed fo
r text mapping.
- Attach to nodes:
  - Start with `BlockNode` (reliable from cmark). Inline nodes can be added late
r only when needed.
  - Example: `case paragraph(inlines: [InlineNode], sourcePos: SourcePos?)`.
- Node identity:
  - Add `var id: String` computed from `SourcePos` (e.g., “1:1-3:5:paragraph”).
Use for `ForEach`.

Parser Changes
- Enable positions: set `ParserOptions.sourcePos` → `CMARK_OPT_SOURCEPOS`.
- Read positions: for each mapped block, call:
  - `cmark_node_get_start_line`, `cmark_node_get_start_column`,
  - `cmark_node_get_end_line`, `cmark_node_get_end_column`.
- Plumb `SourcePos` into `BlockNode` constructors during mapping.

Renderer/Factory Updates
- SwiftUI `MarkdownView`:
  - Use `node.id` (from `SourcePos`) in all `ForEach` blocks (blocks, lists, tab
les).
- UIKit `AttributedTextFactory`:
  - Introduce an optional cache keyed by `(nodeType, sourcePos, traitSignature)`
 to reuse attributed strings for unchanged blocks.
- Selection/scroll:
  - Expose optional callbacks (e.g., `onBlockVisible(SourcePos)`) to help client
s retain scroll position across updates.

Deriving Byte/Text Ranges (when needed)
- Precompute line start UTF-8 indices for the input string once per parse.
- Map `(line, column)` to UTF-8 offset; convert to `String.Index` and then to UT
F-16 `NSRange` if needed by UIKit.
- Do this lazily (only when a feature requires it); keep `SourcePos` as the prim
ary ID.

Minimal Implementation Plan
1) Add `SourcePos` struct and attach `sourcePos: SourcePos?` to `BlockNode` case
s.
2) Toggle parsing: set `ParserOptions.sourcePos` in `MarkdownView` defaults and
in `CMarkBridge`.
3) Populate: call cmark getters during `mapBlock` and assign `sourcePos` on each
 block node.
4) IDs: add a computed `id` on `BlockNode` from `sourcePos` (fallback to a hash
if positions are missing).
5) SwiftUI: swap `ForEach(..., id: \.self)`/indices for `ForEach(..., id: \.id)`
 everywhere we render blocks, list items, and table cells.
6) Optional cache: introduce a small in-memory cache for attributed strings keye
d by `(type, id, traitSignature)`; invalidate on theme/trait changes.
7) API hook (optional): surface `onBlockVisible` or similar for scroll restorati
on in `MarkdownView`.

Notes
- Inline positions: cmark-gfm doesn’t reliably expose them; start with blocks. I
f later needed, approximate inline spans from child literals when feasible.
- Performance: position tracking overhead is small; range derivation should be l
azy to avoid per-frame work.

If you want, I can implement step 1–5 now (model + parser + stable IDs), and lea
ve caching and mapping to ranges for a follow-up.
