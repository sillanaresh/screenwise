#!/bin/bash
# App Store screenshots on the 6.9 inch iPhone (1320 x 2868). Needs a Debug simulator build,
# because it opens screens with the debug launch arguments. Run: make screenshots
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${SIM:-iPhone 17 Pro Max}"
OUT="${OUT:-design/app-store}"
APP=".build/DerivedData/Build/Products/Debug-iphonesimulator/Screenwise.app"
FILM="${FILM:-tmdb-1170608}"        # Dune: Part Three
SCREEN="${SCREEN:-allu-s1-dolby}"   # Allu Cinemas Dolby Cinema
WAIT="${WAIT:-9}"

ID=$(xcrun simctl list devices available | grep -m1 -F "    $SIM (" | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')
xcrun simctl boot "$ID" 2>/dev/null || true
xcrun simctl bootstatus "$ID" >/dev/null
xcrun simctl ui "$ID" appearance light
xcrun simctl status_bar "$ID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$ID" "$APP"
mkdir -p "$OUT"

shot() {
  local name="$1"; shift
  xcrun simctl terminate "$ID" app.screenwise.ios 2>/dev/null || true
  xcrun simctl launch "$ID" app.screenwise.ios "$@" >/dev/null
  sleep "$WAIT"
  xcrun simctl io "$ID" screenshot --type=jpeg "$OUT/$name.jpg" >/dev/null 2>&1
  echo "wrote $OUT/$name.jpg"
}

# Open the app once so it downloads the latest data, then take the shots.
shot 00-warmup
rm -f "$OUT/00-warmup.jpg"
shot 01-home
shot 02-movie -openURL "screenwise://film/$FILM" -debugScrollY 620
shot 03-theatre -openURL "screenwise://film/$FILM/screen/$SCREEN"
shot 04-seat -openURL "screenwise://film/$FILM/screen/$SCREEN" -debugStageMode seat
shot 05-explainer -openURL "screenwise://debug/explain/dolbyCinema"

xcrun simctl status_bar "$ID" clear
