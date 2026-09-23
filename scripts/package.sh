#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh

# One top-level folder so Safari does not dump the .app into Downloads
# (double-clicking that is what Gatekeeper calls "cannot be installed").
# ditto preserves the bundle; `zip -r` of the repo does not.
# --norsrc/--noextattr drop AppleDouble `._` files so Finder and unzip
# both yield a sealed bundle. Keep the zip name space-free so GitHub's
# download URL matches the README.
OUT="${1:-$HOME/Desktop/LofiHouse.zip}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

ROOT="$STAGE/Install Lo fi house"
mkdir -p "$ROOT"
ditto --norsrc --noextattr "Lo fi house.app" "$ROOT/Lo fi house.app"
cp scripts/Install.command "$ROOT/Install.command"
chmod +x "$ROOT/Install.command"
cat > "$ROOT/Read Me.txt" <<'EOF'
Lo fi house — late-night radio in the Mac menu bar.
Apple Silicon, macOS 14+.

Double-click Install.command

Do not open the house icon from this folder. GitHub marks the
download as quarantined, and macOS then says the app cannot be
installed. Install.command copies it to /Applications and clears
that flag.

Or in Terminal:

  curl -fsSL https://raw.githubusercontent.com/clodoan/bed/main/scripts/install.sh | bash
EOF

rm -f "$OUT"
ditto -c -k --norsrc --noextattr "$STAGE" "$OUT"

echo "Packed $OUT"
unzip -l "$OUT" | head -25
