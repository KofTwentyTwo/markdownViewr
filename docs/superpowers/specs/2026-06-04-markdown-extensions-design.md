# Markdown Extensions Design

**Date:** 2026-06-04  
**Status:** Approved

## Overview

Add a Markdown tab to the Settings window that lets users toggle four inline
syntax extensions. Enabled extensions are applied via a post-processing pass
on the generated HTML.

## Extensions

| Syntax | Name | HTML output | Default |
|---|---|---|---|
| `==text==` | Highlight | `<mark>text</mark>` | on |
| `^text^` | Superscript | `<sup>text</sup>` | on |
| `~text~` | Subscript | `<sub>text</sub>` | on |
| `++text++` | Underline | `<ins>text</ins>` | on |

Strikethrough (`~~text~~`) is already handled at the parser level (swift-markdown
GFM extension) and is not part of this feature.

## Data Model

New `MarkdownExtensions` struct in its own file (`MarkdownExtensions.swift`):

```swift
struct MarkdownExtensions: Codable {
    var highlight: Bool = true
    var superscript: Bool = true
    var subscript_: Bool = true  // trailing underscore: `subscript` is a Swift keyword
    var underline: Bool = true
}
```

`ThemeManager` gets one new `@Published var markdownExtensions: MarkdownExtensions`
property. On `didSet` it encodes to JSON and writes to UserDefaults key
`markdownExtensions`. On init it reads and decodes from UserDefaults, falling
back to `MarkdownExtensions()` (all on) if the key is absent or malformed.

## Post-Processing

`MarkdownDocument` gains a private static `applyExtensions(_:extensions:) -> String`
helper. It is called as the final step of `convertToHTML`, after `HTMLConverter`
produces its output.

The helper splits the HTML on `<pre>` / `</pre>` boundaries. Segments inside
`<pre>` blocks are passed through unchanged. Segments outside have each enabled
extension's regex applied using `NSRegularExpression`.

Patterns (applied in the order listed):

| Extension | Regex | Replacement |
|---|---|---|
| Highlight | `==(.+?)==` | `<mark>$1</mark>` |
| Superscript | `\^(.+?)\^` | `<sup>$1</sup>` |
| Subscript | `~(.+?)~` | `<sub>$1</sub>` |
| Underline | `\+\+(.+?)\+\+` | `<ins>$1</ins>` |

`convertToHTML` signature gains one new parameter:

```swift
static func convertToHTML(
    _ markdown: String,
    frontmatterMode: FrontmatterMode = .hide,
    extensions: MarkdownExtensions = MarkdownExtensions()
) -> String
```

All existing callers that omit `extensions` get the all-on defaults.

## Settings UI

A fourth tab is added to the `TabView` in `SettingsView`:

- Label: "Markdown", system image: `doc.plaintext`
- New struct `MarkdownSettingsView` in `SettingsView.swift`
- One `GroupBox` containing a `VStack` of four rows
- Each row: extension name (left), example syntax in secondary monospaced text
  (center), `Toggle` with `.checkbox` style (right)
- Toggling writes through `themeManager.markdownExtensions` immediately

## Re-render Trigger

`ContentView` already observes `themeManager` via `@EnvironmentObject` and
re-renders on published changes. Adding `onReceive(themeManager.$markdownExtensions)`
(same pattern as `frontmatterMode`) triggers a re-render when any toggle changes.
No restart required.

## Theme Color: Highlight

`<mark>` has a browser-default yellow background that looks wrong on dark themes.
`ThemeColors` gets two new fields:

```swift
var highlightBackground: String   // default: "#ffd700" (gold — readable on dark)
var highlightText: String         // default: "#1e1e2e" (dark — pairs with gold bg)
```

`ThemeManager.generateCSS` emits `--highlight-bg` and `--highlight-text` CSS
variables. The HTML template adds:

```css
mark {
    background-color: var(--highlight-bg);
    color: var(--highlight-text);
    border-radius: 2px;
    padding: 0 2px;
}
```

All 20 built-in theme JSON files get the two new color fields with
theme-appropriate values. The Theme Editor color list gains a "Highlight"
section (background + text), matching the existing "Code" section layout.

User themes that predate this change omit these fields in their JSON. Swift's
auto-synthesized `Decodable` throws on missing keys, so `ThemeColors` needs a
custom `init(from decoder:)` that uses `decodeIfPresent` for the two new fields
and falls back to the `ThemeColors.init` defaults when absent.

## Files Changed

| File | Change |
|---|---|
| `MarkdownExtensions.swift` | New — struct definition |
| `Theme.swift` | Add `highlightBackground`, `highlightText` to `ThemeColors` |
| `ThemeManager.swift` | Add `markdownExtensions` published property; emit `--highlight-bg`/`--highlight-text` in `generateCSS` |
| `MarkdownDocument.swift` | Add `applyExtensions` helper, update `convertToHTML` signature |
| `SettingsView.swift` | Add `MarkdownSettingsView`, add Markdown tab |
| `ContentView.swift` | Add `onReceive` for `markdownExtensions` |
| `ThemeEditorView.swift` | Add Highlight color pickers |
| `Resources/template.html` | Add `mark { … }` CSS rule |
| `Resources/themes/*.json` (×20) | Add `highlightBackground` + `highlightText` per theme |
