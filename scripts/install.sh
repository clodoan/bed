#!/usr/bin/env bash
# Install Lo fi house from the latest GitHub Release.
#   curl -fsSL https://raw.githubusercontent.com/clodoan/bed/main/scripts/install.sh | bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Lo fi house is a Mac menu-bar app." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Lo fi house is Apple Silicon only (macOS 14+)." >&2
  exit 1
fi

APP_NAME="Lo fi house.app"
DEST="/Applications/${APP_NAME}"
ZIP_URL="https://github.com/clodoan/bed/releases/latest/download/LofiHouse.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Lo fi house…"
if ! curl -fL --retry 3 --retry-delay 1 -o "$TMP/LofiHouse.zip" "$ZIP_URL"; then
  echo "Could not download ${ZIP_URL}" >&2
  echo "Get LofiHouse.zip from https://github.com/clodoan/bed/releases/latest — not Source code (zip)." >&2
  exit 1
fi

ditto -x -k "$TMP/LofiHouse.zip" "$TMP"
APP="$(find "$TMP" -name "*.app" -maxdepth 3 -print -quit)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "The download was not the app. Use LofiHouse.zip from the latest release, not Source code." >&2
  exit 1
fi

# Quarantine on an ad-hoc signed app is what macOS reports as "cannot be installed".
xattr -cr "$APP" 2>/dev/null || true
rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

echo "Installed ${DEST}"
open "$DEST"
