#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="LocalhostBar"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUNDLE_ID="com.robzilla1738.localhostbar"
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
# Prefer Xcode-beta when present so XCTest/SPM binary frameworks resolve consistently.
if [[ -z "${DEVELOPER_DIR:-}" && -d "/Users/robert/Downloads/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Users/robert/Downloads/Xcode-beta.app/Contents/Developer"
fi
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
RESOURCES_DIR="$ROOT_DIR/Resources"
PUBLIC_ED_KEY="$(tr -d '[:space:]' < "$ROOT_DIR/Config/SparklePublicEDKey.txt")"
FEED_URL="https://github.com/robzilla1738/localhostbar/releases/latest/download/appcast.xml"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" >&2

# Resolve built binary path (triple-prefixed layout on newer toolchains).
if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  FOUND="$(find "$ROOT_DIR/.build" -path "*/$CONFIGURATION/$APP_NAME" -type f -perm -111 2>/dev/null | head -1 || true)"
  if [[ -n "$FOUND" ]]; then
    EXECUTABLE_PATH="$FOUND"
  fi
fi
if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "error: built executable not found" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
  cp "$RESOURCES_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Embed Sparkle.framework from SPM artifacts or .build products.
embed_sparkle() {
  local framework=""
  # Binary target XCFramework slice
  framework="$(find "$ROOT_DIR/.build" -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -type d 2>/dev/null | head -1 || true)"
  if [[ -z "$framework" ]]; then
    framework="$(find "$ROOT_DIR/.build" -path '*/Sparkle.framework' -type d 2>/dev/null | grep -v xcframework | head -1 || true)"
  fi
  if [[ -z "$framework" ]]; then
    echo "error: Sparkle.framework not found under .build — ensure Sparkle SPM dependency resolved" >&2
    return 1
  fi
  echo "Embedding Sparkle from $framework" >&2
  rsync -a --delete "$framework" "$APP_DIR/Contents/Frameworks/"
}

embed_sparkle

# Ensure rpath finds Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "$APP_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. MIT License.</string>
    <key>CFBundleGetInfoString</key>
    <string>$APP_NAME $VERSION</string>
    <key>SUFeedURL</key>
    <string>$FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$PUBLIC_ED_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>SUAllowsAutomaticUpdates</key>
    <true/>
    <key>SUShowReleaseNotes</key>
    <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "$APP_DIR"
