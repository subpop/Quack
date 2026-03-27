#!/usr/bin/env bash

set -e  # Exit on any error

# Configuration — GitHub Pages & Releases
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="$(find "$PROJECT_ROOT" -maxdepth 1 -name '*.xcodeproj' | head -1)"
NAME="$(xcodebuild -project "$XCODEPROJ" -showBuildSettings 2>/dev/null | awk '/^ *PRODUCT_NAME = / {$1=$2=""; gsub(/^ +| +$/, "", $0); print}')"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"
GITHUB_REPO="${GITHUB_REPO:-subpop/Quack}"   # owner/repo
WEBSITE="${WEBSITE:-https://subpop.github.io/Quack}"
DOCS_APPCAST_PATH="docs/appcast.xml"                # Deployed as .../appcast.xml via GitHub Pages
GENERATE_APPCAST_TOOL="generate_appcast"

# Check for required tools
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is required. Install: https://cli.github.com/"
    exit 1
fi

# Check if DMG is provided
if [[ -z "$1" ]]; then
    echo "❌ No DMG file provided!"
    echo "Usage: ./publish-update.sh /path/to/MCP Inspector.dmg"
    exit 1
fi

DMG_FILE="$(realpath "$1")"
DMG_BASENAME="$(basename "$DMG_FILE")"
UPDATE_DIR="$(dirname "$DMG_FILE")"
PARTIAL_APPCAST_FILE="$UPDATE_DIR/partial_update.xml"
APPCAST_FILE="$UPDATE_DIR/appcast.xml"
EXISTING_APPCAST_FILE="$UPDATE_DIR/existing_update.xml"
APPCAST_OUTPUT="$PROJECT_ROOT/$DOCS_APPCAST_PATH"

# Generate `update.xml` using local DMG
echo "📝 Generating Sparkle appcast..."
"$GENERATE_APPCAST_TOOL" --link "$WEBSITE" -o "$PARTIAL_APPCAST_FILE" "$UPDATE_DIR"

# Extract version & build using awk (compatible with macOS)
VERSION=$(awk -F '[<>]' '/<sparkle:shortVersionString>/ {print $3}' "$PARTIAL_APPCAST_FILE")
BUILD=$(awk -F '[<>]' '/<sparkle:version>/ {print $3}' "$PARTIAL_APPCAST_FILE")

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    echo "❌ Failed to extract version or build from appcast!"
    exit 1
fi

echo "🏷️ Extracted version: $VERSION, build: $BUILD"

# Enclosure URL: GitHub Release asset (GitHub replaces spaces with dots in asset names)
DMG_ENCODED=$(echo "$DMG_BASENAME" | sed 's/ /./g')
RELEASE_TAG="v${VERSION}"
CORRECT_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${DMG_ENCODED}"

# 🔍 Extract changelog for this version (INCLUDING title)
CHANGELOG_CONTENT=$(awk -v version="$VERSION" -v build="$BUILD" '
    BEGIN {found=0}
    $0 ~ "^## " version " \\(" build "\\) " {found=1}  # Start capturing from title
    found && /^## / && !($0 ~ "^## " version " \\(" build "\\) ") {exit}  # Stop at next title
    found {print}
' "$CHANGELOG")

if [[ -z "$CHANGELOG_CONTENT" ]]; then
    echo "⚠️ No changelog entry found for version $VERSION (Build $BUILD)."
    exit 1
fi

# Convert changelog to HTML
CHANGELOG_HTML=$(echo "$CHANGELOG_CONTENT" | pandoc -f markdown-auto_identifiers -t html | sed 's/"/\&quot;/g')

# Wrap the HTML in a <div>
FULL_CHANGELOG_HTML=$(cat <<EOF
<div>
    $CHANGELOG_HTML
</div>
EOF
)

# Show preview in plain text
echo "🔎 Changelog Preview (Plain Text):"
echo "---------------------------------------------------------"
echo "$CHANGELOG_CONTENT"
echo "---------------------------------------------------------"

# Ask for confirmation before proceeding
echo -n "Proceed with creating update (y/n)? "
read answer
if [[ "$answer" != "${answer#[Nn]}" ]]; then
    echo "❌ Update canceled."
    exit 1
fi

# Fetch existing appcast from GitHub (main branch, docs folder)
DEFAULT_BRANCH="${GITHUB_DEFAULT_BRANCH:-main}"
RAW_APPCAST_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${DEFAULT_BRANCH}/${DOCS_APPCAST_PATH}"
if curl -sfL -o "$EXISTING_APPCAST_FILE" "$RAW_APPCAST_URL" && [[ -s "$EXISTING_APPCAST_FILE" ]]; then
    echo "📡 Found existing appcast. Downloading from GitHub..."
    APPCAST_EXISTS=true
    # Check if this build already exists
    if grep -q "<sparkle:version>$BUILD</sparkle:version>" "$EXISTING_APPCAST_FILE"; then
        echo "❌ Build $BUILD already exists in appcast!"
        echo "⚠️ Aborting to prevent duplicate versions."
        exit 1
    fi
else
    echo "⚠️ No existing appcast found. Using new appcast only."
    APPCAST_EXISTS=false
    rm -f "$EXISTING_APPCAST_FILE"
fi

# Merge old appcast (if exists) or use the new one
if [[ "$APPCAST_EXISTS" == true ]]; then
    echo "🔄 Merging new update into existing appcast..."

    # Copy everything up to <channel> (keep header and opening tag)
    awk '/<channel>/ {print; exit} {print}' "$EXISTING_APPCAST_FILE" > "$APPCAST_FILE"

    # Insert the new update entry at the top (newest version first)
    awk '/<item>/,/<\/item>/' "$PARTIAL_APPCAST_FILE" >> "$APPCAST_FILE"

    # Append all existing <item> entries (preserving version history)
    awk '/<item>/,/<\/item>/' "$EXISTING_APPCAST_FILE" >> "$APPCAST_FILE"

    # Close the channel properly
    echo "</channel></rss>" >> "$APPCAST_FILE"
else
    echo "✅ Using new appcast as the final appcast (no existing history)."
    cp "$PARTIAL_APPCAST_FILE" "$APPCAST_FILE"
fi

# Inject changelog into appcast (only the first </item>, which is the new entry)
perl -i -0pe "s{</item>}{<description><![CDATA[$FULL_CHANGELOG_HTML]]></description>\n</item>}" "$APPCAST_FILE"

# Replace enclosure URL with the GitHub Release URL (only the first enclosure = new entry)
perl -i -0pe "s{<enclosure url=\"[^\"]*\"}{<enclosure url=\"$CORRECT_URL\"}" "$APPCAST_FILE"

# Ask for final confirmation before publishing
echo -n "Proceed with publishing to GitHub (Release + Pages)? (y/n)? "
read answer
if [[ "$answer" != "${answer#[Nn]}" ]]; then
    echo "❌ Publish canceled."
    exit 1
fi

# 1) Create or update GitHub Release and upload DMG
if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" &>/dev/null; then
    echo "☁️ Uploading DMG to existing release $RELEASE_TAG..."
    gh release upload "$RELEASE_TAG" "$DMG_FILE" --repo "$GITHUB_REPO" --clobber
else
    echo "☁️ Creating release $RELEASE_TAG and uploading DMG..."
    gh release create "$RELEASE_TAG" "$DMG_FILE" --repo "$GITHUB_REPO" \
        --title "$NAME $VERSION" \
        --notes "$CHANGELOG_CONTENT"
fi

# 2) Publish appcast to GitHub Pages (write to docs/ and push)
mkdir -p "$(dirname "$APPCAST_OUTPUT")"
cp "$APPCAST_FILE" "$APPCAST_OUTPUT"

echo "📄 Appcast written to $APPCAST_OUTPUT"
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    git -C "$PROJECT_ROOT" add "$DOCS_APPCAST_PATH"
    if git -C "$PROJECT_ROOT" diff --staged --quiet; then
        echo "⚠️ No changes to appcast (already up to date)."
    else
        git -C "$PROJECT_ROOT" commit -m "Update appcast for $NAME $VERSION ($BUILD)"
        echo "📤 Pushing appcast to GitHub (Pages will deploy automatically)..."
        git -C "$PROJECT_ROOT" push
    fi
else
    echo "⚠️ Not a git repo: appcast saved to $APPCAST_OUTPUT"
    echo "   Commit and push $DOCS_APPCAST_PATH to publish via GitHub Pages."
fi

echo "🎉 Done. Release: https://github.com/${GITHUB_REPO}/releases/tag/${RELEASE_TAG}"
echo "   Appcast: ${WEBSITE}/appcast.xml (updates after Pages deploy)"
