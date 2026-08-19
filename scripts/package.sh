#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh

# ditto preserves the .app bundle; `zip -r` of the repo does not.
OUT="${1:-$HOME/Desktop/Bed.zip}"
rm -f "$OUT"
ditto -c -k --keepParent Bed.app "$OUT"

echo "Packed $OUT"
unzip -l "$OUT" | head -20
