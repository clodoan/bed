#!/bin/bash
# Double-click this — not the house icon. GitHub-quarantined apps
# are what macOS reports as "cannot be installed".
set -euo pipefail
cd "$(dirname "$0")"

APP="Lo fi house.app"
DEST="/Applications/${APP}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Lo fi house is a Mac menu-bar app." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Lo fi house is Apple Silicon only (macOS 14+)." >&2
  exit 1
fi
if [[ ! -d "$APP" ]]; then
  echo "Put this script next to ${APP} (inside the unzipped LofiHouse folder)." >&2
  exit 1
fi

xattr -cr "$APP" 2>/dev/null || true
rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

echo "Installed ${DEST}"
open "$DEST"
