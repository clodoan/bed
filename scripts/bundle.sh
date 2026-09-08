#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

BIN=".build/release/Bed"
APP="Bed.app"

if [[ ! -x "$BIN" ]]; then
  echo "missing binary: $BIN" >&2
  exit 1
fi

MAKE_ICNS=".build/make-icns"
if [[ ! -x "$MAKE_ICNS" || scripts/make-icns.swift -nt "$MAKE_ICNS" ]]; then
    mkdir -p .build
    swiftc -O -framework AppKit -o "$MAKE_ICNS" scripts/make-icns.swift
fi
"$MAKE_ICNS" Resources/AppIcon.png Resources/AppIcon.icns

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Bed"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
cp Resources/night-desk.png "$APP/Contents/Resources/"
cp Resources/toddler-room.png "$APP/Contents/Resources/"
cp Resources/dancer/*.png "$APP/Contents/Resources/"
cp Resources/desk/*.png "$APP/Contents/Resources/"
cp Resources/PressStart2P-Regular.ttf "$APP/Contents/Resources/"
cp Resources/PressStart2P-OFL.txt "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/Bed"

echo "Built $APP"
echo "open $APP"
