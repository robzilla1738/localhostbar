# Contributing

Thanks for helping improve LocalhostBar.

## Requirements

- macOS 13+
- **Full Xcode** (or Xcode-beta), not Command Line Tools alone — XCTest is required for `swift test`
- Optional: Developer ID certificate + notarytool profile for signed builds
- Optional: Sparkle `sign_update` tools for appcast generation

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# or Xcode-beta:
# export DEVELOPER_DIR=$HOME/Downloads/Xcode-beta.app/Contents/Developer
```

## Develop

```sh
swift test
./Scripts/run.sh
```

- Core logic: `Sources/LocalhostCore` (no AppKit / Sparkle)
- UI + updates: `Sources/LocalhostBar`
- Public Sparkle key: `Config/SparklePublicEDKey.txt`
- Private Sparkle key: `Secrets/sparkle_eddsa_private` (**never commit**)

## Guidelines

- Keep the app local-only for process data — no analytics
- Update checks may contact GitHub Releases only
- Prefer small, tested changes to naming/heuristics
- Neutral fixture paths in tests (`/Users/dev/...`)
- Update `CHANGELOG.md` for user-visible changes
- Bump `VERSION` and `AppMetadata.version` together for releases

## Sparkle keys (maintainers)

```sh
# Once per machine/org (account: localhostbar)
./bin/generate_keys --account localhostbar
./bin/generate_keys --account localhostbar -p > Config/SparklePublicEDKey.txt
./bin/generate_keys --account localhostbar -x Secrets/sparkle_eddsa_private
chmod 600 Secrets/sparkle_eddsa_private
```

Download Sparkle release tools from [sparkle-project/Sparkle releases](https://github.com/sparkle-project/Sparkle/releases) (`bin/sign_update`, `bin/generate_keys`).

## Release (maintainers)

```sh
export SIGN_IDENTITY="Developer ID Application: …"
export NOTARY_PROFILE="AC_PASSWORD"
export SPARKLE_TOOLS=/path/to/Sparkle-extracted   # bin/sign_update
./Scripts/release.sh --sign --publish
```

## Code of conduct

Be kind. Assume good intent. No harassment.
