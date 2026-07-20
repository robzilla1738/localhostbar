#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure icon exists for local runs.
if [[ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  "$ROOT_DIR/Scripts/generate-icon.sh" || true
fi

APP_PATH="$("$ROOT_DIR/Scripts/build-app.sh")"

/usr/bin/pkill -x "LocalhostBar" 2>/dev/null || true
sleep 0.2
open "$APP_PATH"
