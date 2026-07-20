#!/usr/bin/env bash
# Sign and notarize LocalhostBar.app for Gatekeeper distribution.
#
# Required env:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#
# Notarization (one of):
#   APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID
#   or NOTARY_PROFILE (keychain profile from `xcrun notarytool store-credentials`)
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: …" ./Scripts/sign-and-notarize.sh [.build/LocalhostBar.app]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/LocalhostBar.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH — run Scripts/build-app.sh first" >&2
  exit 1
fi

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  echo "error: set SIGN_IDENTITY to your Developer ID Application identity" >&2
  echo "  security find-identity -v -p codesigning" >&2
  exit 1
fi

echo "Signing $APP_PATH with $SIGN_IDENTITY" >&2
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

submit_args=()
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  submit_args=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  submit_args=(
    --apple-id "$APPLE_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
    --team-id "$APPLE_TEAM_ID"
  )
else
  echo "Signed (not notarized). Set NOTARY_PROFILE or APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID to notarize." >&2
  echo "$APP_PATH"
  exit 0
fi

echo "Submitting for notarization…" >&2
xcrun notarytool submit "$ZIP_PATH" --wait "${submit_args[@]}"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

spctl --assess --type execute --verbose "$APP_PATH" >&2 || true

echo "$APP_PATH"
