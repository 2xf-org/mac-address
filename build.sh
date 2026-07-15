#!/bin/bash
# Builds MAC Address.app — a menu bar app for changing network interface addresses.
# Requires: Xcode command line tools (swiftc), iconutil. No Xcode project needed.
set -euo pipefail
cd "$(dirname "$0")"

APP="MAC Address.app"
EXEC_NAME="MACAddress"
MIN_MACOS="13.0"
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="${BUILD_NUMBER:-${VERSION//./}}"

echo "› Generating icons…"
mkdir -p build
xcrun swift tools/icons.swift Resources build/AppIcon.iconset .github >/dev/null
xcrun swift tools/menu-preview.swift .github/menu.png >/dev/null
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

echo "› Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/menubar.png Resources/menubar@2x.png "$APP/Contents/Resources/"

echo "› Compiling Swift…"
ARCH="$(uname -m)"
xcrun swiftc -O \
    -swift-version 5 \
    -target "${ARCH}-apple-macos${MIN_MACOS}" \
    -framework AppKit -framework SwiftUI \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/${EXEC_NAME}"

# Ad-hoc signing is enough for local builds. Release zips can be replaced with
# a Developer ID signed build without changing the app.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Built $(pwd)/$APP ($VERSION)"
