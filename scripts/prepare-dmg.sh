#!/usr/bin/env bash

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="$(find "$PROJECT_ROOT" -maxdepth 1 -name '*.xcodeproj' | head -1)"
NAME="$(xcodebuild -project "$XCODEPROJ" -showBuildSettings 2>/dev/null | awk '/^ *PRODUCT_NAME = / {$1=$2=""; gsub(/^ +| +$/, "", $0); print}')"
BUILD_DIR="$PROJECT_ROOT/builds"
NOTARY_PROFILE="notarytool-signing-profile"
# Developer ID Application certificate SHA-1 fingerprint (set DEVELOPER_ID in env or .env to avoid committing)
DEVELOPER_ID="${DEVELOPER_ID:?Set DEVELOPER_ID to your Developer ID Application certificate fingerprint (e.g. from Keychain Access or 'security find-identity -v -p codesigning')}"

echo "🔍 Searching for builds..." >&2
AVAILABLE_BUILDS=()
while IFS= read -r line; do
    AVAILABLE_BUILDS+=("$line")
done < <(find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -type d -exec stat -f "%m %N" {} \; | sort -nr | cut -d' ' -f2-)

if [[ ${#AVAILABLE_BUILDS[@]} -eq 0 ]]; then
    echo "❌ No builds found in $BUILD_DIR!"
    exit 1
fi

# Extract only folder names, preserving spaces
BUILD_NAMES=()
for dir in "${AVAILABLE_BUILDS[@]}"; do
    BUILD_NAMES+=("$(basename "$dir")")
done

# Use fzf for selection if available
if command -v fzf &>/dev/null; then
    echo "↕️ Select a build using arrow keys:" >&2
    SELECTED_BUILD_NAME=$(printf "%s\n" "${BUILD_NAMES[@]}" | fzf --height=10 --reverse)
else
    echo "↕️ Available builds:" >&2
    for i in "${!BUILD_NAMES[@]}"; do
        echo "$((i+1))) ${BUILD_NAMES[$i]}" >&2
    done

    read -p "Select a build (default: latest): " BUILD_SELECTION >&2
    if [[ -z "$BUILD_SELECTION" || ! "$BUILD_SELECTION" =~ ^[0-9]+$ || "$BUILD_SELECTION" -lt 1 || "$BUILD_SELECTION" -gt ${#BUILD_NAMES[@]} ]]; then
        SELECTED_BUILD_NAME="${BUILD_NAMES[0]}"  # Default to latest
    else
        SELECTED_BUILD_NAME="${BUILD_NAMES[$((BUILD_SELECTION-1))]}"
    fi
fi

SELECTED_BUILD_DIR="$BUILD_DIR/$SELECTED_BUILD_NAME"
APP_BUNDLE="$SELECTED_BUILD_DIR/$NAME.app"

# Extract version and build number
VERSION=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleVersion)

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    echo "❌ Failed to extract version or build number!" >&2
    exit 1
fi

DMG_FILE="${APP_BUNDLE%.app}-$VERSION.dmg"

echo "✅ Selected build: $SELECTED_BUILD_NAME" >&2

# Check if DMG already exists
if [[ -f "$DMG_FILE" ]]; then
    echo "⚠️ A DMG file already exists: $DMG_FILE" >&2
    echo -n "Do you want to delete it and create a new one? (y/n)? " >&2
    read answer
    if [[ "$answer" != "${answer#[Nn]}" ]]; then
        echo "❌ Aborting. Existing DMG not deleted." >&2
        exit 1
    fi
    echo "🗑️ Deleting existing DMG..." >&2
    rm "$DMG_FILE"
fi

echo "📦 Building & notarizing DMG..." >&2
/opt/local/bin/create-dmg \
  --volname "$NAME" \
  --no-internet-enable \
  --codesign "$DEVELOPER_ID" \
  --notarize "$NOTARY_PROFILE" \
  --window-size 540 380 \
  --icon-size 96 \
  --icon "$NAME.app" 100 142 \
  --app-drop-link 320 142 \
  "$DMG_FILE" "$SELECTED_BUILD_DIR"

echo "🧷 Stapling..." >&2
/usr/bin/xcrun stapler staple "$DMG_FILE" >&2
echo "🎁 DMG is ready for publishing." >&2

# 🚀 **Final output: ONLY the DMG path**
echo "$DMG_FILE"
