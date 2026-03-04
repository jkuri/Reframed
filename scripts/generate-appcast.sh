#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
VERSION=$(grep MARKETING_VERSION "$ROOT_DIR/Config.xcconfig" | cut -d'=' -f2 | tr -d ' ')
DMG_NAME="Reframed-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
APPCAST_PATH="$DIST_DIR/appcast.xml"
DOWNLOAD_URL="https://github.com/jkuri/Reframed/releases/download/v${VERSION}/${DMG_NAME}"

if [ ! -f "$DMG_PATH" ]; then
  echo "Error: DMG not found at $DMG_PATH"
  echo "Run 'make dmg' first."
  exit 1
fi

SIGN_UPDATE=""
SPARKLE_BIN_DIR=$(find "$ROOT_DIR/.build/SourcePackages/artifacts/sparkle/Sparkle" -name "sign_update" -type f 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)

if [ -z "$SPARKLE_BIN_DIR" ]; then
  SPARKLE_BIN_DIR=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle/bin" -type d 2>/dev/null | head -1 || true)
fi

if [ -n "$SPARKLE_BIN_DIR" ] && [ -f "$SPARKLE_BIN_DIR/sign_update" ]; then
  SIGN_UPDATE="$SPARKLE_BIN_DIR/sign_update"
else
  echo "Error: Sparkle sign_update tool not found."
  echo "Run 'make build' first to fetch Sparkle artifacts."
  exit 1
fi

if [ -z "${REFRAMED_SPARKLE_KEY:-}" ]; then
  echo "Error: REFRAMED_SPARKLE_KEY is not set."
  echo "Export your EdDSA private key:"
  echo "  .build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x /tmp/sparkle_key"
  echo "  export REFRAMED_SPARKLE_KEY=\"\$(cat /tmp/sparkle_key)\""
  exit 1
fi

LENGTH=$(stat -f%z "$DMG_PATH")
SIGNATURE=$(echo "$REFRAMED_SPARKLE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$DMG_PATH" -p)

if [ -z "$SIGNATURE" ]; then
  echo "Error: Failed to generate EdDSA signature."
  exit 1
fi

PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

md_to_html() {
  local md="$1"
  local html=""
  local in_list=false
  local section=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^###\ (.+) ]]; then
      if $in_list; then
        html+="</ul>"
        in_list=false
      fi
      section="${BASH_REMATCH[1]}"
      html+="<h3>${section}</h3>"
    elif [[ "$line" =~ ^-\ (.+) ]]; then
      if ! $in_list; then
        html+="<ul>"
        in_list=true
      fi
      local item="${BASH_REMATCH[1]}"
      item=$(echo "$item" | sed -E 's/\*\*([^*]+)\*\*/<b>\1<\/b>/g')
      item=$(echo "$item" | sed -E 's/\[([^]]+)\]\([^)]+\)/\1/g')
      html+="<li>${item}</li>"
    fi
  done <<< "$md"

  if $in_list; then
    html+="</ul>"
  fi

  echo "$html"
}

CHANGELOG_MD=""
if [ -f "$SCRIPT_DIR/changelog.sh" ] && git rev-parse "v${VERSION}" >/dev/null 2>&1; then
  CHANGELOG_MD=$("$SCRIPT_DIR/changelog.sh" --tag "v${VERSION}" --stdout 2>/dev/null | tail -n +4 || true)
fi

RELEASE_NOTES=""
if [ -n "$CHANGELOG_MD" ]; then
  RELEASE_NOTES=$(md_to_html "$CHANGELOG_MD")
fi

DESCRIPTION_BLOCK=""
if [ -n "$RELEASE_NOTES" ]; then
  DESCRIPTION_BLOCK="      <description><![CDATA[${RELEASE_NOTES}]]></description>"
fi

cat > "$APPCAST_PATH" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Reframed</title>
    <link>https://github.com/jkuri/Reframed</link>
    <description>Reframed Updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
${DESCRIPTION_BLOCK}
      <enclosure
        url="${DOWNLOAD_URL}"
        length="${LENGTH}"
        type="application/octet-stream"
        sparkle:edSignature="${SIGNATURE}"
      />
    </item>
  </channel>
</rss>
EOF

echo "Appcast generated at $APPCAST_PATH"
echo "  Version: $VERSION"
echo "  DMG: $DMG_PATH ($LENGTH bytes)"
echo "  Download URL: $DOWNLOAD_URL"
echo "  Signature: present"
if [ -n "$RELEASE_NOTES" ]; then
  echo "  Release notes: included"
else
  echo "  Release notes: none (no tag v${VERSION} found or no conventional commits)"
fi
