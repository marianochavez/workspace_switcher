#!/bin/bash
set -euo pipefail

APP_NAME="WorkspaceSwitcher"
SCHEME="WorkspaceSwitcher"
PROJECT="WorkspaceSwitcher.xcodeproj"
BUILD_DIR="build"
DMG_DIR="$BUILD_DIR/dmg"
DMG_TEMP="$BUILD_DIR/$APP_NAME-temp.dmg"
DMG_OUTPUT="$BUILD_DIR/$APP_NAME.dmg"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
VOL_NAME="$APP_NAME"

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
ln -s /Applications "$DMG_DIR/Applications"

# Create a read-write DMG first so we can customize the Finder view
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDRW \
    -size 10m \
    "$DMG_TEMP"

# Mount the writable DMG
DEVICE=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep "/Volumes/$VOL_NAME" | awk '{print $1}')
sleep 1

echo "==> Customizing DMG layout..."
# Use AppleScript to set Finder view options (icon view, positions, window size)
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        delay 2
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 200, 900, 520}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set text size of theViewOptions to 13
        delay 1
        set position of item "$APP_NAME.app" of container window to {140, 160}
        set position of item "Applications" of container window to {360, 160}
        delay 1
        update without registering applications
        close
    end tell
end tell
APPLESCRIPT

# Set the volume icon
if [ -f "$DMG_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns" ]; then
    cp "$DMG_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns" "/Volumes/$VOL_NAME/.VolumeIcon.icns"
    SetFile -c icnC "/Volumes/$VOL_NAME/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "/Volumes/$VOL_NAME" 2>/dev/null || true
fi

sync
hdiutil detach "$DEVICE" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUTPUT"
rm -f "$DMG_TEMP"

echo ""
echo "==> Done!"
echo "    DMG: $DMG_OUTPUT"
echo "    Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
