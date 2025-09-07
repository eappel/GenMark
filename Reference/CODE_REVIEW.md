Here’s a staff-level review of the current GenMark codebase with concrete, high‑
leverage improvements to simplify, align with the implementation plan, and harde
n correctness and ergonomics.

**High‑Level**
- Robust core and a clean separation of concerns across `GenMarkCore` (parse + m
odel), `GenMarkUIKit` (AttributedString + TextKit), and `GenMarkUI` (SwiftUI).
- Parser bridging to `cmark-gfm` is pragmatic and mostly correct; SwiftUI render
ing is reasonably modular and uses UITextView where it matters.
- Several inconsistencies in build/manifests and examples, and a few correctness
/ergonomic/safety issues in core types and defaults.

**Build & Tooling**
- Makefile:
  - Bug: `reload` has a stray quote: `$(TUIST) generate"` → `$(TUIST) generate`.
  - Missing `open` target mentioned in the docs. Suggest:
    - `open`: `tuist generate && xed .`
    - `reload`: `tuist generate` (no open)
    - Consider consistent device parameterization for `test` using `-destination
`.
- Tuist vs README/Examples:
  - Tuist project uses `App/**` for the example app, but README and repo also sh
ip `Examples/GenMarkExample/**`.
  - `Examples/GenMarkExample` imports `GenMark` and uses `Sources/GenMark/SDKVie
w.swift`, but there is no SPM target or Tuist target named `GenMark`. This examp
le will not build.
  - Recommendation: Either remove the `Examples/` app or add a thin aggregator t
arget/product `GenMark` that reexports `GenMarkUI` (and optionally UIKit/Core),
then update Tuist to include it (or update the example to import `GenMarkUI`).
- SPM/Dependencies:
  - SPM setup for `swift-cmark` GFM branch and Tuist `Dependencies.swift` mappin
g looks correct.

**Core Parser (`GenMarkCore`)**
- Defaults and security:
  - `CMarkParser` defaults include `.unsafe`. This is risky and contrary to prin
ciple-of-least-privilege. Recommend default to safe options: `options: [.validat
eUTF8, .smart]` (no `.unsafe`), with `.unsafe` opt-in only.
  - `MarkdownView` initializer already defaults to `parserOptions: [.smart, .val
idateUTF8]`; align the `CMarkParser` default to match for consistency.
- Inline model simplification:
  - `InlineNode.autolink` is never produced (autolinks end up as `.link` in mapp
ing). Remove `autolink` from the model and tests; treat all links uniformly as `
.link`.
- HTML behavior and tests:
  - `mapInline(.HTML_INLINE)` returns `.text` (good) and `CMARK_NODE_HTML_BLOCK`
 is skipped. Tests assume `<br>` becomes `.lineBreak` — that holds if cmark norm
alizes `<br>` into a break; otherwise your mapping won’t create it from HTML_INL
INE. Consider explicitly converting common `<br>` variants in HTML inline litera
ls to `.lineBreak` only if cmark doesn’t already do so.
- List and task items:
  - Task item detection falls back to `nodeTypeString == "tasklist"` and then re
ads the checked bit. Confirm exact type string in the GFM API. If it’s actually
`"tasklist_item"`, or if relying solely on `cmark_gfm_extensions_get_tasklist_it
em_checked`, drop the string comparison and use the function’s semantics to dete
ct task-items directly.
- Fallback/document flattening:
  - `mapBlock` default sometimes produces `.document(children:[...])`, which cre
ates nested document blocks. Prefer to flatten unknown/transparent container typ
es into their children to avoid `.document` inside `.document`, simplifying down
stream rendering.
- Source positions:
  - Implementation Plan mentions preserving byte ranges for stable IDs. Not impl
emented. For streaming and diffing, add optional `range: Range<Int>` to nodes an
d map `CMARK_OPT_SOURCEPOS`.
- Minor:
  - `ParserOptions` rawValue uses `Int32`; cmark flags are C ints. `Int32` is fi
ne, but a `CInt` alias may read clearer.
  - Invalid link URLs: currently `.link` falls back to `.text(urlString)`, losin
g child inline content. Prefer rendering child inlines as text if the URL is inv
alid.

**UIKit/TextKit (`GenMarkUIKit`)**
- AttributedTextFactory:
  - Clear, direct attribute merging via dictionaries is great and transparent.
  - When overriding link attributes, you also set `.link` on the range — this is
 correct given `UITextView` renders from `.link`.
  - For code spans/blocks, consider adding a small paragraph style tweak (line h
eight) for readability.
- MarkdownTextView:
  - `sizeThatFits(_:uiView:context:)`: using `proposal.width ?? UIScreen.main.bo
unds.width` can be brittle in nested layouts. Prefer using proposal width only;
if nil, return nil to let SwiftUI size the view, or compute with the current vie
w’s bounds if available. On iOS 18, SwiftUI generally provides width.
  - Set `uiView.adjustsFontForContentSizeCategory = true` to better support Dyna
mic Type when fonts were created via `UIFontMetrics`.
  - For streaming updates (future work): preserve selection and avoid replacing
the entire `attributedText`; incrementally mutate a shared `NSMutableAttributedS
tring` and batch updates.
- Theme:
  - `MarkdownTheme` uses explicit fonts and colors; implementation plan mentions
 Dynamic Type via `UIFontMetrics`. Consider pre-scaling fonts with metrics or pr
oviding a helper to scale based on current `UITraitCollection`.
  - `@unchecked Sendable`: OK with documented constraints. Consider adding a doc
 note that consumers shouldn’t mutate theme objects post-initialization.
  - Add paragraph/line spacing defaults into `textAttributes` via `NSParagraphSt
yle` to get consistent multi-line layout without per-cell injection.

**SwiftUI (`GenMarkUI`)**
- `MarkdownView`:
  - Re-parses on every body evaluation. Introduce a small state/cache:
    - Keep `@State private var parsed: MarkdownDocument` and update in `onChange
(of: markdown)` to avoid re-parsing on unrelated state changes.
    - If you adopt source positions, use them for stable `id`s in `ForEach` inst
ead of indices to make streaming updates smoother.
- BlockRenderer:
  - Good separation. List marker logic is solid and readable; ordered lists comp
ute `start + index` (works).
- Tables:
  - IDs fixed to avoid collisions; nice. Consider introducing padding inside cel
ls instead of relying only on `.border(.secondary)` for readability.

**Tests**
- Strengths:
  - Broad coverage of GFM features: lists, headings, tables, code, parser option
s, html edge-cases.
  - Tables and task list checks validate important mappings.
- Improvements:
  - Remove or mark tests that only print without strong assertions (e.g., parts
of `GFMComplianceTests`, `FeatureDebugTests`) or convert prints to expectations.
 Excessive logs slow CI and reduce signal.
  - Unify resource loading in tests:
    - Prefer `Bundle.module` consistently; the Tuist test target already include
s resources. Mixing `Bundle.module` and `Bundle(for:)` is confusing.
  - Eliminate future/unsupported feature scaffolding:
    - The “highlight/mark” tests document behavior for a non-existent extension.
 Either mark them `@disabled("Not supported by swift-cmark")` or move them to do
cumentation-only, so test runs are crisp and intentional.

**Documentation & MCP**
- Implementation plan is strong and realistic; it doubles as living design docs.
- README/AGENTS.md promise an `mcp/` scaffold that isn’t present. Either add `mc
p/` with a minimal `README.md` and example config, or remove from docs to avoid
confusion until it lands.

**API Ergonomics**
- Aggregation import:
  - Many consumers will prefer `import GenMark` and a single surface; consider a
dding a tiny “umbrella” target `GenMark` that re-exports `GenMarkUI` (and maybe
`UIKit/Core` symbols), then update the Tuist target and SPM products.
- Environment-driven theming:
  - You pass theme in the initializer; offering `EnvironmentKey` for theme and a
n image loader will make view composition cleaner (and matches the plan).

**Performance & Streaming Readiness**
- Parser off-main + debounce:
  - Current `parse` runs inline. Add an async parse path that debounces input ch
anges and delivers results on main, then keep `MarkdownView` rendering purely fr
om the model state.
- Caching:
  - Add a basic attributed string cache keyed by inline subtree identity and cur
rent `UITraitCollection` to minimize rework on updates.
  - Measurement cache for paragraphs/headings to avoid `sizeThatFits` churn on u
nchanged content.
- Stable IDs:
  - As mentioned, add byte-range based IDs to nodes (`.sourcePos`) and use those
 for `ForEach`.
 
 
 
## Actionable Checklist

- [x] Build & Tooling
  - [x] Makefile: fix stray quote in `reload` target (`$(TUIST) generate"` → `$(TUIST) generate`).
  - [x] Makefile: add `open` target (`tuist generate && xed .`).
  - [x] Makefile: keep `reload` as `tuist generate` (no open).
  - [x] Tests runner: add consistent device parameterization (e.g., normalize `DEST_SIM`/`-destination`).
  - [x] Example app alignment: either remove `Examples/GenMarkExample` or update it to import `GenMarkUI` (or provide an umbrella `GenMark` product and update Tuist/SPM to include it).

- [ ] Core Parser (GenMarkCore)
  - [x] Change `CMarkParser` default options to safe defaults: `options: [.validateUTF8, .smart]` (remove `.unsafe`).
  - [x] Ensure `MarkdownView` and `CMarkParser` defaults are aligned.
  - [x] Remove `InlineNode.autolink`; treat autolinks as `.link` uniformly (update model and tests).
  - [x] Verify `<br>` handling: if cmark doesn’t normalize to breaks, map common HTML `<br>` variants to `.lineBreak` in inline mapping and update tests accordingly.
  - [x] Task items: drop string-based type checks; rely on `cmark_gfm_extensions_get_tasklist_item_checked` (confirm exact GFM node type if still needed).
  - [ ] Flatten container fallbacks in `mapBlock` to avoid nested `.document` nodes. (Decision: removed flattening logic to reduce complexity)
  - [ ] Add optional `range: Range<Int>` (source positions) to nodes; enable `CMARK_OPT_SOURCEPOS` in parsing and plumb through.
  - [x] Use `CInt` alias (or clearly documented type) for `ParserOptions` rawValue for clarity.
  - [x] Invalid URL handling: when a link URL is invalid, render child inline content as text instead of dropping it.

- [ ] UIKit/TextKit (GenMarkUIKit)
  - [ ] AttributedTextFactory: add a small paragraph style tweak (e.g., line height) for code spans/blocks.
  - [x] MarkdownTextView: update `sizeThatFits` to honor `proposal.width` only; return nil when unspecified (avoid `UIScreen.main.bounds.width`).
  - [x] MarkdownTextView: set `uiView.adjustsFontForContentSizeCategory = true`.
  - [ ] Streaming updates prep: preserve selection and mutate a shared `NSMutableAttributedString` instead of wholesale replacement.
  - [ ] Theme: pre-scale fonts with `UIFontMetrics` or provide helper to scale per `UITraitCollection`.
  - [x] Theme: document `@unchecked Sendable` constraints and discourage post-init mutation by consumers.
  - [x] Theme: add paragraph/line spacing defaults via `NSParagraphStyle` in `textAttributes`.

- [ ] SwiftUI (GenMarkUI)
  - [x] MarkdownView: add parsed-model state/cache (`@State private var parsed`) and update in `onChange(of: markdown)` to avoid unnecessary re-parsing.
  - [ ] Use source-position-based stable IDs for `ForEach` when available.
  - [x] Tables: add cell padding for readability (not only `.border(.secondary)`).

- [ ] Tests
  - [ ] Replace print-only tests with assertions (e.g., in `GFMComplianceTests`, `FeatureDebugTests`).
  - [ ] Unify test resources loading via `Bundle.module` consistently.
  - [ ] Mark unsupported/future features (e.g., “highlight/mark”) as disabled/skipped or move to docs.

- [ ] Documentation & MCP
  - [ ] Either add `mcp/` scaffold (README + example config) as promised in README/AGENTS.md or remove references until available.

- [ ] API Ergonomics
  - [ ] Add umbrella `GenMark` target that re-exports `GenMarkUI` (optionally UIKit/Core) and update Tuist/SPM products.
  - [ ] Add `EnvironmentKey` for theme and an image loader to allow environment-driven configuration.

- [ ] Performance & Streaming Readiness
  - [ ] Add an async parse path that debounces input changes off-main and delivers results on main.
  - [ ] Add attributed string cache keyed by inline subtree identity and current `UITraitCollection`.
  - [ ] Add measurement cache for paragraphs/headings to reduce repeated `sizeThatFits` work.
  - [ ] Add byte-range-based IDs to nodes (`.sourcePos`) and use them for `ForEach` stability.
