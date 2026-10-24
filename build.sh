#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/RMOS Spotlight.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "Building RM-OS Spotlight for $ARCH..."

xcrun --sdk macosx swiftc \
  -O \
  -target "$ARCH-apple-macos13.0" \
  -o "$MACOS_DIR/RMOSSpotlight" \
  "$ROOT/Sources/Config.swift" \
  "$ROOT/Sources/SearchEngine.swift" \
  "$ROOT/Sources/NativeSearchField.swift" \
  "$ROOT/Sources/LiquidGlassBackground.swift" \
  "$ROOT/Sources/FileLocator.swift" \
  "$ROOT/Sources/SpotlightView.swift" \
  "$ROOT/Sources/main.swift" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -lsqlite3

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

xattr -cr "$APP"
codesign --force --deep --sign "-" "$APP"
codesign --verify --deep --strict "$APP"

echo "Build successful: $APP"
