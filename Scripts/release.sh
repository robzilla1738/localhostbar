#!/usr/bin/env bash
# Build, optionally sign/notarize, package DMG, and create a GitHub release.
#
# Usage:
#   ./Scripts/release.sh              # build + package only
#   ./Scripts/release.sh --sign       # also sign/notarize (needs env)
#   ./Scripts/release.sh --publish    # create gh release (needs gh auth)
#   ./Scripts/release.sh --sign --publish
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DO_SIGN=0
DO_PUBLISH=0

for arg in "$@"; do
  case "$arg" in
    --sign) DO_SIGN=1 ;;
    --publish) DO_PUBLISH=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

cd "$ROOT_DIR"

echo "==> Tests" >&2
swift test >&2

echo "==> Build app" >&2
APP_PATH="$("$ROOT_DIR/Scripts/build-app.sh")"

if [[ "$DO_SIGN" -eq 1 ]]; then
  echo "==> Sign & notarize" >&2
  APP_PATH="$("$ROOT_DIR/Scripts/sign-and-notarize.sh" "$APP_PATH")"
fi

echo "==> Package" >&2
DMG_PATH="$("$ROOT_DIR/Scripts/make-dmg.sh" "$APP_PATH")"
OUT_DIR="$(dirname "$DMG_PATH")"
ZIP_PATH="$OUT_DIR/LocalhostBar-$VERSION.zip"

echo "Packaged:" >&2
echo "  $DMG_PATH" >&2
echo "  $ZIP_PATH" >&2

if [[ "$DO_PUBLISH" -eq 1 ]]; then
  if ! command -v gh >/dev/null; then
    echo "error: gh CLI required for --publish" >&2
    exit 1
  fi

  TAG="v$VERSION"
  NOTES_FILE="$OUT_DIR/release-notes.md"
  if [[ -f "$ROOT_DIR/CHANGELOG.md" ]]; then
    # Extract section for this version if present.
    awk -v ver="$VERSION" '
      $0 ~ "^## \\[" ver "\\]" {p=1; print; next}
      p && $0 ~ /^## \[/ {exit}
      p {print}
    ' "$ROOT_DIR/CHANGELOG.md" > "$NOTES_FILE"
    if [[ ! -s "$NOTES_FILE" ]]; then
      echo "LocalhostBar $VERSION" > "$NOTES_FILE"
    fi
  else
    echo "LocalhostBar $VERSION" > "$NOTES_FILE"
  fi

  git tag -f "$TAG" 2>/dev/null || git tag "$TAG"
  git push origin "$TAG" 2>/dev/null || true

  gh release create "$TAG" \
    --title "LocalhostBar $VERSION" \
    --notes-file "$NOTES_FILE" \
    "$DMG_PATH" \
    "$ZIP_PATH" \
    "$OUT_DIR/SHA256SUMS" \
    || gh release upload "$TAG" "$DMG_PATH" "$ZIP_PATH" "$OUT_DIR/SHA256SUMS" --clobber

  echo "Published $TAG" >&2
fi

echo "$DMG_PATH"
