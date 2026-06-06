# Sparkle Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Sparkle 2.x auto-update support so users are notified of new releases and can install them without manually visiting GitHub.

**Architecture:** Sparkle is added as an SPM dependency. `SPUStandardUpdaterController` is initialized at app launch and handles background update checks and the update UI. An `appcast.xml` file lives in the repo root and is served via raw.githubusercontent.com; the `just release` recipe gains a step to regenerate it with each release.

**Tech Stack:** Sparkle 2.x (SPM), XcodeGen (`project.yml`), `generate_appcast` CLI tool (bundled with Sparkle in DerivedData), `just` for release automation.

---

## File Map

| File | Change |
|---|---|
| `project.yml` | Add Sparkle SPM package; add to target dependencies; add `SUFeedURL` and `SUPublicEDKey` to `info.properties` |
| `markdownViewr/MarkdownViewrApp.swift` | Add `import Sparkle`; add `SPUStandardUpdaterController` stored property; add "Check for Updates..." menu item |
| `appcast.xml` | New — empty initial appcast committed to repo root |
| `justfile` | Update `release` recipe to run `generate_appcast`, commit, and push `appcast.xml` |

---

### Task 1: Add Sparkle as an SPM dependency

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add Sparkle to the `packages` block in `project.yml`**

The `packages` block currently has one entry. Add `sparkle` directly after it:

```yaml
packages:
  swift-markdown:
    url: https://github.com/apple/swift-markdown.git
    from: "0.4.0"
  sparkle:
    url: https://github.com/sparkle-project/Sparkle.git
    from: "2.0.0"
```

- [ ] **Step 2: Add Sparkle to the target's `dependencies` list**

The `dependencies` block currently has one entry. Add `sparkle` directly after it:

```yaml
    dependencies:
      - package: swift-markdown
        product: Markdown
      - package: sparkle
        product: Sparkle
```

- [ ] **Step 3: Regenerate the Xcode project**

```bash
xcodegen generate
```

Expected: `Generating project markdownViewr.xcodeproj` with no errors.

- [ ] **Step 4: Build to verify Sparkle resolves and compiles**

```bash
just build
```

Expected: `** BUILD SUCCEEDED **`. Sparkle will be downloaded and compiled on first build — this may take a minute.

- [ ] **Step 5: Commit**

```bash
git add project.yml markdownViewr.xcodeproj
git commit -m "add Sparkle SPM dependency for auto-update"
```

---

### Task 2: Generate EdDSA keys and add to Info.plist

Sparkle signs each update with an ed25519 key so the app can verify the update came from you. This task generates the key pair, stores the private key in your keychain, and bakes the public key into the app.

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Locate the `generate_keys` tool from the resolved Sparkle package**

After the build in Task 1, Sparkle's tools are in DerivedData. Find them:

```bash
find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin/generate_keys" 2>/dev/null | head -1
```

Expected: a path like `~/Library/Developer/Xcode/DerivedData/markdownViewr-<hash>/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys`

- [ ] **Step 2: Run `generate_keys`**

```bash
$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin/generate_keys" 2>/dev/null | head -1)
```

The tool will:
1. Prompt for a keychain item name — enter `markdownViewr-sparkle`
2. Store the private key in your macOS keychain
3. Print a public key that looks like:

```
Public Key (SUPublicEDKey):

  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=

Add the following to your app's Info.plist:

  <key>SUPublicEDKey</key>
  <string>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</string>
```

Copy the base64 public key string (the `AAAA...=` part).

- [ ] **Step 3: Add `SUFeedURL` and `SUPublicEDKey` to `project.yml`'s `info.properties`**

The `info:` section currently ends with `UTImportedTypeDeclarations`. Add two new properties after it (substitute the actual base64 key from Step 2):

```yaml
    info:
      path: markdownViewr/Info.plist
      properties:
        CFBundleDocumentTypes:
          ...  # leave existing content unchanged
        UTImportedTypeDeclarations:
          ...  # leave existing content unchanged
        SUFeedURL: "https://raw.githubusercontent.com/darinkelkhoff/markdownViewr/main/appcast.xml"
        SUPublicEDKey: "PASTE_YOUR_BASE64_PUBLIC_KEY_HERE"
```

- [ ] **Step 4: Regenerate the Xcode project to write keys into Info.plist**

```bash
xcodegen generate
```

- [ ] **Step 5: Verify both keys appear in the generated Info.plist**

```bash
grep -A1 "SUFeedURL\|SUPublicEDKey" markdownViewr/Info.plist
```

Expected: both keys present with their values.

- [ ] **Step 6: Build to confirm no regressions**

```bash
just build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add project.yml markdownViewr/Info.plist
git commit -m "add Sparkle EdDSA public key and feed URL to Info.plist"
```

---

### Task 3: Wire up SPUStandardUpdaterController and menu item

**Files:**
- Modify: `markdownViewr/MarkdownViewrApp.swift`

- [ ] **Step 1: Add `import Sparkle` at the top of `MarkdownViewrApp.swift`**

After `import SwiftUI`:

```swift
import SwiftUI
import Sparkle
```

- [ ] **Step 2: Add the updater controller as a stored property**

Add this property to `MarkdownViewrApp`, immediately before the existing `@StateObject` declarations:

```swift
@main
struct MarkdownViewrApp: App {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var editorManager = EditorManager()
```

- [ ] **Step 3: Add "Check for Updates..." to the app menu**

In the `.commands { }` block, add a new `CommandGroup` as the first entry, before the existing `CommandGroup(replacing: .appSettings)`:

```swift
.commands {
    CommandGroup(after: .appInfo) {
        Button("Check for Updates...") {
            updaterController.checkForUpdates(nil)
        }
    }

    CommandGroup(replacing: .appSettings) {
        // ... existing settings button
    }
    // ... rest of existing commands
```

- [ ] **Step 4: Build**

```bash
just build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Launch the app and verify "Check for Updates..." appears in the app menu**

```bash
just run
```

Open the app menu (the menu with the app name, leftmost in the menu bar). "Check for Updates..." should appear below "About markdownViewr".

- [ ] **Step 6: Commit**

```bash
git add markdownViewr/MarkdownViewrApp.swift
git commit -m "wire up SPUStandardUpdaterController and Check for Updates menu item"
```

---

### Task 4: Create the initial appcast.xml

**Files:**
- Create: `appcast.xml`

- [ ] **Step 1: Create `appcast.xml` in the repo root**

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>markdownViewr</title>
        <link>https://github.com/darinkelkhoff/markdownViewr</link>
        <description>markdownViewr releases</description>
        <language>en</language>
    </channel>
</rss>
```

- [ ] **Step 2: Verify the file is valid XML**

```bash
xmllint --noout appcast.xml && echo "valid"
```

Expected: `valid`

- [ ] **Step 3: Commit**

```bash
git add appcast.xml
git commit -m "add initial empty appcast.xml for Sparkle auto-update"
```

---

### Task 5: Update `just release` to regenerate the appcast

After each GitHub release, the appcast needs to be updated with the new version's entry (signed with your private key) and pushed so existing users are notified.

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Add the appcast update step to the `release` recipe**

The current `release` recipe ends with:

```bash
    echo ""
    echo "Done! https://github.com/darinkelkhoff/markdownViewr/releases/tag/v$VERSION"
```

Replace that block with:

```bash
    echo "==> Updating appcast..."
    SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1)
    if [[ -z "$SPARKLE_BIN" ]]; then
        echo "Error: Sparkle tools not found in DerivedData. Run 'just build' first."
        exit 1
    fi
    mkdir -p /tmp/markdownViewr-appcast-input
    cp "$ZIP" /tmp/markdownViewr-appcast-input/
    "$SPARKLE_BIN/generate_appcast" \
        --download-url-prefix "https://github.com/darinkelkhoff/markdownViewr/releases/download/v$VERSION/" \
        -o appcast.xml \
        /tmp/markdownViewr-appcast-input/
    echo "==> Committing and pushing appcast..."
    git add appcast.xml
    git commit -m "release: update appcast for v$VERSION"
    git push
    echo ""
    echo "Done! https://github.com/darinkelkhoff/markdownViewr/releases/tag/v$VERSION"
```

- [ ] **Step 2: Verify `justfile` has no syntax errors**

```bash
just --list
```

Expected: lists all recipes including `release` with no errors.

- [ ] **Step 3: Dry-run verify by checking `generate_appcast` is findable after a build**

```bash
find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1
```

Expected: prints a path (not empty). If empty, run `just build` first.

- [ ] **Step 4: Commit**

```bash
git add justfile
git commit -m "update release recipe to regenerate and push appcast after each release"
```

---

## Post-Implementation Verification

After all tasks are complete:

1. Run `just run` — confirm "Check for Updates..." appears in the app menu
2. Click "Check for Updates..." — Sparkle should show either "You're up to date" or a first-launch permission dialog asking whether to enable automatic checks
3. Run `just release` on a version bump (bump `MARKETING_VERSION` in `project.yml` first) — confirm `appcast.xml` is updated with the new version entry after the release completes
4. On a machine with the previous version installed, open the app — Sparkle should detect the new version and prompt for an update
