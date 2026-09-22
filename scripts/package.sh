#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh

# ditto preserves the .app bundle; `zip -r` of the repo does not.
# --norsrc/--noextattr drop AppleDouble `._` files so Finder and unzip
# both yield a sealed bundle. Keep the zip name space-free so GitHub's
# download URL matches the README.
OUT="${1:-$HOME/Desktop/LofiHouse.zip}"
rm -f "$OUT"
ditto -c -k --keepParent --norsrc --noextattr "Lo fi house.app" "$OUT"

echo "Packed $OUT"
unzip -l "$OUT" | head -20
