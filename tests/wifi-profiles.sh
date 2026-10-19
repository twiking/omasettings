#!/bin/bash
# Regression for wifi_profiles, wifi_saved, and wifi_profile_uuids:
# unescape colons in SSIDs and match numbered duplicate profiles ("<SSID> 1").
# Run from any directory: bash tests/wifi-profiles.sh
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/lib/wifi.sh"

# Ensure fallback path is exercised regardless of host environment.
HOME_DIR="/nonexistent"
PATH="/usr/bin:/bin"

capture() {
  [[ $1 == nmcli && $2 == -t && $3 == -f && $4 == UUID,NAME,TYPE ]] || return 1
  cat <<'OUTPUT'
11111111-1111-1111-1111-111111111111:Wired connection 1:802-3-ethernet
22222222-2222-2222-2222-222222222222:Home_WiFi:802-11-wireless
33333333-3333-3333-3333-333333333333:Home_WiFi 1:802-11-wireless
44444444-4444-4444-4444-444444444444:Cafe\:5GHz:802-11-wireless
55555555-5555-5555-5555-555555555555:Office 2:802-11-wireless
OUTPUT
}

expected_saved=$'Home_WiFi\nHome_WiFi 1\nCafe:5GHz\nOffice 2\nOffice'
actual_saved=$(wifi_saved)
if [[ $actual_saved != "$expected_saved" ]]; then
  printf 'FAIL: wifi_saved emitted wrong list:\n%s\n' "$actual_saved" >&2
  exit 1
fi

expected_uuids=$'22222222-2222-2222-2222-222222222222\n33333333-3333-3333-3333-333333333333'
actual_uuids=$(wifi_profile_uuids "Home_WiFi")
if [[ $actual_uuids != "$expected_uuids" ]]; then
  printf 'FAIL: wifi_profile_uuids Home_WiFi emitted wrong UUIDs:\n%s\n' "$actual_uuids" >&2
  exit 1
fi

colon_uuid=$(wifi_profile_uuids "Cafe:5GHz")
if [[ $colon_uuid != "44444444-4444-4444-4444-444444444444" ]]; then
  printf 'FAIL: wifi_profile_uuids failed to match SSID with colon:\n%s\n' "$colon_uuid" >&2
  exit 1
fi

echo 'PASS: wifi_saved and wifi_profile_uuids unescape colons and match duplicate wireless profiles'

