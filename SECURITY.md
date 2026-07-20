# Security Policy

## What LocalhostBar does

LocalhostBar is a **local-only** macOS menu bar utility. It:

- Lists TCP listeners reachable on localhost (via `lsof`)
- Reads process command lines and working directories (via `ps` / `lsof`)
- Optionally probes `http(s)://localhost:<port>` to detect openable web UIs
- Can send `SIGTERM` to **user-owned, non-protected** processes you choose to stop

## What it does **not** do

- No analytics, crash reporting, or telemetry
- No network requests except to `localhost` / loopback during HTTP probes
- No upload of process lists or paths
- No privilege escalation; it cannot stop processes you do not own
- No injection into other apps

## Protected processes

System and app-managed services (AirPlay, Continuity, Docker backend, Adobe helpers, etc.) appear with a lock and **cannot** be stopped from the UI.

## Reporting a vulnerability

If you find a security issue, please open a private security advisory on GitHub or email the maintainer via the contact listed on the repository. Please do not open a public issue for exploitable bugs until a fix is available.

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |
