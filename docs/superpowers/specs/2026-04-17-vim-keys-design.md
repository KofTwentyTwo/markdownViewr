# Vim Movement Keys

Add always-on vim-style navigation keys to the markdown viewer. Read-only app, so no modes — keys act immediately when the WebView has focus.

## Keybindings

| Key | Action |
|---|---|
| `j` / `k` | scroll down/up one line (~30px) |
| `Ctrl-d` / `Ctrl-u` | scroll half viewport |
| `Ctrl-f` / `Ctrl-b` | scroll full viewport |
| `g g` | scroll to top (two `g` within 500ms) |
| `G` | scroll to bottom |
| `]` `]` | next heading |
| `[` `[` | previous heading |
| `/` | focus the find bar |
| `n` / `N` | next / previous find match |
| `Esc` | clear find highlights |

Disabled when `Cmd` or `Alt` modifier is held (so Cmd+F, Cmd+/, etc. still work). Disabled when focus is in an `INPUT`, `TEXTAREA`, or `contentEditable` element.

## Architecture

All motion keys are handled in JavaScript inside `Resources/template.html`. A single `keydown` listener on `window` is added once on page load; it survives `updateContent()` calls because those only replace `#content` innerHTML.

Two-key sequences (`gg`, `][`, `[[`) are tracked with a small module-level variable plus a 500ms timeout that resets pending state.

### Helpers in template.html

- `scrollBy(px)` — animated scroll using `window.scrollBy`
- `scrollHalfPage(dir)` / `scrollFullPage(dir)` — based on `window.innerHeight`
- `gotoTop()` / `gotoBottom()`
- `jumpHeading(dir)` — queries `h1…h6`, filters to visible (`offsetParent !== null`), finds the first heading whose `offsetTop` is past the current scrollTop (or before, for `dir === -1`), and scrolls it into view

### `/` → find bar focus

The WebView can't focus a SwiftUI `TextField` directly. Flow:

1. JS: `window.webkit.messageHandlers.vim.postMessage("focusFind")`
2. `Coordinator` implements `WKScriptMessageHandler` and on receipt posts the existing `.toggleFindBar` notification
3. SwiftUI find bar already listens to that notification and opens / focuses itself

To register the handler, `MarkdownWebView.makeNSView` attaches a user content controller to the `WKWebViewConfiguration`:

```swift
let userContent = WKUserContentController()
userContent.add(context.coordinator, name: "vim")
config.userContentController = userContent
```

### `n` / `N` / `Esc`

These call the existing JS functions (`findNext`, `findPrev`, `clearFind`) directly — no Swift round-trip needed. `n`/`N` is a no-op when `_findMatches.length === 0`.

## Files Touched

- `markdownViewr/Resources/template.html` — new `<script>` block (or append to existing one) with the keydown handler and helpers
- `markdownViewr/MarkdownWebView.swift` — register `vim` script message handler, add `WKScriptMessageHandler` conformance to `Coordinator`

## Edge Cases

- **Find bar has focus**: WebView doesn't have keyboard focus, so JS handler doesn't fire. Correct by default.
- **`n`/`N` with no active search**: no-op.
- **Collapsed headings**: `jumpHeading` filters by `offsetParent !== null`, so hidden headings inside collapsed sections are skipped.
- **Modifier keys**: handler returns early if `metaKey` or `altKey` is set, so Cmd+F, Cmd+/, Cmd+0, etc. still reach their system/SwiftUI handlers.
- **Content re-render**: `keydown` listener is on `window`, unaffected by innerHTML swap.

## Non-Goals

- Count prefixes (`5j`, `10k`) — YAGNI
- `h` / `l` / `w` / `b` — not meaningful for rendered prose
- Visual mode / yank / any editing — view-only app
- Configurable keybindings — personal project, always on
