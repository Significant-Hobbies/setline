#!/bin/zsh
# Sign two iPhone simulators into the same iCloud account and check that a
# unique goal written on A arrives on B through CloudKit.
#
# Requires SETLINE_ICLOUD_APPLE_ID and SETLINE_ICLOUD_PASSWORD. Prompts with a
# local dialog if they are unset. Two-factor approval may still need a human.

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
# Same lock as ios/scripts/archive.sh. Xcode's last-used team can be Vault.
personal_team="8F7LXHTJZR"
development_team="${SETLINE_DEVELOPMENT_TEAM:-$personal_team}"
if [[ "$development_team" != "$personal_team" ]]; then
  print -u2 "Refusing to run: Setline is locked to personal team $personal_team."
  exit 3
fi
cd "$project_root"

A="${SETLINE_SIM_A:-6A01186A-2F27-4175-860E-E9F04DBE817F}"
B="${SETLINE_SIM_B:-BDE1151A-5755-4975-99DC-CB081A73AAC8}"
marker="sim-sync-$(date +%s)"
goal_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

prompt_secrets() {
  if [[ -n "${SETLINE_ICLOUD_APPLE_ID:-}" && -n "${SETLINE_ICLOUD_PASSWORD:-}" ]]; then
    return
  fi
  local id_answer
  id_answer="$(osascript -e 'Tell application "System Events" to display dialog "Apple ID to sign the Setline simulators into iCloud" default answer "sarthakagrawal927@gmail.com" with title "Setline simulator iCloud"' -e 'text returned of result' 2>/dev/null || true)"
  local pw_answer
  pw_answer="$(osascript -e 'Tell application "System Events" to display dialog "Password for that Apple ID (hidden)" default answer "" with hidden answer with title "Setline simulator iCloud"' -e 'text returned of result' 2>/dev/null || true)"
  if [[ -z "$id_answer" || -z "$pw_answer" ]]; then
    echo "Need SETLINE_ICLOUD_APPLE_ID and SETLINE_ICLOUD_PASSWORD (or complete the dialogs)." >&2
    exit 2
  fi
  export SETLINE_ICLOUD_APPLE_ID="$id_answer"
  export SETLINE_ICLOUD_PASSWORD="$pw_answer"
}

boot() {
  local udid="$1"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
}

sign_in() {
  local udid="$1"
  echo "Signing $udid into iCloud…"
  # Keep the password off the xcodebuild command line — it prints build settings.
  xcrun simctl spawn "$udid" /bin/sh -c 'printf "%s\n%s\n" "$1" "$2" > /tmp/setline-icloud-creds' x "$SETLINE_ICLOUD_APPLE_ID" "$SETLINE_ICLOUD_PASSWORD"
  (
    cd ios
    xcodegen generate >/dev/null
    xcodebuild test \
      -project Setline.xcodeproj \
      -scheme Setline \
      -destination "platform=iOS Simulator,id=$udid" \
      -only-testing:SetlineUITests/SimulatorICloudSignInTests/testSignIntoICloud \
      -derivedDataPath /tmp/setline-sim-icloud-derived \
      DEVELOPMENT_TEAM="$development_team"
  )
  xcrun simctl spawn "$udid" rm -f /tmp/setline-icloud-creds
}

install_app() {
  local udid="$1"
  local app="/tmp/setline-sim-icloud-derived/Build/Products/Debug-iphonesimulator/Setline.app"
  if [[ ! -d "$app" ]]; then
    (
      cd ios
      xcodegen generate >/dev/null
      xcodebuild build \
        -project Setline.xcodeproj \
        -scheme Setline \
        -destination "platform=iOS Simulator,id=$udid" \
        -derivedDataPath /tmp/setline-sim-icloud-derived \
        DEVELOPMENT_TEAM="$development_team"
    )
  fi
  xcrun simctl install "$udid" "$app"
}

app_support() {
  local udid="$1"
  local data
  data="$(xcrun simctl get_app_container "$udid" com.significanthobbies.setline data)"
  echo "$data/Library/Application Support/Setline"
}

seed_goal() {
  local udid="$1"
  local dir
  dir="$(app_support "$udid")"
  mkdir -p "$dir"
  cat > "$dir/setline-v1.json" <<JSON
{
  "schemaVersion": 2,
  "syncState": "deviceOnly",
  "templates": [],
  "programme": {
    "none": {}
  },
  "history": [],
  "goals": [
    {
      "id": "$goal_id",
      "exerciseName": "Simulator sync probe",
      "metric": "estimatedOneRepMax",
      "targetValue": 123.45,
      "createdAt": "2026-08-16T00:00:00Z",
      "note": "$marker"
    }
  ]
}
JSON
  echo "Seeded $marker on $udid"
}

launch_and_wait() {
  local udid="$1"
  xcrun simctl terminate "$udid" com.significanthobbies.setline 2>/dev/null || true
  xcrun simctl launch "$udid" com.significanthobbies.setline
  echo "Launched Setline on $udid; waiting for CloudKit…"
  sleep 25
}

document_has_marker() {
  local udid="$1"
  local file
  file="$(app_support "$udid")/setline-v1.json"
  [[ -f "$file" ]] && grep -q "$marker" "$file"
}

prompt_secrets
boot "$A"
boot "$B"
sign_in "$A"
sign_in "$B"
install_app "$A"
install_app "$B"
# B must start empty so the only way the marker arrives is iCloud.
xcrun simctl uninstall "$B" com.significanthobbies.setline 2>/dev/null || true
install_app "$B"
seed_goal "$A"
launch_and_wait "$A"
launch_and_wait "$B"

if document_has_marker "$B"; then
  echo "PASS: goal $goal_id ($marker) arrived on simulator B through iCloud."
  exit 0
fi

echo "FAIL: marker $marker did not appear on simulator B." >&2
echo "A document:" >&2
cat "$(app_support "$A")/setline-v1.json" >&2 || true
echo "B document:" >&2
cat "$(app_support "$B")/setline-v1.json" >&2 || true
xcrun simctl io "$A" screenshot /tmp/setline-sim-icloud/a-after.png || true
xcrun simctl io "$B" screenshot /tmp/setline-sim-icloud/b-after.png || true
exit 1
