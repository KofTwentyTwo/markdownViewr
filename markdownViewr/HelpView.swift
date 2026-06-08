import SwiftUI
import WebKit

private enum HelpTopic: String, CaseIterable, Identifiable {
    case overview       = "Overview"
    case openingFiles   = "Opening Files"
    case frontmatter    = "Frontmatter"
    case extensions     = "Markdown Extensions"
    case themes         = "Themes"
    case editors        = "External Editors"
    case shortcuts      = "Keyboard Shortcuts"

    var id: String { rawValue }
}

struct HelpView: View {
    @State private var selection: HelpTopic = .overview

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.allCases, selection: $selection) { topic in
                Text(topic.rawValue).tag(topic)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            HelpWebView(markdown: helpMarkdown(for: selection))
                .id(selection)
        }
    }

    private func helpMarkdown(for topic: HelpTopic) -> String {
        switch topic {
        case .overview:
            return """
            # Overview

            markdownViewr is a fast, view-only markdown file viewer for macOS. It renders \
            markdown to HTML and displays it in a styled WebView with full theming support.

            Files are watched for external changes and automatically reloaded — open a file \
            in your editor and markdownViewr keeps pace as you save.

            ## Features

            - Renders standard Markdown and GitHub Flavored Markdown (GFM): bold, italic, \
            strikethrough, tables, code blocks, task lists, and more
            - Optional extensions: highlight, superscript, subscript, underline
            - YAML frontmatter support: hide it, show it as a metadata table, or render it as Markdown
            - Fully customizable themes with a built-in theme editor and custom CSS
            - Vim-style keyboard navigation
            - Find in document with match count
            - One-click open in any configured external editor
            - Automatic updates via Sparkle
            """

        case .openingFiles:
            return """
            # Opening Files

            markdownViewr opens any plain text file. It registers `.md`, `.markdown`, \
            `.mdown`, and `.mkd` with the OS so Finder offers markdownViewr for those \
            file types by default.

            ## Ways to open a file

            - **File > Open** (⌘O) — standard open dialog
            - Drag a file onto the Dock icon or an open window
            - Double-click a file in Finder if markdownViewr is set as the default app
            - Right-click a file in Finder > Open With > markdownViewr

            ## Setting as the default viewer

            To make markdownViewr open all `.md` files by default: right-click any `.md` \
            file in Finder, choose **Get Info**, expand **Open with**, select markdownViewr, \
            then click **Change All...**.

            ## Live reloading

            When an open file is modified on disk by another app (your editor, a script, \
            etc.), markdownViewr detects the change and re-renders automatically. Scroll \
            position is preserved across reloads.
            """

        case .frontmatter:
            return """
            # Frontmatter

            YAML frontmatter is a block of metadata at the very top of a Markdown file, \
            delimited by `---` lines:

            ```
            ---
            title: My Document
            author: Jane Smith
            date: 2026-01-01
            ---

            # Heading

            Body text...
            ```

            The **Frontmatter** setting (Settings > General) controls how this block is handled.

            ## Hide (default)

            The frontmatter block is stripped before rendering. The body begins immediately \
            after the closing `---` line.

            ## Show as Metadata

            The frontmatter is rendered as a styled key–value table above the document body. \
            Keys appear on the left, values on the right.

            ## Show as Markdown

            The frontmatter is passed to the Markdown parser as-is. The `---` delimiters \
            render as horizontal rules and the content is treated as normal Markdown text.
            """

        case .extensions:
            return """
            # Markdown Extensions

            Extensions add syntax beyond standard GFM. Each can be toggled independently \
            in **Settings > Extensions**.

            ## Highlight

            Wrapping text in `== ==` renders it as highlighted text.

            ```
            ==highlighted text==
            ```

            ## Superscript

            Wrapping a single word in `^ ^` renders it as superscript. No spaces allowed \
            inside — this avoids false positives on prose like "It's ^ that simple".

            ```
            E = mc^2^

            Footnote reference^1^
            ```

            ## Subscript

            Wrapping a single word in `~ ~` renders it as subscript. No spaces allowed \
            inside — single-word only to avoid conflict with GFM strikethrough (`~~ ~~`).

            ```
            H~2~O

            CO~2~
            ```

            ## Underline

            Wrapping text in `++ ++` renders it as underlined text.

            ```
            ++underlined text++
            ```

            ## Standard GFM (always on)

            - `**bold**` / `__bold__`
            - `*italic*` / `_italic_`
            - `~~strikethrough~~`
            - `` `inline code` ``
            - Fenced code blocks
            - Tables
            - `- [ ]` task lists
            """

        case .themes:
            return """
            # Themes

            Themes control the colors, fonts, and overall appearance of rendered documents. \
            markdownViewr ships with a set of built-in themes and supports unlimited \
            user-created themes.

            ## Switching themes

            Use the **Theme** menu or the keyboard shortcuts **⌘⇧↓** / **⌘⇧↑** to cycle \
            through enabled themes. The active theme applies to all open windows.

            ## Managing themes

            **Settings > Themes** lists all themes. You can:

            - Enable or disable themes (disabled themes are skipped when cycling)
            - Reorder themes by dragging
            - Delete user themes
            - Restore deleted built-in themes

            ## Creating and editing themes

            Click **New Theme** (or **Edit** on an existing user theme) to open the Theme \
            Editor. Changes are previewed live against a sample document.

            The editor covers:

            - Background and text colors
            - Heading, link, inline code, and blockquote colors
            - Table border and alternating row colors
            - Body, heading, and code font families and sizes
            - Custom CSS — injected after all base styles, so any rule can be overridden

            ## Custom CSS

            Custom CSS is the escape hatch for anything the theme editor doesn't expose. \
            It targets the same HTML the renderer produces, so standard CSS selectors work:

            ```css
            /* Wider line spacing */
            body { line-height: 1.9; }

            /* Justify paragraphs */
            p { text-align: justify; }

            /* Larger code font */
            code { font-size: 0.95em; }
            ```

            ## Theme storage

            User themes are stored as JSON files in \
            `~/Library/Application Support/markdownViewr/themes/`. Built-in themes are \
            bundled with the app and cannot be edited (but can be duplicated).
            """

        case .editors:
            return """
            # External Editors

            markdownViewr can open the current file in an external editor with one click. \
            Any app that accepts a file path as a command-line argument can be configured.

            ## Adding an editor

            Go to **Settings > Editors** and click the **+** button. Give the editor a name, \
            then click the path field to browse for the executable or app bundle. Most \
            editors install a command-line tool (e.g. `/usr/local/bin/code` for VS Code), \
            but you can also browse directly to the `.app` in `/Applications`.

            Enable **Opens folder instead of file** if the editor works better when opened \
            to the containing directory rather than the file itself — useful for \
            project-based editors like VS Code or Nova, terminal emulators like Terminal \
            (`/System/Applications/Utilities/Terminal.app`), or Finder \
            (`/System/Library/CoreServices/Finder.app`).

            ## Using the toolbar button

            When at least one editor is configured, an **Open In** button appears in the \
            document toolbar. Click it to open the current file (or its containing folder) \
            in your configured editor. If you have multiple editors configured, clicking \
            the button shows a menu to choose which one.
            """

        case .shortcuts:
            return """
            # Keyboard Shortcuts

            ## Navigation

            | Key | Action |
            |---|---|
            | `j` / `k` | Scroll down / up one line |
            | `Ctrl+d` / `Ctrl+u` | Scroll half page down / up |
            | `Ctrl+f` / `Ctrl+b` | Scroll full page down / up |
            | `g g` | Jump to top of document |
            | `G` | Jump to bottom of document |
            | `]]` / `[[` | Jump to next / previous heading |

            ## Find

            | Key | Action |
            |---|---|
            | `⌘ F` | Show / hide find bar |
            | `⌘ G` | Find next match |
            | `⌘ ⇧ G` | Find previous match |
            | `/` (in document) | Focus find bar (vim-style) |
            | `n` / `N` (in document) | Next / previous match (vim-style) |

            ## View

            | Key | Action |
            |---|---|
            | `⌘ +` | Zoom in |
            | `⌘ −` | Zoom out |
            | `⌘ 0` | Actual size |
            | `⌘ ⇧ ↓` | Next theme |
            | `⌘ ⇧ ↑` | Previous theme |

            ## General

            | Key | Action |
            |---|---|
            | `⌘ ,` | Open Settings |
            | `⌘ ?` | Open Help |
            | `⌘ O` | Open file |
            | `⌘ W` | Close window |
            """
        }
    }
}

struct HelpWebView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let body = MarkdownDocument.convertToHTML(markdown)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, sans-serif;
            font-size: 13px;
            line-height: 1.6;
            color: #1a1a1a;
            background: transparent;
            margin: 0;
            padding: 20px 24px;
            max-width: 680px;
        }
        h1 { font-size: 1.5em; margin: 0 0 12px 0; }
        h2 { font-size: 1.1em; margin: 20px 0 6px 0; }
        p { margin: 0 0 8px 0; }
        ul, ol { margin: 0 0 8px 0; padding-left: 1.5em; }
        li { margin-bottom: 3px; }
        code {
            font-family: ui-monospace, monospace;
            font-size: 0.9em;
            background: rgba(0,0,0,0.06);
            padding: 1px 4px;
            border-radius: 3px;
        }
        pre {
            background: rgba(0,0,0,0.06);
            border-radius: 6px;
            padding: 10px 14px;
            overflow-x: auto;
            margin: 0 0 10px 0;
        }
        pre code { background: none; padding: 0; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 10px; }
        th, td { text-align: left; padding: 5px 10px; border-bottom: 1px solid rgba(0,0,0,0.1); }
        th { font-weight: 600; border-bottom: 2px solid rgba(0,0,0,0.15); }
        @media (prefers-color-scheme: dark) {
            body { color: #e8e8e8; }
            code { background: rgba(255,255,255,0.1); }
            pre { background: rgba(255,255,255,0.08); }
            th, td { border-bottom-color: rgba(255,255,255,0.12); }
            th { border-bottom-color: rgba(255,255,255,0.2); }
        }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
