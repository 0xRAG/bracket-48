#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_ID="${1:-159CAA8C-E3C3-4AA8-ACF2-C497B28C0274}"
BUNDLE_ID="app.bracket48.Bracket48"
DERIVED_DATA="$ROOT_DIR/Build/ScreenshotDerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/WorldCupBracket.app"
OUTPUT_DIR="$ROOT_DIR/AppStore/Screenshots"

mkdir -p "$OUTPUT_DIR"

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

xcodebuild \
  -quiet \
  -project "$ROOT_DIR/WorldCupBracket.xcodeproj" \
  -scheme WorldCupBracket \
  -destination "id=$DEVICE_ID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

xcrun simctl install "$DEVICE_ID" "$APP_PATH"

capture() {
  local index="$1"
  local screen="$2"
  local name="$3"

  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -WCBUseScreenshotFixtures -WCBScreenshotScreen "$screen" >/dev/null
  sleep 2
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIR/$index-$name.png" >/dev/null
}

capture "01" "home" "home"
capture "02" "brackets" "brackets"
capture "03" "group-bracket" "group-bracket"
capture "04" "groups" "groups"
capture "05" "profile" "profile"

echo "Screenshots saved to $OUTPUT_DIR"
