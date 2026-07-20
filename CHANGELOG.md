# Changelog

All notable changes to LocalhostBar are documented in this file.

## [0.1.0] — 2026-07-20

### Added

- Menu bar app listing localhost TCP listeners with smart names from process + HTTP metadata
- HTTP probing for openable web UIs (page titles, content type, server header)
- Open in browser, copy URL / port / PID, stop safe processes
- Hide background/system services by default with toggle
- Preferences: refresh interval, show background, launch at login
- Context menus and ⌘R refresh
- Project root detection via package markers (`package.json`, `Cargo.toml`, etc.)
- **Sparkle auto-updates** with EdDSA-signed appcast on GitHub Releases
- MIT license, security policy, CI, signed-release packaging scripts

### Security

- Only `SIGTERM` user-owned, non-protected processes
- No telemetry; probes limited to localhost (except Sparkle update checks)
- Sparkle private key never committed; public key in `Config/` and Info.plist
