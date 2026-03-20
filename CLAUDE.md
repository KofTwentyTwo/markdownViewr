# markdownViewr

macOS markdown viewer app. View-only — no editing. Built with SwiftUI + WKWebView hybrid architecture.

## Build & Run

Uses XcodeGen to generate the Xcode project from `project.yml`.

```bash
just run          # build and launch
just build        # build only
just generate     # regenerate .xcodeproj from project.yml
just clean        # clean build artifacts
just kill         # force-kill running app
```

After adding/removing Swift files or resources, run `xcodegen generate` before building.

## Architecture

- **SwiftUI** app shell (toolbar, settings, window management)
- **WKWebView** for markdown rendering (via `NSViewRepresentable`)
- **Document-based** using `DocumentGroup` with `FileDocument`
- Markdown parsed to HTML using Apple's `swift-markdown` library
- HTML rendered in a template (`Resources/template.html`) with CSS variable-based theming
- Settings and Theme Editor use custom `NSWindow` controllers (not SwiftUI `Settings` scene) because SwiftUI's Settings scene doesn't support resizing

## Key Files

| File | Purpose |
|---|---|
| `MarkdownViewrApp.swift` | App entry point, `DocumentGroup`, menu commands, `SettingsWindowController` |
| `MarkdownDocument.swift` | `FileDocument`, markdown-to-HTML conversion, frontmatter parsing |
| `ContentView.swift` | Main window: toolbar, find bar, `LiveContent` for file watching |
| `MarkdownWebView.swift` | `NSViewRepresentable` wrapping `WKWebView`, handles content/theme/find updates |
| `Theme.swift` | `Codable` theme model (colors, fonts, sizes, customCSS). `isBuiltIn` is runtime-only (not in JSON) |
| `ThemeManager.swift` | Loads/saves themes, generates CSS, manages enabled/disabled/deleted state |
| `ThemeEditorView.swift` | Theme creation/editing UI with live preview |
| `SettingsView.swift` | General, Editors, Themes tabs + `ThemeEditorWindowController` |
| `EditorConfig.swift` | External editor model + manager |
| `FileWatcher.swift` | `DispatchSource` file system watcher |
| `FindBarController.swift` | Find state + notification names |
| `CSSHelpView.swift` | Shared CSS reference popover |
| `SampleMarkdown.swift` | Kitchen-sink sample for theme preview |
| `WindowResizer.swift` | NSView helper that adds `.resizable` to hosting windows |
| `Resources/template.html` | HTML template with base CSS, theme CSS slot, and JS functions |
| `Resources/themes/*.json` | Built-in theme definitions |

## How Theming Works

1. `ThemeManager.generateCSS(for:)` produces CSS with `:root` variables from the theme, plus global CSS, plus per-theme custom CSS
2. CSS is injected into the `<style id="theme-css">` block in the template (comes AFTER base CSS so custom CSS can override)
3. Theme switching uses `evaluateJavaScript("updateThemeCSS(...)")` to avoid full page reload
4. Content updates use `evaluateJavaScript("updateContent(...)")` with scroll position preservation

## How File Watching Works

- `LiveContent` (ObservableObject) stores raw markdown, updated by `FileWatcher`
- `ContentView.rerender()` converts raw markdown to HTML using current frontmatter mode
- Updates pushed to WebView via JS `updateContent()` to preserve scroll position
- `onReceive` on `themeManager.$frontmatterMode` and `liveContent.$rawMarkdown` trigger re-renders (with `DispatchQueue.main.async` to avoid stale `@Published` values)

## How Images Work

- HTML is written to a temp file in `/tmp/markdownViewr-previews/`
- Loaded via `WKWebView.loadFileURL` with `allowingReadAccessTo: /`
- A `<base href="...">` tag in the HTML points to the document's directory so relative image paths resolve correctly

## Settings Windows

SwiftUI's `Settings` scene and `.sheet` don't support resizing on macOS. Both Settings and Theme Editor use manually created `NSWindow` instances via controller classes (`SettingsWindowController`, `ThemeEditorWindowController`).

## Theme Storage

- Built-in themes: bundled JSON in `Resources/themes/`
- User themes: `~/Library/Application Support/markdownViewr/themes/`
- Disabled themes tracked in UserDefaults key `disabledThemes`
- Deleted built-in themes tracked in UserDefaults key `deletedBuiltIns` (restorable)
- Theme order tracked in UserDefaults key `themeOrder`
- Active theme tracked in UserDefaults key `activeTheme`

## Find in Document

- Cmd+F toggles find bar per-window (each window has its own `FindBarController`)
- Menu commands post notifications; only the key window responds
- Uses custom JavaScript (`findAll`, `findNext`, `findPrev`, `clearFind`) that highlights matches with `<mark>` elements
- Highlights use theme-aware colors (`--text` and `--link` variables) to work on any background
- Returns JSON `{current, total}` for "n of m" display

## Gotchas

- `Bundle.module` doesn't exist in XcodeGen projects — always use `Bundle.main`
- `Table` is ambiguous between SwiftUI and Markdown — use `Markdown.Table`
- SwiftUI computed properties reading `@Published` values via `onReceive` fire BEFORE the value is set — use `DispatchQueue.main.async` to defer
- `NSWindow.isReleasedWhenClosed` must be `false` for windows held by controllers, with `windowWillClose` delegate to nil the reference
