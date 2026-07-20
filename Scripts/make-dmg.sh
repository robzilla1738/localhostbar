#!/usr/bin/env bash
# Create a simple DMG containing LocalhostBar.app
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
APP_PATH="${1:-$ROOT_DIR/.build/LocalhostBar.app}"
OUT_DIR="${2:-$ROOT_DIR/.build/dist}"
DMG_NAME="LocalhostBar-$VERSION.dmg"
DMG_PATH="$OUT_DIR/$DMG_NAME"
VOL_NAME="LocalhostBar"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
STAGE="$OUT_DIR/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >&2

rm -rf "$STAGE"

# Also write a zip for users who prefer it.
ZIP_PATH="$OUT_DIR/LocalhostBar-$VERSION.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

shasum -a 256 "$DMG_PATH" "$ZIP_PATH" | tee "$OUT_DIR/SHA256SUMS" >&2

echo "$DMG_PATH"
