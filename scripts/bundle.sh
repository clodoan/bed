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

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Bed"
cp Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/Bed"

echo "Built $APP"
echo "open $APP"
