# BirdNET-Go iOS

Native SwiftUI companion app for [BirdNET-Go](https://github.com/tphakala/birdnet-go) stations. The app connects directly to a user-owned BirdNET-Go instance and gives iPhone/iPad users a pocket view of recent detections, live updates, species activity, media, and station status.

This project is intentionally a companion app, not a standalone classifier: BirdNET-Go remains the station-side analyzer and source of truth.

## Current Capabilities

- Connect to a BirdNET-Go station by URL and validate station configuration.
- Log in to protected stations, including password-only simple auth setups.
- Show recent detections and stream live detection events over SSE.
- Open detection detail with audio playback, spectrogram generation/display, species image attribution, weather, and time-of-day context.
- Browse detected species using station species data plus recent detection summaries.
- Cache recent detections/species for graceful offline fallback.
- Generate redacted diagnostics bundles from the Station tab.

## Tech Stack

- Swift, SwiftUI, Swift Concurrency, and `URLSession`.
- `AVPlayer` for station audio clips.
- UserDefaults-backed station/preferences storage, Keychain-backed credentials, and file-backed local cache.
- Xcode project with GitHub Actions CI and semantic-release-based GitHub releases.

## Development

Requirements:

- macOS with Xcode 26.1.1 or newer compatible tooling.
- iOS Simulator runtime compatible with the project deployment target.
- Node.js 22 for release tooling.

Build locally:

```sh
xcodebuild \
  -project BirdNETGo.xcodeproj \
  -scheme BirdNETGo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

For debug simulator launches, the app supports flags such as `-initialTab`, `-stationURL`, and `-debugDetectionID`. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the full contributor guide.

## Releases

Releases are managed by semantic-release through GitHub Actions. Conventional Commits determine release notes, tags, and published GitHub releases.

The checked-in app and package versions intentionally remain `0.0.0-development`; release workflows pass the semantic-release version to `xcodebuild` at build time and do not commit version bumps back to the repository.

## Roadmap

The long-term plan covers station administration, taxonomy browsing, analytics, notifications, widgets, App Intents, and other Apple platform integrations. Track current status in [docs/BIRDNET_GO_IOS_PROJECT_PLAN.md](docs/BIRDNET_GO_IOS_PROJECT_PLAN.md).