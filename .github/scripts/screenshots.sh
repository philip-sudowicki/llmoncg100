#!/bin/bash
# Captures screenshots of each screen in the simulator using the app's demo launch arguments.
set -uo pipefail
udid="$1"
app="$2"
out="$3"
bundle="app.lowtide.Lowtide"
mkdir -p "$out"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" "$app"
xcrun simctl privacy "$udid" grant location "$bundle" || true
xcrun simctl location "$udid" set 51.5074,-0.1278 || true
xcrun simctl status_bar "$udid" override --time "14:10" || true

shoot() {
  local name="$1" screen="$2" appearance="${3:-light}" size="${4:-large}" time="${5:-14:10}"
  xcrun simctl ui "$udid" appearance "$appearance" || true
  xcrun simctl ui "$udid" content_size "$size" || true
  xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
  xcrun simctl launch "$udid" "$bundle" -LowtideDemoTime "$time" -LowtideDemoScreen "$screen"
  sleep 10
  xcrun simctl io "$udid" screenshot "$out/$name.png"
}

shoot 01-onboarding onboarding
shoot 02-map map
shoot 03-place place:marlow-street-library
shoot 04-checkin checkin:marlow-street-library
shoot 05-lowwater lowwater
shoot 06-cards cards
shoot 07-profile profile
shoot 08-map-dark map dark
shoot 09-place-dark place:marlow-street-library dark
shoot 10-lowwater-dark lowwater dark
shoot 11-map-ax map light accessibility-extra-large
shoot 12-place-ax place:marlow-street-library light accessibility-extra-large
shoot 13-place-closed place:harbour-tea-room light large 20:00
shoot 14-map-evening map light large 20:00
shoot 15-route route:larkspur-gardens
xcrun simctl ui "$udid" content_size large || true
xcrun simctl ui "$udid" appearance light || true
