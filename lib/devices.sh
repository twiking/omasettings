# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Per-device input settings — Hyprland's `hl.device` — for when one keyboard or
# one mouse should not follow the global input settings. A trackball that needs
# its own sensitivity, an external keyboard on a different layout.
#
# https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/

# What a device may override, by kind. These are the input options Hyprland
# accepts per device; the global ones live in hypr.sh.
device_schema() {
  local kind=$1
  case $kind in
    keyboard)
      cat <<'SCHEMA'
kb_layout	str
kb_variant	str
kb_options	str
repeat_rate	int
repeat_delay	int
numlock_by_default	bool
enabled	bool
SCHEMA
      ;;
    pointer)
      cat <<'SCHEMA'
sensitivity	float
accel_profile	str
natural_scroll	bool
left_handed	bool
scroll_factor	float
enabled	bool
SCHEMA
      ;;
    *) return 1 ;;
  esac
}

# Hyprland reports far more "keyboards" and "mice" than anyone has on their
# desk: power buttons, video buses and lid switches all arrive as input
# devices. A device with no real settings to give is only noise in a list.
devices_state() {
  local raw
  raw=$(hyprctl -j devices 2>/dev/null) || { echo '{}'; return; }

  jq -c --argjson store "$(read_store)" '
    def uninteresting:
      test("^(power-button|video-bus|sleep-button|lid-switch|hl-virtual.*|.*-wireless-radio-control|.*-consumer-control.*)$");

    { keyboards: [ .keyboards[]
        | select(.name | uninteresting | not)
        | { name: .name,
            kind: "keyboard",
            main: (.main == true),
            layout: (.active_keymap // ""),
            settings: (($store.devices // {})[.name] // {}) } ],
      pointers: [ .mice[]
        | select(.name | uninteresting | not)
        | { name: .name,
            kind: "pointer",
            # A touchpad is a pointer whose name says so, and it wants
            # different settings than a mouse does.
            touchpad: (.name | test("touchpad|synaptics|trackpad")),
            settings: (($store.devices // {})[.name] // {}) } ] }
  ' <<<"$raw"
}

# Rendered into the generated Lua next to everything else OmaSettings sets, and
# applied live through the same Lua parser.
device_set() {
  local name=$1 key=$2 raw=$3 kind=$4 type formatted

  [[ -n $name ]] || die "no device given"
  type=$(device_schema "$kind" | awk -F'\t' -v k="$key" '$1 == k { print $2 }')
  [[ -n $type ]] || die "a $kind cannot set '$key'"

  case $type in
    int) [[ $raw =~ ^-?[0-9]+$ ]] || die "'$raw' is not a whole number"; formatted=$raw ;;
    float) [[ $raw =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || die "'$raw' is not a number"; formatted=$raw ;;
    bool) [[ $raw == true || $raw == false ]] || die "'$raw' is not true or false"; formatted=$raw ;;
    *) formatted=$(jq -Rn --arg v "$raw" '$v') ;;
  esac

  # $formatted is already valid JSON for every type: a quoted string, or a
  # bare number or boolean.
  edit_store '.devices = ((.devices // {}) | .[$name] = (((.[$name] // {})) | .[$key] = $value))' \
    --arg name "$name" --arg key "$key" --argjson value "$formatted"

  hyprctl eval "hl.device({ name = $(jq -Rn --arg v "$name" '$v'), $key = $formatted })" >/dev/null 2>&1
}

device_clear() {
  local name=$1 key=$2
  [[ -n $name ]] || die "no device given"
  edit_store '.devices = ((.devices // {}) | .[$name] = ((.[$name] // {}) | del(.[$key])) | with_entries(select(.value != {})))' \
    --arg name "$name" --arg key "$key"
  # Hyprland has no way to unset one device option, so the config it was
  # written into is reloaded without it.
  hyprctl reload >/dev/null 2>&1
}

devices_cmd() {
  local action=${1:-} name=${2:-} key=${3:-} value=${4:-} kind=${5:-}
  case $action in
    state) devices_state ;;
    set)
      [[ -n $kind ]] || kind=pointer
      device_set "$name" "$key" "$value" "$kind" ;;
    clear) device_clear "$name" "$key" ;;
    *) die "unknown devices action '$action'" ;;
  esac
}
