# Markdown Extensions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four toggleable inline markdown extensions (highlight, superscript, subscript, underline) with a Markdown settings tab, a theme-aware highlight color, and a post-processing HTML pass.

**Architecture:** A new `MarkdownExtensions` struct holds four booleans stored in UserDefaults via `ThemeManager`. `MarkdownDocument.convertToHTML` runs a post-processing pass (skipping `<pre>` blocks) after the swift-markdown AST walk. `ThemeColors` gains `highlightBackground`/`highlightText` fields (with a custom decoder for backward compatibility) that feed CSS variables used by `mark {}` in the HTML template.

**Tech Stack:** SwiftUI, AppKit (NSWindow), swift-markdown 0.7.3, NSRegularExpression, UserDefaults, XcodeGen (sources glob — new Swift files auto-included, no regeneration needed).

---

### Task 1: MarkdownExtensions struct + ThemeColors highlight fields

**Files:**
- Create: `markdownViewr/MarkdownExtensions.swift`
- Modify: `markdownViewr/Theme.swift`

- [ ] **Step 1: Create `markdownViewr/MarkdownExtensions.swift`**

```swift
import Foundation

struct MarkdownExtensions: Codable {
    var highlight: Bool = true
    var superscript: Bool = true
    var subscript_: Bool = true  // trailing underscore: `subscript` is a Swift keyword
    var underline: Bool = true
}
```

- [ ] **Step 2: Add `highlightBackground` and `highlightText` to `ThemeColors` in `Theme.swift`**

Add the two new properties after `blockquoteBackground`:

```swift
    var blockquoteBackground: String
    var highlightBackground: String
    var highlightText: String
```

Update the `init(...)` signature and body to include them after `blockquoteBackground`:

```swift
    init(
        background: String = "#1e1e2e",
        text: String = "#cdd6f4",
        heading1: String = "#cba6f7",
        heading2: String = "#89b4fa",
        heading3: String = "#89b4fa",
        heading4: String = "#74c7ec",
        heading5: String = "#74c7ec",
        heading6: String = "#74c7ec",
        link: String = "#89dceb",
        codeBackground: String = "#181825",
        codeText: String = "#a6e3a1",
        blockquoteBorder: String = "#cba6f7",
        blockquoteBackground: String = "#252535",
        highlightBackground: String = "#ffd700",
        highlightText: String = "#1a1a1a"
    ) {
        self.background = background
        self.text = text
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.link = link
        self.codeBackground = codeBackground
        self.codeText = codeText
        self.blockquoteBorder = blockquoteBorder
        self.blockquoteBackground = blockquoteBackground
        self.highlightBackground = highlightBackground
        self.highlightText = highlightText
    }
```

- [ ] **Step 3: Add explicit `CodingKeys` and custom `init(from:)` to `ThemeColors` for backward compatibility**

Existing user theme JSONs don't have these fields. Swift's auto-synthesized decoder throws on missing keys, so add the following inside `struct ThemeColors`:

```swift
    enum CodingKeys: String, CodingKey {
        case background, text
        case heading1, heading2, heading3, heading4, heading5, heading6
        case link, codeBackground, codeText
        case blockquoteBorder, blockquoteBackground
        case highlightBackground, highlightText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = try c.decode(String.self, forKey: .background)
        text = try c.decode(String.self, forKey: .text)
        heading1 = try c.decode(String.self, forKey: .heading1)
        heading2 = try c.decode(String.self, forKey: .heading2)
        heading3 = try c.decode(String.self, forKey: .heading3)
        heading4 = try c.decode(String.self, forKey: .heading4)
        heading5 = try c.decode(String.self, forKey: .heading5)
        heading6 = try c.decode(String.self, forKey: .heading6)
        link = try c.decode(String.self, forKey: .link)
        codeBackground = try c.decode(String.self, forKey: .codeBackground)
        codeText = try c.decode(String.self, forKey: .codeText)
        blockquoteBorder = try c.decode(String.self, forKey: .blockquoteBorder)
        blockquoteBackground = try c.decode(String.self, forKey: .blockquoteBackground)
        highlightBackground = try c.decodeIfPresent(String.self, forKey: .highlightBackground) ?? "#ffd700"
        highlightText = try c.decodeIfPresent(String.self, forKey: .highlightText) ?? "#1a1a1a"
    }
```

- [ ] **Step 4: Build to verify**

```bash
just build
```

Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add markdownViewr/MarkdownExtensions.swift markdownViewr/Theme.swift
git commit -m "add MarkdownExtensions struct and highlight color fields to ThemeColors"
```

---

### Task 2: ThemeManager — extensions property and CSS variables

**Files:**
- Modify: `markdownViewr/ThemeManager.swift`

- [ ] **Step 1: Add `markdownExtensions` as the last `@Published` property in `ThemeManager`**

Add after the `frontmatterMode` property block (around line 21–26):

```swift
    @Published var markdownExtensions: MarkdownExtensions {
        didSet {
            if let data = try? JSONEncoder().encode(markdownExtensions) {
                UserDefaults.standard.set(data, forKey: "markdownExtensions")
            }
        }
    }
```

- [ ] **Step 2: Initialize `markdownExtensions` in `ThemeManager.init()`**

In the `init()` body, after the `frontmatterMode` initialization, add:

```swift
        if let data = UserDefaults.standard.data(forKey: "markdownExtensions"),
           let ext = try? JSONDecoder().decode(MarkdownExtensions.self, from: data) {
            self.markdownExtensions = ext
        } else {
            self.markdownExtensions = MarkdownExtensions()
        }
```

- [ ] **Step 3: Add `--highlight-bg` and `--highlight-text` to `generateCSS`**

In `generateCSS(for:)`, inside the `:root {` block, add these two lines after `--blockquote-bg`:

```swift
            --highlight-bg: \(theme.colors.highlightBackground);
            --highlight-text: \(theme.colors.highlightText);
```

- [ ] **Step 4: Build to verify**

```bash
just build
```

Expected: build succeeds.

---

### Task 3: HTML template — `mark` CSS rule

**Files:**
- Modify: `markdownViewr/Resources/template.html`

- [ ] **Step 1: Add `mark` rule to `base-css` in `template.html`**

After the `del { opacity: 0.6; }` rule (around line 223–225), add:

```css
mark {
    background-color: var(--highlight-bg);
    color: var(--highlight-text);
    border-radius: 2px;
    padding: 0 2px;
}
```

Note: find marks created by the in-page find feature use inline styles that override this rule, so there is no conflict.

- [ ] **Step 2: Build to verify**

```bash
just build
```

Expected: build succeeds.

---

### Task 4: Update built-in theme JSON files

**Files:**
- Modify: all 20 files in `markdownViewr/Resources/themes/`

Each file needs `"highlightBackground"` and `"highlightText"` added inside the `"colors"` object, after `"blockquoteBackground"`.

- [ ] **Step 1: Update `catppuccin-mocha.json`** (dark)

Add after `"blockquoteBackground"`:
```json
        "highlightBackground": "#f9e2af",
        "highlightText": "#1e1e2e"
```

- [ ] **Step 2: Update `catppuccin-latte.json`** (light)

```json
        "highlightBackground": "#f9e2af",
        "highlightText": "#4c4f69"
```

- [ ] **Step 3: Update `dracula.json`** (dark)

```json
        "highlightBackground": "#f1fa8c",
        "highlightText": "#282a36"
```

- [ ] **Step 4: Update `everforest-dark.json`** (dark)

```json
        "highlightBackground": "#dbbc7f",
        "highlightText": "#2d353b"
```

- [ ] **Step 5: Update `github-dark.json`** (dark)

```json
        "highlightBackground": "#e3b341",
        "highlightText": "#0d1117"
```

- [ ] **Step 6: Update `github-light.json`** (light)

```json
        "highlightBackground": "#fff8c5",
        "highlightText": "#1f2328"
```

- [ ] **Step 7: Update `gruvbox-dark.json`** (dark)

```json
        "highlightBackground": "#fabd2f",
        "highlightText": "#282828"
```

- [ ] **Step 8: Update `gruvbox-light.json`** (light)

```json
        "highlightBackground": "#fabd2f",
        "highlightText": "#282828"
```

- [ ] **Step 9: Update `kanagawa.json`** (dark)

```json
        "highlightBackground": "#ff9e3b",
        "highlightText": "#1f1f28"
```

- [ ] **Step 10: Update `monokai.json`** (dark)

```json
        "highlightBackground": "#e6db74",
        "highlightText": "#272822"
```

- [ ] **Step 11: Update `nord.json`** (dark)

```json
        "highlightBackground": "#ebcb8b",
        "highlightText": "#2e3440"
```

- [ ] **Step 12: Update `one-dark.json`** (dark)

```json
        "highlightBackground": "#e5c07b",
        "highlightText": "#282c34"
```

- [ ] **Step 13: Update `one-light.json`** (light)

```json
        "highlightBackground": "#ffd700",
        "highlightText": "#383a42"
```

- [ ] **Step 14: Update `rose-pine.json`** (dark)

```json
        "highlightBackground": "#f6c177",
        "highlightText": "#191724"
```

- [ ] **Step 15: Update `rose-pine-dawn.json`** (light)

```json
        "highlightBackground": "#f6c177",
        "highlightText": "#575279"
```

- [ ] **Step 16: Update `solarized-dark.json`** (dark)

```json
        "highlightBackground": "#b58900",
        "highlightText": "#002b36"
```

- [ ] **Step 17: Update `solarized-light.json`** (light)

```json
        "highlightBackground": "#b58900",
        "highlightText": "#fdf6e3"
```

- [ ] **Step 18: Update `tokyo-night.json`** (dark)

```json
        "highlightBackground": "#e0af68",
        "highlightText": "#1a1b26"
```

- [ ] **Step 19: Update `tokyo-night-light.json`** (light)

```json
        "highlightBackground": "#f9c859",
        "highlightText": "#343b58"
```

- [ ] **Step 20: Update `zenburn.json`** (dark)

```json
        "highlightBackground": "#f0dfaf",
        "highlightText": "#3f3f3f"
```

- [ ] **Step 21: Build to verify**

```bash
just build
```

Expected: build succeeds.

- [ ] **Step 22: Commit**

```bash
git add markdownViewr/ThemeManager.swift markdownViewr/Resources/template.html markdownViewr/Resources/themes/
git commit -m "add highlight CSS variable, mark rule, and highlight colors to all built-in themes"
```

---

### Task 5: MarkdownDocument — post-processing pass

**Files:**
- Modify: `markdownViewr/MarkdownDocument.swift`

- [ ] **Step 1: Update `convertToHTML` signature to accept `extensions`**

Change the function signature from:

```swift
    static func convertToHTML(_ markdown: String, frontmatterMode: FrontmatterMode = .hide) -> String {
```

to:

```swift
    static func convertToHTML(_ markdown: String, frontmatterMode: FrontmatterMode = .hide, extensions: MarkdownExtensions = MarkdownExtensions()) -> String {
```

- [ ] **Step 2: Call `applyExtensions` as the last step in `convertToHTML`**

At the end of `convertToHTML`, change the final two lines from:

```swift
        var htmlVisitor = HTMLConverter()
        html += htmlVisitor.visit(document)
        return html
```

to:

```swift
        var htmlVisitor = HTMLConverter()
        html += htmlVisitor.visit(document)
        return applyExtensions(html, extensions: extensions)
```

- [ ] **Step 3: Add the three private static helpers at the bottom of `MarkdownDocument`** (before the closing brace, after `escapeHTML`)

```swift
    private static func applyExtensions(_ html: String, extensions: MarkdownExtensions) -> String {
        // Split on <pre>...</pre> blocks so code blocks are never transformed.
        var segments = html.components(separatedBy: "<pre>")
        for i in 0..<segments.count {
            if i == 0 {
                segments[i] = applyExtensionRegexes(segments[i], extensions: extensions)
            } else {
                // Each segment begins with the pre block content up to </pre>,
                // followed by regular content.
                if let endRange = segments[i].range(of: "</pre>") {
                    let preContent = String(segments[i][..<endRange.upperBound])
                    let afterPre = applyExtensionRegexes(
                        String(segments[i][endRange.upperBound...]),
                        extensions: extensions
                    )
                    segments[i] = preContent + afterPre
                }
            }
        }
        return segments.joined(separator: "<pre>")
    }

    private static func applyExtensionRegexes(_ text: String, extensions: MarkdownExtensions) -> String {
        var result = text
        if extensions.highlight {
            result = applyRegex(result, pattern: "==(.+?)==", template: "<mark>$1</mark>")
        }
        if extensions.superscript {
            result = applyRegex(result, pattern: "\\^(.+?)\\^", template: "<sup>$1</sup>")
        }
        if extensions.subscript_ {
            result = applyRegex(result, pattern: "~(.+?)~", template: "<sub>$1</sub>")
        }
        if extensions.underline {
            result = applyRegex(result, pattern: "\\+\\+(.+?)\\+\\+", template: "<ins>$1</ins>")
        }
        return result
    }

    private static func applyRegex(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
```

- [ ] **Step 4: Build to verify**

```bash
just build
```

Expected: build succeeds.

---

### Task 6: ContentView — wire extensions into rerender

**Files:**
- Modify: `markdownViewr/ContentView.swift`

- [ ] **Step 1: Update `rerender()` to pass `extensions`**

Change:

```swift
    private func rerender() {
        renderedHTML = MarkdownDocument.convertToHTML(currentMarkdown, frontmatterMode: themeManager.frontmatterMode)
    }
```

to:

```swift
    private func rerender() {
        renderedHTML = MarkdownDocument.convertToHTML(
            currentMarkdown,
            frontmatterMode: themeManager.frontmatterMode,
            extensions: themeManager.markdownExtensions
        )
    }
```

- [ ] **Step 2: Add `onReceive` for `markdownExtensions`**

After the existing `.onReceive(themeManager.$frontmatterMode)` block, add:

```swift
        .onReceive(themeManager.$markdownExtensions) { _ in
            DispatchQueue.main.async { rerender() }
        }
```

- [ ] **Step 3: Build to verify**

```bash
just build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add markdownViewr/MarkdownDocument.swift markdownViewr/ContentView.swift
git commit -m "add post-processing pass for markdown extensions (highlight, superscript, subscript, underline)"
```

---

### Task 7: Settings UI — Markdown tab

**Files:**
- Modify: `markdownViewr/SettingsView.swift`

- [ ] **Step 1: Add `MarkdownSettingsView` struct to `SettingsView.swift`**

Add this new struct before the `ThemeEditorItem` struct (before line 265):

```swift
struct MarkdownSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Markdown Extensions")
                .font(.headline)
                .padding(.bottom, 8)

            Text("Enable or disable inline syntax extensions applied during rendering.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            GroupBox {
                VStack(spacing: 0) {
                    extensionRow(
                        name: "Highlight",
                        example: "==text==",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.highlight },
                            set: { themeManager.markdownExtensions.highlight = $0 }
                        )
                    )
                    Divider().padding(.vertical, 6)
                    extensionRow(
                        name: "Superscript",
                        example: "^text^",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.superscript },
                            set: { themeManager.markdownExtensions.superscript = $0 }
                        )
                    )
                    Divider().padding(.vertical, 6)
                    extensionRow(
                        name: "Subscript",
                        example: "~text~",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.subscript_ },
                            set: { themeManager.markdownExtensions.subscript_ = $0 }
                        )
                    )
                    Divider().padding(.vertical, 6)
                    extensionRow(
                        name: "Underline",
                        example: "++text++",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.underline },
                            set: { themeManager.markdownExtensions.underline = $0 }
                        )
                    )
                }
                .padding(4)
            }

            Spacer()
        }
        .padding(20)
    }

    private func extensionRow(name: String, example: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(name)
                .frame(width: 100, alignment: .leading)
            Text(example)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Add the Markdown tab to `SettingsView`**

In `SettingsView.body`, add the new tab after the Themes tab:

```swift
            MarkdownSettingsView()
                .tabItem {
                    Label("Markdown", systemImage: "doc.plaintext")
                }
```

- [ ] **Step 3: Build to verify**

```bash
just build
```

Expected: build succeeds.

---

### Task 8: Theme Editor — highlight color pickers

**Files:**
- Modify: `markdownViewr/ThemeEditorView.swift`
- Modify: `markdownViewr/SampleMarkdown.swift`

- [ ] **Step 1: Add highlight color rows to `colorsSection` in `ThemeEditorView.swift`**

In the `LazyVGrid` inside `colorsSection`, after `colorRow("Quote BG", $colors.blockquoteBackground)`, add:

```swift
                colorRow("Highlight BG", $colors.highlightBackground)
                colorRow("Highlight Text", $colors.highlightText)
```

- [ ] **Step 2: Add highlight/extension examples to `sampleMarkdown` in `SampleMarkdown.swift`**

Find the sample markdown string and add a new section so the Theme Editor preview shows the highlight color in action. Add this block to the sample (a sensible place is near the inline formatting examples):

```swift
## Extensions

This sentence uses ==highlighted text==, H~2~O for subscript, E=mc^2^ for superscript, and ++underlined text++.
```

- [ ] **Step 3: Build to verify**

```bash
just build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add markdownViewr/SettingsView.swift markdownViewr/ThemeEditorView.swift markdownViewr/SampleMarkdown.swift
git commit -m "add Markdown settings tab and highlight color pickers to theme editor"
```

---

### Task 9: Manual test

- [ ] **Step 1: Launch the app**

```bash
just run
```

- [ ] **Step 2: Open a test file with all four extension types**

Create `/tmp/extensions-test.md` with the following content:

```markdown
# Extension Test

Regular text with ==highlighted phrase== inline.

E=mc^2^ uses superscript.

H~2~O uses subscript.

This is ++underlined text++ using plus markers.

Code blocks must NOT be transformed:

    ==not highlighted==
    ^not superscript^
    ~not subscript~
    ++not underlined++

Fenced code blocks must also be skipped:

```text
==still not highlighted==
```

Open this file in the app.

- [ ] **Step 3: Verify each extension renders correctly**

- `==highlighted phrase==` → yellow/amber background highlight (matching the active theme's highlight color)
- `mc^2^` → `2` as superscript
- `H~2~O` → `2` as subscript
- `++underlined text++` → underline styling
- Content inside code blocks: no transformation, literal syntax visible

- [ ] **Step 4: Verify toggles work**

Open Settings → Markdown tab. Toggle Highlight off. Verify the highlighted phrase no longer has a background and shows `==highlighted phrase==` literally. Toggle it back on and verify it re-renders immediately.

- [ ] **Step 5: Verify highlight color in Theme Editor**

Open Settings → Themes → select a theme → Edit. Verify "Highlight BG" and "Highlight Text" color pickers appear in the Colors section. Change the highlight color and verify the preview updates immediately.

- [ ] **Step 6: Verify theme switching**

Switch between a dark theme and a light theme in the toolbar. Verify the highlight background color changes appropriately with the theme.
