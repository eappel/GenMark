# GenMark – Full GFM Showcase

> Blockquote with **bold**, _italic_, `inline code`, and ~~strikethrough~~.

---

## Text Formatting

This text has **bold content** using markdown syntax. You can also *emphasize multiple* different **sections** in the same paragraph.

## Line Breaks

Here's a line with a soft break
This text continues on the same line.

Two spaces at the end of this line  
This creates a hard line break.

## Smart Typography

When smart typography is enabled:
- "Double quotes" become curly quotes
- 'Single quotes' too
- Three dashes---become em dash
- Two dashes--become en dash
- It's smart about apostrophes

## Lists

- Bullet one
- Bullet two with a [link](https://example.com) and <https://apple.com>

1. Ordered one
2. Ordered two with `code`

- [ ] Task unchecked
- [x] Task checked

## Table

| Left | Center | Right |
|:-----|:------:|------:|
| L1   |  C1    |   R1  |
| L2 **bold** | _C2 italic_ | `R2 code` |

## Code Block

```
let greeting = "Hello, world!"
print(greeting)
```

## Images

Basic remote image:

![Lorem picsum](https://picsum.photos/200/300)

Image with explicit alt text and caption:

![Swift logo](https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Swift_logo.svg/512px-Swift_logo.svg.png)

_Figure 1:_ Swift logo fetched over the network.

## Footnotes

Here is a footnote reference.[^1]

[^1]: This is the footnote definition.

## Mixed Formatting

This paragraph combines ==highlighted text== with **bold**, _italic_, ~~strikethrough~~, and `inline code`. You can even have ==**bold highlight**== or ==_italic highlight_== combinations.

## Line Breaks Examples

Soft break (normal):
This line
continues here.

Hard break (two spaces at end of line):  
This line  
has hard breaks.

HTML break:<br>
This uses HTML break tag.

## Edge Cases

Empty highlight: ==== (should not highlight)

Unclosed highlight: ==This is unclosed

Nested formatting: **Bold with _italic_ and ~~strike~~ and ==highlight==**

## Parser Options Demo

With `.hardBreaks` option:
Each line
would become
a separate line.

With `.noBreaks` option:
All lines
would join
as one paragraph.

With `.smart` option:
"Quotes" and it's --- great -- really!
