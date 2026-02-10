#!/bin/bash
set -e

APP_NAME="Frame"
BUILD_DIR=".build/Build/Products/Release"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${BUILD_DIR}/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || echo "0.0.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
# Use /tmp for temporary files
DMG_TEMP="/tmp/${APP_NAME}_dmg_temp"
DMG_TEMP_IMG="/tmp/temp_${DMG_NAME}"
DMG_FINAL="dist/${DMG_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if app bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    error "App bundle not found at ${APP_BUNDLE}. Run 'make release' first."
fi

info "Creating DMG for ${APP_NAME} v${VERSION}..."

# Clean up any previous temp directory
rm -rf "${DMG_TEMP}"
rm -f "${DMG_TEMP_IMG}"

# Create temp directory with app and Applications symlink
info "Setting up DMG contents..."
mkdir -p "dist"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Optional: Add background image if it exists
if [ -f "scripts/dmg-background.png" ]; then
    mkdir -p "${DMG_TEMP}/.background"
    cp "scripts/dmg-background.png" "${DMG_TEMP}/.background/background.png"
fi

# Calculate the size needed (app size + 10MB buffer)
APP_SIZE=$(du -sm "${APP_BUNDLE}" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

info "Creating temporary DMG (${DMG_SIZE}MB)..."

# Create temporary DMG
hdiutil create -srcfolder "${DMG_TEMP}" \
    -volname "${APP_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "${DMG_TEMP_IMG}" \
    -quiet

info "Mounting DMG for customization..."

# Mount the DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP_IMG}" | grep "/Volumes/${APP_NAME}" | tail -1 | cut -f3-)

if [ -z "${MOUNT_DIR}" ]; then
    error "Failed to mount DMG"
fi

info "Customizing DMG window..."

# Set DMG window properties using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "${APP_NAME}.app" of container window to {120, 150}
        set position of item "Applications" of container window to {380, 150}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Give Finder time to write changes
sync
sleep 5

info "Finalizing DMG..."

# Unmount
hdiutil detach "${MOUNT_DIR}" -quiet

rm -f "${DMG_FINAL}"
hdiutil convert "${DMG_TEMP_IMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}" \
    -quiet

# Clean up
rm -rf "${DMG_TEMP}"
rm -f "${DMG_TEMP_IMG}"

# Get final size
FINAL_SIZE=$(du -h "${DMG_FINAL}" | cut -f1)

info "✓ Successfully created ${DMG_FINAL} (${FINAL_SIZE})"
