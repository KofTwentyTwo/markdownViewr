# Sparkle Auto-Update Design

**Date:** 2026-06-05  
**Status:** Approved

## Overview

Add automatic update support to markdownViewr using Sparkle 2.x. On first launch after install, Sparkle prompts the user whether to enable background update checks. When a new release is published, the app notifies users and handles download and installation. Users can also trigger a manual check via "Check for Updates..." in the app menu.

## Dependencies

Sparkle 2.x added to `project.yml` as a Swift Package dependency:

```yaml
packages:
  sparkle:
    url: https://github.com/sparkle-project/Sparkle.git
    from: "2.0.0"
```

Added to the target's `dependencies` alongside `swift-markdown`. After adding, run `xcodegen generate` to regenerate the `.xcodeproj`.

## Signing Keys

Sparkle 2.x uses EdDSA (ed25519) signatures to verify update authenticity.

- Generate a key pair using Sparkle's bundled `generate_keys` tool (run once, at setup time).
- The **private key** is stored in the macOS keychain under the profile name `markdownViewr-sparkle` (never committed to the repo).
- The **public key** is stored in `Info.plist` as `SUPublicEDKey`.

## App Integration

`MarkdownViewrApp.swift` gets one new stored property:

```swift
private let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
```

`startingUpdater: true` starts the background updater on launch. Sparkle handles the first-launch permission prompt automatically.

A "Check for Updates..." menu item is added to the app menu using `CommandGroup(after: .appInfo)`:

```swift
CommandGroup(after: .appInfo) {
    Button("Check for Updates...") {
        updaterController.checkForUpdates(nil)
    }
}
```

## Info.plist

Two keys added to `markdownViewr/Info.plist`:

| Key | Value |
|---|---|
| `SUFeedURL` | `https://raw.githubusercontent.com/darinkelkhoff/markdownViewr/main/appcast.xml` |
| `SUPublicEDKey` | _(EdDSA public key generated at setup)_ |

## Appcast

`appcast.xml` lives in the repo root. It is a standard Sparkle RSS appcast with one `<item>` per release. Sparkle's `generate_appcast` tool creates and updates it automatically.

Example structure:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>markdownViewr</title>
        <link>https://github.com/darinkelkhoff/markdownViewr</link>
        <description>markdownViewr releases</description>
        <language>en</language>
        <item>
            <title>markdownViewr 1.1.0</title>
            <sparkle:version>2</sparkle:version>
            <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
            <pubDate>Thu, 05 Jun 2026 12:00:00 +0000</pubDate>
            <enclosure
                url="https://github.com/darinkelkhoff/markdownViewr/releases/download/v1.1.0/markdownViewr-1.1.0.zip"
                sparkle:edSignature="..."
                length="..."
                type="application/octet-stream"/>
        </item>
    </channel>
</rss>
```

The `generate_appcast` tool reads the private key from the keychain, signs the zip, extracts version info from the app bundle, and writes the updated `appcast.xml`.

## Release Workflow Changes

The `just release` recipe gains a final step after creating the GitHub release:

1. Run `generate_appcast` against the export directory containing the notarized zip.
2. Commit the updated `appcast.xml` to the repo.
3. Push the commit.

The `generate_appcast` tool is accessed via the path inside the resolved Sparkle SPM package in DerivedData, or via a symlink/path set up at key-generation time.

## Files Changed

| File | Change |
|---|---|
| `project.yml` | Add Sparkle SPM package; add to target dependencies |
| `markdownViewr/Info.plist` | Add `SUFeedURL` and `SUPublicEDKey` |
| `markdownViewr/MarkdownViewrApp.swift` | Add `SPUStandardUpdaterController`; add "Check for Updates..." menu item |
| `appcast.xml` | New — initial empty appcast committed to repo root |
| `justfile` | Update `release` recipe to run `generate_appcast`, commit, and push `appcast.xml` |

## Setup Steps (One-Time, Not in Implementation Plan)

Before the implementation plan tasks can be completed, the developer must:

1. Run Sparkle's `generate_keys` tool to create the EdDSA key pair.
2. Store the private key in the keychain under profile `markdownViewr-sparkle`.
3. Note the public key for insertion into `Info.plist`.

These are manual one-time steps performed in the terminal, not automated tasks.
