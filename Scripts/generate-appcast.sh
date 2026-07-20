#!/usr/bin/env bash
# Sign a ZIP update archive with Sparkle EdDSA and emit appcast.xml
#
# Usage:
#   ./Scripts/generate-appcast.sh path/to/LocalhostBar-0.1.0.zip [output-dir]
#
# Env:
#   SPARKLE_PRIVATE_KEY_FILE  default: Secrets/sparkle_eddsa_private
#   SIGN_UPDATE_BIN           default: auto-discover from SPARKLE_TOOLS or PATH
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
ZIP_PATH="${1:-}"
OUT_DIR="${2:-$ROOT_DIR/.build/dist}"
KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$ROOT_DIR/Secrets/sparkle_eddsa_private}"
FEED_BASE="https://github.com/robzilla1738/localhostbar/releases/download/v${VERSION}"

if [[ -z "$ZIP_PATH" || ! -f "$ZIP_PATH" ]]; then
  echo "usage: $0 path/to/LocalhostBar-VERSION.zip [out-dir]" >&2
  exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
  echo "error: Sparkle private key not found at $KEY_FILE" >&2
  echo "  Generate with Sparkle generate_keys and export: generate_keys --account localhostbar -x Secrets/sparkle_eddsa_private" >&2
  exit 1
fi

SIGN_UPDATE_BIN="${SIGN_UPDATE_BIN:-}"
if [[ -z "$SIGN_UPDATE_BIN" ]]; then
  for candidate in \
    "${SPARKLE_TOOLS:-}/bin/sign_update" \
    "$ROOT_DIR/Tools/Sparkle/bin/sign_update" \
    "$(command -v sign_update 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      SIGN_UPDATE_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$SIGN_UPDATE_BIN" || ! -x "$SIGN_UPDATE_BIN" ]]; then
  echo "error: sign_update not found. Set SIGN_UPDATE_BIN or SPARKLE_TOOLS to Sparkle release tools." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
ZIP_NAME="$(basename "$ZIP_PATH")"
FILE_SIZE="$(stat -f%z "$ZIP_PATH" 2>/dev/null || stat -c%s "$ZIP_PATH")"

# sign_update prints: sparkle:edSignature="..." length="..."
# Prefer explicit key file; fall back to keychain account localhostbar.
SIGN_OUT="$("$SIGN_UPDATE_BIN" --account localhostbar --ed-key-file "$KEY_FILE" "$ZIP_PATH" 2>&1)" \
  || SIGN_OUT="$("$SIGN_UPDATE_BIN" --ed-key-file "$KEY_FILE" "$ZIP_PATH" 2>&1)" \
  || SIGN_OUT="$("$SIGN_UPDATE_BIN" --account localhostbar "$ZIP_PATH" 2>&1)"

echo "sign_update output: $SIGN_OUT" >&2

# Parse edSignature attribute
ED_SIG="$(printf '%s\n' "$SIGN_OUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | head -1)"
if [[ -z "$ED_SIG" ]]; then
  ED_SIG="$(printf '%s\n' "$SIGN_OUT" | sed -n 's/.*edSignature=\([^ ]*\).*/\1/p' | head -1 | tr -d '"')"
fi
LENGTH="$(printf '%s\n' "$SIGN_OUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p' | head -1)"
if [[ -z "$LENGTH" ]]; then
  LENGTH="$FILE_SIZE"
fi

if [[ -z "$ED_SIG" ]]; then
  echo "error: could not parse edSignature from sign_update" >&2
  echo "$SIGN_OUT" >&2
  exit 1
fi

PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
DOWNLOAD_URL="${FEED_BASE}/${ZIP_NAME}"
APPCAST="$OUT_DIR/appcast.xml"

cat > "$APPCAST" <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>LocalhostBar</title>
    <link>https://github.com/robzilla1738/localhostbar</link>
    <description>LocalhostBar updates</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>LocalhostBar $VERSION</h2>
        <p>See the <a href="https://github.com/robzilla1738/localhostbar/releases/tag/v$VERSION">release notes</a>.</p>
      ]]></description>
      <enclosure
        url="$DOWNLOAD_URL"
        length="$LENGTH"
        type="application/octet-stream"
        sparkle:edSignature="$ED_SIG"
      />
    </item>
  </channel>
</rss>
XML

echo "Wrote $APPCAST" >&2
echo "$APPCAST"
