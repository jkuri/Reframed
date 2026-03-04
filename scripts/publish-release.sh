#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
VERSION=$(grep MARKETING_VERSION "$ROOT_DIR/Config.xcconfig" | cut -d'=' -f2 | tr -d ' ')
TAG="v${VERSION}"
DMG_PATH="$DIST_DIR/Reframed-${VERSION}.dmg"
APPCAST_PATH="$DIST_DIR/appcast.xml"
REPO="jkuri/Reframed"

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install it: brew install gh"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "Error: Not authenticated with gh. Run: gh auth login"
  exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "Error: DMG not found at $DMG_PATH"
  exit 1
fi

if [ ! -f "$APPCAST_PATH" ]; then
  echo "Error: appcast.xml not found at $APPCAST_PATH"
  exit 1
fi

echo "Publishing Reframed ${TAG}..."

echo "Pushing commits and tag..."
git push --follow-tags

CHANGELOG=$("$SCRIPT_DIR/changelog.sh" --tag "$TAG" --stdout 2>/dev/null | tail -n +4 || true)

echo "Creating GitHub release ${TAG}..."
if [ -n "$CHANGELOG" ]; then
  gh release create "$TAG" \
    --repo "$REPO" \
    --title "Reframed ${TAG}" \
    --notes "$CHANGELOG" \
    "$DMG_PATH"
else
  gh release create "$TAG" \
    --repo "$REPO" \
    --title "Reframed ${TAG}" \
    --generate-notes \
    "$DMG_PATH"
fi

echo "Uploading appcast.xml..."
if gh release view appcast --repo "$REPO" &>/dev/null; then
  gh release delete-asset appcast appcast.xml --repo "$REPO" --yes 2>/dev/null || true
  gh release upload appcast "$APPCAST_PATH" --repo "$REPO" --clobber
else
  gh release create appcast \
    --repo "$REPO" \
    --title "Appcast" \
    --notes "Sparkle appcast feed. This release is updated automatically." \
    "$APPCAST_PATH"
fi

echo ""
echo "Published Reframed ${TAG}!"
echo "  Release: https://github.com/${REPO}/releases/tag/${TAG}"
echo "  Appcast: https://github.com/${REPO}/releases/download/appcast/appcast.xml"
