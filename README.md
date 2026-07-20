# LocalhostBar

Tiny macOS menu-bar utility for local development ports.

LocalhostBar scans TCP listeners on localhost, names them from project folders, package metadata, and HTTP page titles, and lets you open or stop them without hunting through terminals.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

## Features

- Lists every reachable `localhost` / loopback listener
- Smart names from page titles, project roots, and known services
- One-click open in your browser (when the port speaks HTTP)
- Copy URL, port, or PID
- Stop user-owned dev processes (`SIGTERM`); system services stay locked
- Background services hidden by default (toggle in the popover or Preferences)
- Launch at login, configurable refresh interval
- No telemetry — everything stays on your machine

## Install

### Download (recommended)

Grab the latest **DMG** or **ZIP** from [GitHub Releases](https://github.com/robzilla1738/localhostbar/releases), open it, and drag **LocalhostBar** to Applications.

Signed and notarized builds pass Gatekeeper. If you build from source yourself, you may need to right-click → Open the first time unless you sign the app.

### Build from source

```sh
git clone https://github.com/robzilla1738/localhostbar.git
cd localhostbar
./Scripts/run.sh
```

The app bundle is written to `.build/LocalhostBar.app`.

## Usage

1. Click the network icon in the menu bar
2. Click a row to open it in your browser (when openable)
3. Use the copy button or right-click for Copy URL / Port / PID
4. Press **×** to stop a safe, user-owned process
5. Check **Background** to reveal system and app-managed ports
6. Open Preferences (gear) for refresh interval and launch at login

## Requirements

- macOS 13 Ventura or later
- No special accessibility permissions required for normal use

## Security & privacy

| Behavior | Detail |
|----------|--------|
| Network | Only probes `localhost` / loopback |
| Data | Process list never leaves your Mac |
| Stop | `SIGTERM` only; never for protected/system processes or other users' PIDs |
| Telemetry | None |

See [SECURITY.md](SECURITY.md) for the full policy.

## Development

```sh
swift test                 # unit tests
./Scripts/build-app.sh     # build .app bundle
./Scripts/run.sh           # build and launch
./Scripts/generate-icon.sh # regenerate AppIcon.icns
```

### Project layout

```text
Sources/LocalhostCore/   # scanner, HTTP probe, models
Sources/LocalhostBar/    # menu bar UI, preferences
Scripts/                 # build, sign, notarize, release
```

### Signed release (maintainers)

```sh
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="notary-profile"   # from notarytool store-credentials
./Scripts/release.sh --sign --publish
```

## License

[MIT](LICENSE)
