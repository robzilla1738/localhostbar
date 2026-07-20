#!/usr/bin/env bash
# Sign and notarize LocalhostBar.app for Gatekeeper distribution.
#
# Required env:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Robert Courson (9F2JXY8TCK)"
#
# Notarization (one of):
#   NOTARY_PROFILE (keychain profile from `xcrun notarytool store-credentials`)
#   default tries AC_PASSWORD
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: …" ./Scripts/sign-and-notarize.sh [.build/LocalhostBar.app]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/LocalhostBar.app}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Robert Courson (9F2JXY8TCK)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH — run Scripts/build-app.sh first" >&2
  exit 1
fi

echo "Signing $APP_PATH with $SIGN_IDENTITY" >&2

# Sign nested frameworks/XPC first (Sparkle)
if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
  find "$APP_PATH/Contents/Frameworks" -name "*.framework" -type d | while read -r fw; do
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$fw" 2>/dev/null || \
      codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$fw"
  done
  find "$APP_PATH/Contents/Frameworks" \( -name "*.xpc" -o -name "*.dylib" -o -name "Autoupdate" -o -name "Updater.app" \) 2>/dev/null | while read -r nested; do
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$nested" 2>/dev/null || true
  done
fi

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH" >&2

ZIP_PATH="${APP_PATH%.app}-signed.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Submitting for notarization (profile: $NOTARY_PROFILE)…" >&2
  xcrun notarytool submit "$ZIP_PATH" --wait --keychain-profile "$NOTARY_PROFILE"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose "$APP_PATH" >&2 || true
else
  echo "Signed (not notarized). No notarytool keychain profile '$NOTARY_PROFILE'." >&2
fi

echo "$APP_PATH"
