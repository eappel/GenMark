# Parser Options and Extensions Test

This fixture demonstrates various parser options and GFM extensions added to GenMark.

## Text Emphasis

This text has **bold emphasis** using markdown syntax. It renders with increased font weight.

Multiple emphases: **first**, *second*, and ***third*** in the same line.

Nested formatting combinations:
- ***Bold and italic***
- **Bold with `code`**  
- *Italic with `code`*
- ~~**Strikethrough and bold**~~

## Smart Typography (.smart option)

When enabled, smart typography converts:

### Quotes
- "Double quotes" → curly double quotes
- 'Single quotes' → curly single quotes  
- Nested "quotes with 'inner' quotes" work too

### Dashes
- Em dash---three hyphens
- En dash--two hyphens
- Regular dash - single hyphen (unchanged)

### Apostrophes
- It's automatic
- Don't worry about it
- '90s style
- Rock 'n' roll

### Ellipsis
- Three dots... become ellipsis

## Line Break Options

### Default Behavior
Line one
Line two
(soft break - renders as space)

### Hard Breaks (.hardBreaks option)
When enabled, every line break
becomes a hard break
like this.

### No Breaks (.noBreaks option)  
When enabled,
all soft breaks
become spaces
joining lines together.

### Line Break Examples
First line  
Second line (with two spaces before break)  
Third line

## Markdown-Only Features

### Standard Markdown Formatting
This has **bold markdown**, *italic markdown*, and ***bold italic***.

You can combine different formatting styles.

### Block Elements
> This is a blockquote using markdown syntax.
> It can span multiple lines.

```
This is a code block
with multiple lines
```

## Strikethrough Variations

Standard: ~~strikethrough text~~

With spaces: ~~ spaced strikethrough ~~

Single tilde: ~not strikethrough~

Triple tilde: ~~~also strikethrough~~~

## Autolink Extension

Plain URLs get linked automatically:
- https://github.com
- http://example.com
- www.google.com
- ftp://files.example.com

Email addresses too:
- user@example.com
- support@company.org

## Combined Features Demo

This paragraph has it all: **emphasized text** with **bold**, _italic_, ~~strikethrough~~, `inline code`, [regular links](https://example.com), https://autolinks.com, and  
line breaks. "Smart quotes" and dashes---all working together!

### Task List with Formatting
- [ ] **Important** task
- [x] ~~Completed~~ task  
- [ ] Task with `code` and **bold**
- [x] Task with [link](https://example.com)

### Table with Formatting
| Feature | Status | Notes |
|---------|:------:|------:|
| **Bold** | ✅ | CommonMark |
| ~~Strike~~ | ✅ | Standard GFM |
| *Italic* | ✅ | CommonMark |
| `Code` | ✅ | CommonMark |
| Links | ✅ | Standard |

## Edge Cases

Empty emphasis: ****

Unclosed brackets: [This is unclosed

Overlapping: **start ~~strike** end~~

Nested emphasis: **outer *inner* outer**

## Parser Validation

UTF-8 validation (.validateUTF8 option):
- English: Hello World
- Japanese: こんにちは世界
- Chinese: 你好世界
- Korean: 안녕하세요 세계
- Arabic: مرحبا بالعالم
- Hebrew: שלום עולם
- Emoji: 🌍🌎🌏 💻📱🖥️
- Math: ∑∫∂∇≈≠≤≥

## Extension Configuration

With only specific extensions enabled:
- `["strikethrough", "autolink"]` - tables won't work
- `["table", "tasklist"]` - strikethrough won't work  
- `[]` - only CommonMark features

This allows fine-grained control over which features are available.