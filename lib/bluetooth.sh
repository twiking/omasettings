# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Bluetooth, driven through Omarchy's own wrappers rather than bluetoothctl:
# powering an adapter means clearing an rfkill soft block (bluetoothctl alone
# forgets across reboots), and connecting a device means trusting it first.
# omarchy-bluetooth-power and omarchy-bluetooth-device already know that.

# `bluetoothctl devices [Paired|Connected]` prints "Device <mac> <name>".
bt_addresses() {
  timeout 5 bluetoothctl devices ${1:+"$1"} 2>/dev/null \
    | awk '$1 == "Device" { address = $2; $1 = ""; $2 = ""; sub(/^  /, ""); print address "\t" $0 }'
}

# Kind and battery come from a per-device lookup, which is only worth doing
# for devices you own: a scan can leave dozens of addresses behind, and none
# of them has either.
bt_details() {
  local address=$1
  timeout 5 bluetoothctl info "$address" 2>/dev/null | awk -F': ' '
    /^\tIcon:/ { icon = $2 }
    /Battery Percentage:/ { match($0, /\(([0-9]+)\)/, m); battery = m[1] }
    END { printf "%s\t%s\n", icon, battery }
  '
}

bluetooth_state() {
  local powered devices paired connected

  command -v bluetoothctl >/dev/null 2>&1 || { echo '{"available": false, "powered": false, "devices": []}'; return; }
  powered=$(omarchy-bluetooth-power is-on >/dev/null 2>&1 && echo true || echo false)

  # Three list calls rather than one info call per device: a scan can leave
  # dozens of addresses behind, and the flags are all that most rows need.
  devices=$(bt_addresses | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | { address: .[0], name: (.[1] // "") })')
  paired=$(bt_addresses Paired | cut -f1 | jq -R -s -c 'split("\n") | map(select(length > 0))')
  connected=$(bt_addresses Connected | cut -f1 | jq -R -s -c 'split("\n") | map(select(length > 0))')

  local enriched='[]' address icon battery
  while read -r address; do
    [[ -n $address ]] || continue
    IFS=$'\t' read -r icon battery < <(bt_details "$address")
    enriched=$(jq -c --arg address "$address" --arg icon "${icon:-}" --arg battery "${battery:-}" \
      '. + [{ address: $address, icon: $icon, battery: (($battery | tonumber?) // null) }]' <<<"$enriched")
  done < <(jq -r -s 'add | unique | .[]' <<<"${paired:-[]} ${connected:-[]}")

  jq -cn --argjson powered "$powered" \
    --argjson devices "${devices:-[]}" \
    --argjson paired "${paired:-[]}" \
    --argjson connected "${connected:-[]}" \
    --argjson enriched "${enriched:-[]}" \
    '($enriched | map({ key: .address, value: . }) | from_entries) as $extra
     | { available: true,
         powered: $powered,
         devices: ([$devices[] | . as $device
           | { address: $device.address,
               # An unnamed device shows its address; a name that is just the
               # address with dashes is the same non-answer, so it is dropped.
               name: (if $device.name == "" or ($device.name | gsub("-"; ":") | ascii_upcase) == ($device.address | ascii_upcase)
                      then "" else $device.name end),
               paired: (($paired | index($device.address)) != null),
               connected: (($connected | index($device.address)) != null),
               icon: (($extra[$device.address].icon) // ""),
               battery: (($extra[$device.address].battery) // null) }]
           # Connected first, then paired, then whatever the scan turned up,
           # each group alphabetical: the device you want is nearly always one
           # you already own.
           | sort_by([(if .connected then 0 elif .paired then 1 else 2 end), (.name | ascii_downcase)])) }'
}

bluetooth_cmd() {
  local action=${1:-} address=${2:-}
  command -v bluetoothctl >/dev/null 2>&1 || die "bluetoothctl is not available"

  case $action in
    state) bluetooth_state ;;
    power)
      case $address in
        on|off|toggle) omarchy-bluetooth-power "$address" >/dev/null 2>&1 || die "could not turn Bluetooth $address" ;;
        *) die "expected on, off or toggle" ;;
      esac ;;
    scan)
      # A scan has to run for a while to find anything; bluetoothctl's own
      # timeout ends it, and the state that follows includes what it found.
      timeout 20 bluetoothctl --timeout 12 scan on >/dev/null 2>&1 || true
      bluetooth_state ;;
    pair|connect|disconnect|forget)
      [[ $address =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || die "'$address' is not a device address"
      local output
      output=$(timeout 45 omarchy-bluetooth-device "$action" "$address" 2>&1) \
        || die "could not $action that device${output:+: $output}" ;;
    *) die "unknown bluetooth action '$action'" ;;
  esac
}
