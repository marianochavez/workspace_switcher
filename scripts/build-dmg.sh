#!/bin/bash
set -euo pipefail

APP_NAME="WorkspaceSwitcher"
SCHEME="WorkspaceSwitcher"
PROJECT="WorkspaceSwitcher.xcodeproj"
BUILD_DIR="build"
DMG_DIR="$BUILD_DIR/dmg"
DMG_OUTPUT="$BUILD_DIR/$APP_NAME.dmg"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"

cd "$(dirname "$0")/.."

echo "==> Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$DMG_DIR"

echo "==> Building Release archive..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    DEVELOPMENT_TEAM="" \
    2>&1 | tail -5

echo "==> Exporting app from archive..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    # Fallback: try to find it in the archive
    APP_PATH=$(find "$ARCHIVE_PATH" -name "$APP_NAME.app" -type d | head -1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Could not find $APP_NAME.app in archive"
    echo "Archive contents:"
    find "$ARCHIVE_PATH" -type d -maxdepth 4
    exit 1
fi

cp -R "$APP_PATH" "$DMG_DIR/"

echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "$DMG_DIR/$APP_NAME.app"

echo "==> Creating DMG..."
# Create a nice DMG with a symlink to /Applications
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

echo ""
echo "==> Done!"
echo "    DMG: $DMG_OUTPUT"
echo "    Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
