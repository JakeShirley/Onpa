#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/src/Onpa.xcodeproj}"
SCHEME="${SCHEME:-Onpa}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
IOS_VERSION="${IOS_VERSION:-26.1}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/docs/screenshots}"
MOCK_HOST="${MOCK_HOST:-127.0.0.1}"
MOCK_PORT="${MOCK_PORT:-18081}"
MOCK_URL="http://$MOCK_HOST:$MOCK_PORT"
BUNDLE_ID="${BUNDLE_ID:-org.odinseye.onpa}"
SCREENSHOT_DELAY="${SCREENSHOT_DELAY:-3.0}"
SKIP_BUILD="${SKIP_BUILD:-0}"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/Onpa.app"
SERVER_LOG="$ROOT_DIR/build/mock-birdnet-go-server.log"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi

  if [[ -n "${DEVICE_UDID:-}" ]]; then
    xcrun simctl status_bar "$DEVICE_UDID" clear >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

resolve_device() {
  DEVICE_NAME="$DEVICE_NAME" IOS_VERSION="$IOS_VERSION" node -e '
const fs = require("node:fs");
const name = process.env.DEVICE_NAME;
const version = process.env.IOS_VERSION || "";
const devices = JSON.parse(fs.readFileSync(0, "utf8")).devices;

for (const [runtime, candidates] of Object.entries(devices)) {
  const runtimeMatches = !version || runtime.endsWith("iOS-" + version.replaceAll(".", "-"));
  if (!runtimeMatches) continue;
  const device = candidates.find((candidate) => candidate.isAvailable && candidate.name === name);
  if (device) {
    console.log(device.udid);
    process.exit(0);
  }
}

console.error(`No available simulator named ${JSON.stringify(name)} for iOS ${version || "any version"}.`);
process.exit(1);
'
}

wait_for_mock_server() {
  for _ in {1..40}; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "Mock BirdNET-Go server exited before it became ready." >&2
      if [[ -f "$SERVER_LOG" ]]; then
        cat "$SERVER_LOG" >&2
      fi
      return 1
    fi

    if curl -fsS --max-time 2 "$MOCK_URL/api/v2/ping" >/dev/null 2>&1; then
      return 0
    fi
    node -e 'setTimeout(() => {}, 250)'
  done

  echo "Mock BirdNET-Go server did not become ready at $MOCK_URL" >&2
  if [[ -f "$SERVER_LOG" ]]; then
    cat "$SERVER_LOG" >&2
  fi
  return 1
}

pause_for_render() {
  SCREENSHOT_DELAY="$SCREENSHOT_DELAY" node -e 'setTimeout(() => {}, Number(process.env.SCREENSHOT_DELAY) * 1000)'
}

capture_tab() {
  local tab="$1"
  local filename="$2"
  local output_path="$SCREENSHOT_DIR/$filename"

  echo "Capturing $tab -> $output_path"
  xcrun simctl launch --terminate-running-process "$DEVICE_UDID" "$BUNDLE_ID" --args -initialTab "$tab" -stationURL "$MOCK_URL" >/dev/null
  pause_for_render
  xcrun simctl io "$DEVICE_UDID" screenshot "$output_path" >/dev/null
}

mkdir -p "$ROOT_DIR/build" "$SCREENSHOT_DIR"

echo "Starting mock BirdNET-Go station at $MOCK_URL"
node "$ROOT_DIR/scripts/mock_birdnet_go_server.js" --host "$MOCK_HOST" --port "$MOCK_PORT" >"$SERVER_LOG" 2>&1 &
SERVER_PID="$!"
wait_for_mock_server

echo "Resolving simulator: $DEVICE_NAME iOS $IOS_VERSION"
DEVICE_UDID="$(xcrun simctl list devices available -j | resolve_device)"
xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b >/dev/null
xcrun simctl status_bar "$DEVICE_UDID" override --time 9:41 --dataNetwork wifi --wifiBars 3 --batteryState charged --batteryLevel 100 >/dev/null

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "Building $SCHEME for $DEVICE_NAME"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$IOS_VERSION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

echo "Installing $APP_PATH"
xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

capture_tab dashboard dashboard.png
capture_tab feed feed.png
capture_tab species species.png
capture_tab station station.png

echo "Screenshots written to $SCREENSHOT_DIR"