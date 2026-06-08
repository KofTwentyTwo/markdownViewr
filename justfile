default:
    @just --list

# Kill the running app
kill:
    -killall -9 markdownViewr 2>/dev/null

# Build the app
build:
    xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -destination 'platform=macOS' build

# Kill, build, and launch the app
run: kill build
    @open "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app"

# Open a specific markdown file
open file: build
    @open -a "$(xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/markdownViewr.app" "{{file}}"

# Regenerate the Xcode project from project.yml
generate:
    xcodegen generate

# Clean build artifacts
clean:
    xcodebuild -project markdownViewr.xcodeproj -scheme markdownViewr clean

# Archive, notarize, and publish a GitHub release (bump MARKETING_VERSION in project.yml first)
release: kill
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    ARCHIVE="/tmp/markdownViewr.xcarchive"
    EXPORT="/tmp/markdownViewr-export"
    ZIP="/tmp/markdownViewr-$VERSION.zip"
    echo "==> Archiving v$VERSION..."
    rm -rf "$ARCHIVE" "$EXPORT" "$ZIP"
    xcodebuild archive \
        -project markdownViewr.xcodeproj \
        -scheme markdownViewr \
        -archivePath "$ARCHIVE" \
        -destination 'generic/platform=macOS' \
        ENABLE_HARDENED_RUNTIME=YES | xcpretty || true
    echo "==> Exporting with Developer ID signing..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath "$EXPORT" \
        -exportOptionsPlist ExportOptions.plist
    APP="$EXPORT/markdownViewr.app"
    if [[ ! -d "$APP" ]]; then
        echo "Error: expected $APP but found: $(ls "$EXPORT")"
        exit 1
    fi
    echo "==> Notarizing (this takes a minute)..."
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "markdownViewr-notarytool" --wait
    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$APP"
    echo "==> Packaging final release..."
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "==> Creating GitHub release v$VERSION..."
    gh release create "v$VERSION" "$ZIP" \
        --repo darinkelkhoff/markdownViewr \
        --title "markdownViewr v$VERSION" \
        --generate-notes
    echo "==> Updating appcast..."
    SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1)
    if [[ -z "$SPARKLE_BIN" ]]; then
        echo "Error: Sparkle tools not found in DerivedData. Run 'just build' first."
        exit 1
    fi
    rm -rf /tmp/markdownViewr-appcast-input
    mkdir -p /tmp/markdownViewr-appcast-input
    cp "$ZIP" /tmp/markdownViewr-appcast-input/
    "$SPARKLE_BIN/generate_appcast" \
        --download-url-prefix "https://github.com/darinkelkhoff/markdownViewr/releases/download/v$VERSION/" \
        -o appcast.xml \
        /tmp/markdownViewr-appcast-input/
    echo "==> Committing and pushing appcast..."
    git add appcast.xml
    git commit -m "release: update appcast for v$VERSION"
    git push origin main
    echo ""
    echo "Done! https://github.com/darinkelkhoff/markdownViewr/releases/tag/v$VERSION"
