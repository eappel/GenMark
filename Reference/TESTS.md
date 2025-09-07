**Summary**
- Core parsing in `GenMarkCore` has decent basic coverage; many GFM features are
 exercised.
- Several tests are exploratory (print-only) with limited assertions, reducing t
heir value.
- UI rendering layers (`GenMarkUI`, `GenMarkUIKit`) have zero unit tests.
- Important parser behaviors and edge cases remain untested.

**What’s Covered (Core)**
- Headings and paragraphs: levels and basic mapping.
- Lists: bullet, ordered (including non-1 starts), task lists with checked state
.
- Inline styles: strong, emphasis, strikethrough (via GFM), code.
- Links and images: basic link detection and explicit links; basic image URL map
ping.
- Tables: parsing, header/rows, alignment from fixtures, code pipes in cells.
- Parser options: smoke checks for `.smart`, `.hardBreaks`, `.noBreaks`, `.unsaf
e`, `.validateUTF8` across fixtures.
- HTML inline `<br>` interpreted as line breaks (covered indirectly via fixtures
).

**Untested Core Functionality**
- Block-level nodes:
  - Block quotes: mapping and rendering of nested content.
  - Thematic breaks: presence and mapping to `.thematicBreak`.
  - HTML blocks: `.HTML_BLOCK` is intentionally dropped; no test asserts this be
havior (safe vs unsafe).
- Inline node edge behavior:
  - Links with invalid URLs: fallback to plain text using child inlines.
  - Images with invalid URLs: fallback to alt text or URL string.
  - Autolink coverage gaps: “www.example.com” and email mailto format assertions
 (currently only printed).
  - HTML inline variants: `<br/>`, `<br />`, case-insensitive handling.
- Parser configurations:
  - `.sourcePos`: never asserted (even presence in model if/when supported later
).
  - Factory initializers: `.minimal()`, `.standard()`, `.maximal()` behavior equ
ivalence to explicit options.
  - `.unsafe` vs `.tagfilter`: explicit assertions for filtering/allowing HTML c
ontent.
  - `.noBreaks`: specific assertion that soft breaks render as spaces rather tha
n preserved breaks.
- Tree transformation:
  - `flattenBlocks(_:)` behavior: prevents nested `.document` nodes; currently u
nverified.
- Fallback pathways:
  - Unknown/unsupported nodes fallback mapping to paragraphs/documents; no tests
 exercise this.

**Untested UI Layers**
- `AttributedTextFactory`:
  - Text: base attributes applied.
  - Emphasis/strong: font trait mutation preserves size/family; attributes merge
d correctly.
  - Strikethrough: attribute presence on range.
  - Code: `theme.codeAttributes` applied; no bleed-through.
  - Links: `.link` attribute applied to child text range; nested children styles
 preserved.
  - Images: alt text fallback and default behavior.
  - `inlineCustomizer`: returns override attributes when provided, no override w
hen nil.
- `MarkdownTheme`:
  - `headingAttributes(for:)` returns correct set (1–6).
  - `.systemDefault` contains expected defaults (spot-check critical keys).
- `OpenURLMarkdownTextView`:
  - Non-editable, non-scrollable, zero insets, link attributes cleared, sizeThat
Fits correctness.
  - Coordinator: intercepts URL taps (can be verified via delegate method unit t
est).
- `MarkdownView`:
  - Minimal vs default parsing (e.g., strikethrough absent in `.minimal`).
  - Lists render markers correctly (bullet vs ordered vs task checkboxes).
  - Table rendering alignment applied to attributed text (paragraph style alignm
ent).

**Existing Tests That Need Stronger Assertions**
- `FeatureDebugTests`:
  - `testSmartTypographyActuallyWorks` only prints; assert that smart vs regular
 output differ and contain expected Unicode curly quotes/dashes.
  - `testAvailableExtensions` only prints; assert per-extension expectations (e.
g., table presence, task list kind, strikethrough inline).
  - `testParserOptionsActualEffect` only prints; assert counts of soft vs hard b
reaks, and `.noBreaks` behavior.
  - `testHTMLParsing` only prints; assert `<br>` becomes `.lineBreak` and that n
on-`<br>` HTML is treated as text for safe mode.
- `GFMComplianceTests`:
  - `test_autolink_www`, `test_autolink_email`, `test_tagfilter_dangerous_tags`,
 `test_list_item_with_multiple_paragraphs`, `test_footnote_reference`: convert p
rints to assertions (where applicable). Footnotes not supported: assert treated
as text.

**Edge Cases To Add**
- Block-level:
  - Block quotes: nested quotes, lists inside quotes, multiple child paragraphs.
  - Thematic breaks: ensure `.thematicBreak` produced and rendered distinctly.
  - HTML blocks: verify dropped even with `.unsafe` (documented behavior).
- Inline:
  - `LINK`: invalid URLs (e.g., malformed scheme) returns `.text` with children’
s text.
  - `IMAGE`: invalid URL returns `.text(alt)` or URL string when alt missing.
  - `<br>` variants: `<br>`, `<br/>`, `<br />` in mixed case produce `.lineBreak
`.
  - Mixed/nested formatting: emphasis within strong and vice versa; link inside
strong/emphasis; code inside strong etc.
  - Autolink: assert detection of `www.example.com` and emails into `.link` with
 expected `mailto:` prefix.
- Lists:
  - Mixed task and non-task items: list kind becomes `.task` and non-task items
have `checked == nil`.
  - Multi-paragraph items: assert item.children has multiple blocks.
- Tables:
  - No explicit header section fallback: first row used as header.
  - Alignment correctness across more than 3 columns and empty cells.
  - Inline content preservation: nested strong/emphasis/code within cells.
- Parser options:
  - `.minimal()`: no strikethrough, no autolink, no tables; assert fallback vs e
nabled cases.
  - `.standard()`: equivalent to enabling all GFM extensions without `.smart`.
  - `.maximal()`: same as default init (all GFM + smart/validateUTF8).
  - `.noBreaks`: ensure no `.lineBreak` nodes and text joined with spaces.
  - `.unsafe` + inline HTML not `<br>`: remains as text; document intended behav
ior.
- Fallbacks/robustness:
  - Empty input → document with 0 blocks.
  - Only HTML comment or unsupported HTML → empty or text per intended mapping.
  - Very long input fixture: parser does not crash, basic invariants hold.

**Proposed Test Additions**
- Core (within `GenMarkCoreTests`):
  - BlockquoteMappingTests
  - ThematicBreakTests
  - HTMLBlocksFilteringTests (safe vs unsafe assertions)
  - InlineFallbackTests (invalid link/image)
  - HTMLInlineBreakVariantsTests (<br>, <br/>, <br />)
  - ParserInitializersTests (minimal/standard/maximal behavior)
  - NoBreaksOptionTests (explicit assertions)
  - FlattenBlocksTests (no nested document nodes)
- UI (new targets):
  - `GenMarkUIKitTests`:
    - AttributedTextFactoryTests: per-inline assertions; link range attributes;
font trait preservation; inlineCustomizer behavior.
    - MarkdownThemeTests: headingAttributes and default keys sanity checks.
    - OpenURLMarkdownTextViewTests: UITextView config; `sizeThatFits`; delegate
link tap callback intercepted.
  - `GenMarkUITests` (unit, not UI test bundle):
    - MarkdownViewTests: minimal vs default differences; list markers output; ta
ble cell alignment applied via paragraph style in attributed strings.

**Coverage Measurement Recommendations**
- Enable code coverage in Tuist/Xcode scheme and run `make test` with `-enableCo
deCoverage YES`, then inspect coverage in Xcode reports.
- Consider adding a CI job that generates `.xcresult` coverage and uploads summa
ry (e.g., `xccov` export) for trend tracking.

## TODOs

When implementing tests:
- Look at ./swift-cmark-reference.txt for a full reference to the cmark repository
- Run `make test` to ensure tests compile and pass

- Strengthen Existing Tests
  - [x] Convert `FeatureDebugTests.testSmartTypographyActuallyWorks` to assert smart vs regular outputs differ and contain curly quotes/dashes.
  - [x] Replace prints with assertions in `FeatureDebugTests.testAvailableExtensions` (table presence, task list kind, strikethrough inline, autolink).
  - [x] In `FeatureDebugTests.testParserOptionsActualEffect`, assert soft vs hard break counts and `.noBreaks` joining behavior.
  - [x] In `FeatureDebugTests.testHTMLParsing`, assert `<br>` maps to `.lineBreak` and non-`<br>` HTML is treated as text in safe mode.
  - [x] In `GFMComplianceTests.test_autolink_www`, assert that `www.*` becomes a `.link` inline.
  - [x] In `GFMComplianceTests.test_autolink_email`, assert `mailto:` URL or linked email.
  - [x] In `GFMComplianceTests.test_tagfilter_dangerous_tags`, assert dangerous tags are filtered/escaped (no executable HTML).
  - [x] In `GFMComplianceTests.test_list_item_with_multiple_paragraphs`, assert multiple block children exist in first list item.
  - [x] Update `GFMComplianceTests.test_footnote_reference` to assert footnotes are treated as plain text (unsupported).

- Core Parsing: New Tests
  - [x] BlockquoteMappingTests: nested quotes, lists in quotes, multiple paragraphs inside quote.
  - [x] ThematicBreakTests: assert mapping to `.thematicBreak`.
  - [x] HTMLBlocksFilteringTests: assert HTML blocks are dropped in both safe and unsafe modes.
  - [x] InlineFallbackTests: invalid link URL falls back to children text/plain; invalid image URL yields alt or URL text.
  - [x] HTMLInlineBreakVariantsTests: `<br>`, `<br/>`, `<br />` (any case) map to `.lineBreak`.
  - [x] MixedInlineNestingTests: emphasis within strong, link inside emphasis/strong, code combined with emphasis/strong.
  - [x] AutolinkDetectionTests: assert autolink for `www.example.com` and email addresses to `.link` (with `mailto:` for emails).
  - [x] ListsKindResolutionTests: mixed task/non-task items → `.task` kind; non-task items have `checked == nil`.
  - [x] ListItemsMultiParagraphTests: assert multiple block children inside list item.
  - [x] TableHeaderFallbackTests: first row used as header when explicit header node missing.
  - [x] TableAlignmentWideTests: verify alignment across >3 columns and handling of empty cells.
  - [x] TableInlinePreservationTests: nested strong/emphasis/code preserved inside cells.
  - [x] ParserInitializersTests: `.minimal()` = no GFM (no strikethrough/tables/autolink); `.standard()` = all GFM without smart; `.maximal()` equals default initializer behavior.
  - [x] NoBreaksOptionTests: ensure no `.lineBreak` nodes and text joined with spaces.
  - [x] UnsafeInlineHTMLTests: inline HTML other than `<br>` remains text even with `.unsafe` (confirm intended behavior).
  - [x] FlattenBlocksTests: assert no nested `.document` nodes after parsing (flattening works).
  - [x] FallbackRobustnessTests: empty input → 0 blocks; unsupported HTML/comment handling; very long input parses without crash.

- UI Layer: New Tests
  - [ ] Create `GenMarkUIKitTests` target (configure in Package.swift/Tuist).
  - [ ] AttributedTextFactoryTests: base text attributes applied.
  - [ ] AttributedTextFactoryTests: emphasis adds italic trait; strong adds bold; font size/family preserved.
  - [ ] AttributedTextFactoryTests: strikethrough attributes applied on correct ranges.
  - [ ] AttributedTextFactoryTests: code attributes applied without bleed-through.
  - [ ] AttributedTextFactoryTests: `.link` attribute set on correct range; nested styles preserved.
  - [ ] AttributedTextFactoryTests: images render alt text fallback when present.
  - [ ] AttributedTextFactoryTests: `inlineCustomizer` overrides attributes when provided; leaves defaults otherwise.
  - [ ] MarkdownThemeTests: `headingAttributes(for:)` returns correct sets for levels 1–6.
  - [ ] MarkdownThemeTests: `.systemDefault` contains expected keys (text, headings, code, links, strikethrough).
  - [ ] OpenURLMarkdownTextViewTests: verify UITextView config (non-editable, non-scrollable, zero insets, cleared linkTextAttributes).
  - [ ] OpenURLMarkdownTextViewTests: `sizeThatFits` respects proposed width and computes height.
  - [ ] OpenURLMarkdownTextViewTests: Coordinator intercepts link taps (delegate callback observed).
  - [ ] Create `GenMarkUITests` (unit) for SwiftUI components.
  - [ ] MarkdownViewTests: `.minimal` vs default parsing differences (e.g., no strikethrough in minimal).
  - [ ] MarkdownViewTests: list markers render bullet/ordered indices/task checkboxes correctly.
  - [ ] MarkdownViewTests: table headers apply paragraph style alignment to attributed strings.

- Coverage & CI
  - [ ] Enable code coverage in Tuist/Xcode test scheme.
  - [ ] Update `make test` to pass `-enableCodeCoverage YES` or configure coverage via Tuist project.
  - [ ] Add CI job to archive `.xcresult` and export coverage using `xccov`.
  - [ ] Track coverage trend and set minimum thresholds.
