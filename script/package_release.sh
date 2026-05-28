#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacArkPet"
BUNDLE_ID="${BUNDLE_ID:-io.github.macarkpet.MacArkPet}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-macOS.zip"

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp -R "$ROOT_DIR/Resources/." "$APP_RESOURCES/"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/NOTICE.md" "$APP_RESOURCES/"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.entertainment</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [ -x /usr/bin/xattr ]; then
  /usr/bin/xattr -cr "$APP_BUNDLE"
fi

if [ -x /usr/bin/codesign ]; then
  /usr/bin/codesign --force --deep --sign "${CODESIGN_IDENTITY:--}" "$APP_BUNDLE"
  if [ -x /usr/bin/xattr ]; then
    /usr/bin/xattr -cr "$APP_BUNDLE"
  fi
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [ -x /usr/bin/xattr ]; then
  /usr/bin/xattr -cr "$APP_BUNDLE"
fi

if [ -x /usr/bin/codesign ]; then
  VERIFY_DIR="$(mktemp -d)"
  /usr/bin/ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/$APP_NAME.app"
  rm -rf "$VERIFY_DIR"
fi

echo "Packaged $ZIP_PATH"
