#!/bin/bash
set -euo pipefail

# WorkspaceSwitcher Installer
# Downloads the latest release and removes the quarantine flag

APP_NAME="WorkspaceSwitcher"
INSTALL_DIR="/Applications"
REPO="marianochavez/workspace_switcher"

echo "==> Fetching latest release..."
DMG_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*\.dmg" \
    | cut -d '"' -f 4)

if [ -z "$DMG_URL" ]; then
    echo "ERROR: Could not find DMG in latest release."
    exit 1
fi

VERSION=$(echo "$DMG_URL" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
TEMP_DMG="/tmp/$APP_NAME-$VERSION.dmg"

echo "==> Downloading $APP_NAME v$VERSION..."
curl -L -o "$TEMP_DMG" "$DMG_URL"

echo "==> Mounting DMG..."
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -nobrowse | grep "/Volumes" | awk '{print $NF}')

echo "==> Installing to $INSTALL_DIR..."
# Remove old version if exists
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$MOUNT_DIR/$APP_NAME.app" "$INSTALL_DIR/"

echo "==> Removing quarantine flag..."
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo "==> Cleaning up..."
hdiutil detach "$MOUNT_DIR" -quiet
rm -f "$TEMP_DMG"

echo ""
echo "==> Done! $APP_NAME v$VERSION installed."
echo "    Launch it from Applications or Spotlight."
