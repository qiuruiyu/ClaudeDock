#!/bin/bash
# Build ClaudeDock.app — a proper macOS app bundle wrapping the SwiftPM executable.
# Output: .build/ClaudeDock.app
# Usage: bash Scripts/build-app.sh [release|debug]   # default: release
set -euo pipefail

cd "$(dirname "$0")/.."
source Scripts/dev/env.sh

CONFIG="${1:-release}"
echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)
EXE="$BIN_PATH/ClaudeDock"
[ -x "$EXE" ] || { echo "missing executable at $EXE"; exit 1; }

APP=".build/ClaudeDock.app"
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$EXE" "$APP/Contents/MacOS/ClaudeDock"
cp "Sources/ClaudeDock/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Sources/ClaudeDock/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

touch "$APP"

echo "==> done: $APP"
echo "Launch with: open $APP"
echo "Or copy to /Applications: cp -R $APP /Applications/"
