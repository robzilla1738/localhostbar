# Contributing

Thanks for helping improve LocalhostBar.

## Requirements

- macOS 13+
- Xcode 16+ / Swift 6 toolchains
- Optional: Developer ID certificate for signed builds

## Develop

```sh
swift test
./Scripts/run.sh
```

Core logic lives in `Sources/LocalhostCore` (no AppKit). UI is in `Sources/LocalhostBar`.

## Guidelines

- Keep the app local-only — no telemetry or remote network calls
- Prefer small, tested changes to naming/heuristics
- Neutralize personal paths in fixtures (`/Users/dev/...`)
- Update `CHANGELOG.md` for user-visible changes
- Bump `VERSION` for releases

## Release (maintainers)

```sh
# Package only
./Scripts/release.sh

# Sign + notarize (needs SIGN_IDENTITY and notary credentials)
./Scripts/release.sh --sign

# Publish GitHub Release
./Scripts/release.sh --sign --publish
```

## Code of conduct

Be kind. Assume good intent. No harassment.
