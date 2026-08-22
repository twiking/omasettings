# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Power: what the battery is doing, and the profile the machine runs at. The
# profile is remembered per power source, the
# way omarchy-powerprofiles-set stores it: a laptop wants performance on the
# wall and power-saver on the train, and should not be asked twice a day.

POWERPROFILES_STATE="${OMARCHY_POWERPROFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME_DIR/.local/state}/omarchy/powerprofiles}"

power_battery_device() {
  upower -e 2>/dev/null | grep -m1 'BAT'
}

# upower's own report, reduced to the handful of facts worth showing.
power_battery_reading() {
  local device=$1
  [[ -n $device ]] || { echo '{}'; return; }

  upower -i "$device" 2>/dev/null | awk -F': +' '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    /state:/ { state = trim($2) }
    /percentage:/ { percentage = trim($2); sub(/%$/, "", percentage) }
    /time to empty:/ { remaining = trim($2) }
    /time to full:/ { untilFull = trim($2) }
    /^ +capacity:/ { health = trim($2); sub(/%$/, "", health) }
    /energy-rate:/ { rate = trim($2); sub(/ W$/, "", rate) }
    END {
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", state, percentage, remaining, untilFull, health, rate
    }
  ' | jq -R -s -c 'split("\n") | .[0] | split("\t")
    | { state: .[0],
        percentage: ((.[1] | tonumber?) // null),
        remaining: (if .[0] == "charging" then .[3] else .[2] end),
        health: ((.[4] | tonumber?) // null),
        watts: ((.[5] | tonumber?) // null) }'
}

power_state() {
  local device reading profiles current onbattery saved_ac saved_battery

  command -v powerprofilesctl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  device=$(power_battery_device)
  reading=$(power_battery_reading "$device")
  profiles=$(omarchy-powerprofiles-list 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))')
  current=$(powerprofilesctl get 2>/dev/null)
  onbattery=$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)
  saved_ac=$(cat "$POWERPROFILES_STATE/ac" 2>/dev/null)
  saved_battery=$(cat "$POWERPROFILES_STATE/battery" 2>/dev/null)

  # A machine with no battery still has power profiles worth setting; the
  # battery half of the page simply has nothing to say.
  jq -cn --argjson reading "${reading:-{\}}" \
    --argjson profiles "${profiles:-[]}" \
    --arg current "${current:-}" \
    --argjson onBattery "$([[ $onbattery == "b true" ]] && echo true || echo false)" \
    --arg savedAc "${saved_ac:-}" \
    --arg savedBattery "${saved_battery:-}" \
    --argjson hasBattery "$([[ -n $device ]] && echo true || echo false)" \
    '{ available: true,
       hasBattery: $hasBattery,
       onBattery: $onBattery,
       battery: $reading,
       profiles: $profiles,
       current: $current,
       # What is remembered for each source, falling back to what
       # omarchy-powerprofiles-set would itself choose.
       ac: (if $savedAc != "" then $savedAc
            elif ($profiles | index("performance")) then "performance"
            else "balanced" end),
       forBattery: (if $savedBattery != "" then $savedBattery else "balanced" end) }'
}

# The profile is not this window's alone: the bar's power plugin, the menu and
# powerprofilesctl itself all move it, and the battery drains regardless. Three
# things are worth waking for — the daemon's active profile, UPower's battery
# and AC readings, and the files omarchy-powerprofiles-set writes to remember a
# profile per power source — so all three feed one stream of state lines.
power_watch() {
  command -v powerprofilesctl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  mkdir -p "$POWERPROFILES_STATE" 2>/dev/null
  power_state

  local reader=$$
  {
    local pids=()
    # The monitors outlive nothing: when this subshell goes, so do they.
    trap 'kill "${pids[@]}" 2>/dev/null' EXIT

    gdbus monitor --system --dest net.hadess.PowerProfiles 2>/dev/null & pids+=($!)
    gdbus monitor --system --dest org.freedesktop.UPower 2>/dev/null & pids+=($!)
    inotifywait -q -m -e close_write,create,moved_to "$POWERPROFILES_STATE" 2>/dev/null & pids+=($!)

    # None of them notices the page closing, and a write to a gone reader is
    # only noticed at the next event — which may be hours away. Watch for the
    # reader instead, so the monitors never outlast the window.
    while kill -0 "$reader" 2>/dev/null; do sleep 2; done
  } | while read -r _; do
        # UPower is chatty and a profile change lands as several signals;
        # draining the burst keeps this to one state read per change.
        while read -r -t 0.2 _; do :; done
        power_state
      done
}

power_cmd() {
  local action=${1:-} source=${2:-} profile=${3:-}
  case $action in
    state) power_state ;;
    watch) power_watch ;;
    profile)
      [[ $source == ac || $source == battery ]] || die "expected ac or battery"
      [[ -n $profile ]] || die "no profile given"
      omarchy-powerprofiles-set "$source" "$profile" >/dev/null 2>&1 \
        || die "could not set the $source profile to $profile" ;;
    *) die "unknown battery action '$action'" ;;
  esac
}
