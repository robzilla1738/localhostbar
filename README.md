# LocalhostBar

Tiny macOS menu-bar utility for local development ports.

LocalhostBar scans TCP listeners on localhost, **pulls process and HTTP metadata** to name them (project folders, package files, page titles, known services), and lets you open or stop them without hunting through terminals.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

## Install (out of the box)

1. Download **LocalhostBar-*.dmg** (or `.zip`) from [GitHub Releases](https://github.com/robzilla1738/localhostbar/releases)
2. Open the DMG and drag **LocalhostBar** to **Applications**
3. Open LocalhostBar once (Gatekeeper-friendly when using the signed/notarized release)
4. Look for the **network** icon in the menu bar

Signed releases are built with **Developer ID** and notarized when credentials allow. The app checks for updates automatically via **Sparkle** (signed appcast on GitHub Releases).

### Build from source

```sh
git clone https://github.com/robzilla1738/localhostbar.git
cd localhostbar
./Scripts/run.sh
```

Requires macOS 13+ and a full Xcode toolchain (Command Line Tools alone cannot run `swift test` because XCTest is missing). If you have Xcode (or Xcode-beta) installed:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# or: export DEVELOPER_DIR=$HOME/Downloads/Xcode-beta.app/Contents/Developer
swift test
./Scripts/build-app.sh
```

The app bundle is written to `.build/LocalhostBar.app`.

## Features

- Lists every reachable `localhost` / loopback TCP listener
- **Metadata-based names** from:
  - HTML page `<title>` (HTTP/HTTPS probe)
  - Project folder / package markers (`package.json`, `Cargo.toml`, `go.mod`, …)
  - Known services (Docker DBs, AirPlay, Ollama, …)
- One-click open in your browser when the port speaks HTTP
- Copy URL, port, or PID (buttons + context menu)
- Stop user-owned dev processes (`SIGTERM`); system services stay locked
- Background services hidden by default (toggle in the popover or Preferences)
- Launch at login, configurable refresh interval
- **Sparkle auto-updates** from GitHub Releases
- No telemetry — process lists and probes stay on your machine

## Usage

1. Click the network icon in the menu bar  
2. Click a row to open it in your browser (when openable)  
3. Use the copy button or right-click for Copy URL / Port / PID  
4. Press **×** to stop a safe, user-owned process  
5. Check **Background** to reveal system and app-managed ports  
6. Open Preferences (gear) for refresh interval, launch at login, and **Check for Updates…**

## Updates

LocalhostBar uses [Sparkle](https://sparkle-project.org) to check a public appcast:

```text
https://github.com/robzilla1738/localhostbar/releases/latest/download/appcast.xml
```

- Automatic checks run daily after launch  
- Manual: **Preferences → Check for Updates…** (or right-click the gear)  
- Update archives are EdDSA-signed; only the **public** key ships in the app  

Maintainers: private key lives in `Secrets/sparkle_eddsa_private` (gitignored). See [CONTRIBUTING.md](CONTRIBUTING.md).

## Requirements

- macOS 13 Ventura or later  
- No special accessibility permissions for normal use  

## Security & privacy

| Behavior | Detail |
|----------|--------|
| Network | Probes `localhost` only; update checks hit GitHub Releases appcast/assets |
| Data | Process list never uploaded |
| Stop | `SIGTERM` only; never for protected/system processes or other users' PIDs |
| Telemetry | None |
| Updates | Sparkle + EdDSA; private signing key never committed |

See [SECURITY.md](SECURITY.md).

## Development

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # if needed
swift test                 # unit tests (needs full Xcode)
./Scripts/build-app.sh     # build .app (embeds Sparkle)
./Scripts/run.sh           # build and launch
./Scripts/generate-icon.sh # regenerate AppIcon.icns
```

### Project layout

```text
Sources/LocalhostCore/   # scanner, HTTP probe, models, AppMetadata
Sources/LocalhostBar/    # menu bar UI, preferences, Sparkle updater
Config/                  # public Sparkle EdDSA key (safe to commit)
Secrets/                 # private keys (gitignored)
Scripts/                 # build, sign, notarize, appcast, release
```

### Signed release (maintainers)

```sh
export DEVELOPER_DIR=…/Xcode.app/Contents/Developer
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="AC_PASSWORD"   # notarytool keychain profile
export SPARKLE_TOOLS=/path/to/Sparkle-2.x   # contains bin/sign_update
./Scripts/release.sh --sign --publish
```

This builds, codesigns (and notarizes when the profile works), packages DMG/ZIP, generates `appcast.xml`, and creates the GitHub Release.

## License

[MIT](LICENSE)
