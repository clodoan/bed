#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

BIN=".build/release/LofiHouse"
APP="Lo fi house.app"

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
cp "$BIN" "$APP/Contents/MacOS/LofiHouse"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
cp Resources/toddler-room.png "$APP/Contents/Resources/"
cp Resources/dancer/*.png "$APP/Contents/Resources/"
cp Resources/desk/*.png "$APP/Contents/Resources/"
cp Resources/PressStart2P-Regular.ttf "$APP/Contents/Resources/"
cp Resources/PressStart2P-OFL.txt "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/LofiHouse"

# Old product name — a leftover Bed.app would keep launching as Bed.
rm -rf Bed.app

if [[ -z "${CI:-}" ]]; then
  if [[ -d /Applications/Bed.app ]]; then
    rm -rf /Applications/Bed.app
  fi
  ditto "$APP" "/Applications/$APP"
  echo "Built $APP"
  echo "open \"/Applications/$APP\""
else
  echo "Built $APP"
fi
