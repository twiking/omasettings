# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------------ displays
#
# `hyprctl keyword monitor` does nothing on a Lua config: it answers "keyword
# can't work with non-legacy parsers. Use eval." on stderr while still exiting
# 0, so a resolution looked applied and never was. Everything here goes
# through `hyprctl eval 'hl.monitor({...})'`, which takes a partial table.
#
# A display is also the one setting on this page worth writing down: it is
# unplugged and plugged back in, and Hyprland matches its monitor rules again
# each time. So what is set here lands in the managed Lua like the rest, and a
# display that is not connected can be configured for the next time it is.

MONITOR_NAME_RE='^[A-Za-z][A-Za-z0-9]*(-[A-Za-z0-9]+)+$'

# What an earlier version of this page wrote down.
#
# It recorded a scale and the mode it read off the display, then applied both
# with `hyprctl keyword monitor` — which does nothing on a Lua config. So every
# entry it left is a setting that never took effect: this machine's store asked
# for scale 1.80 while both displays ran at 1.6.
#
# Now that these entries are rendered into the managed file, keeping them would
# apply years-old fiction to someone's screens on the next reload. They are
# dropped once instead, and the page starts from what the displays are actually
# doing.
monitor_migrate() {
  local store
  store=$(read_store)
  jq -e '(.monitorsSchema // 0) >= 2' <<<"$store" >/dev/null && return 0
  # On a .conf setup the keyword worked, so those entries are real settings and
  # not fiction — they are kept, and only the flag is written.
  [[ -f $HYPR_DIR/hyprland.lua ]] || {
    edit_store '.monitorsSchema = 2'
    return 0
  }
  edit_store '.monitors = {} | .monitorsSchema = 2
    | if .written then .written |= with_entries(select(.key | startswith("monitor:") | not)) else . end'
}

# What Hyprland reports, including the displays it knows about but has turned
# off. Modes arrive as "3840x2160@60.00Hz" and go back as "3840x2160@60.00",
# so the "Hz" comes off here rather than in the page.
#
# `mode` is the entry from that same list the display is running, not a string
# built from its width and height: the picker compares what it is set to
# against the options it offers, and 59.99700 matches none of them.
monitor_live() {
  capture hyprctl -j monitors all | jq -c '
    [ .[] | . as $m
      | ([$m.availableModes[]? | sub("Hz$"; "")]
         | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $modes
      | { name: $m.name,
          description: ($m.description // ""),
          disabled: ($m.disabled // false),
          scale: $m.scale,
          width: $m.width,
          height: $m.height,
          refreshRate: ($m.refreshRate | floor),
          transform: ($m.transform // 0),
          modes: $modes,
          mode: (($modes
                  | map(select(startswith("\($m.width)x\($m.height)@")))
                  | sort_by((split("@")[1] | tonumber) - $m.refreshRate | fabs)
                  | first)
                 // "\($m.width)x\($m.height)@\($m.refreshRate | floor)"),
          connected: true } ]' 2>/dev/null || echo '[]'
}

# Their own hl.monitor lines. Read, never written: a display already set up in
# monitors.lua would otherwise read as unconfigured here, and a resolution
# picked from this page would silently fight the line they wrote.
#
# One call per line is what Omarchy's own template writes, and all that is
# read: a table split over several lines is left to say nothing rather than be
# half understood. The global rule (`output = ""`) is not a display.
monitor_config_settings() {
  local file line name mode scale out='{}'
  while IFS= read -r line; do
    name=$(sed -nE 's/.*output *= *"([^"]+)".*/\1/p' <<<"$line")
    [[ -n $name ]] || continue
    mode=$(sed -nE 's/.*mode *= *"([^"]+)".*/\1/p' <<<"$line")
    scale=$(sed -nE 's/.*scale *= *([0-9]+(\.[0-9]+)?).*/\1/p' <<<"$line")
    out=$(jq -c --arg n "$name" --arg m "$mode" --arg s "$scale" \
      '.[$n] = ((.[$n] // {})
        | (if $m == "" then . else .mode = $m end)
        | (if $s == "" then . else .scale = ($s | tonumber) end))' <<<"$out")
  done < <(for file in "$HYPR_DIR"/*.lua; do
             [[ -f $file ]] || continue
             [[ $file == "$MANAGED_LUA" ]] && continue
             read_file "$file" | grep -E '^[^-]*hl\.monitor'
           done)
  printf '%s\n' "$out"
}

# Every display worth a group on the page: the ones plugged in, the ones this
# window has settings for, and the ones their own config names. A display you
# own is not always plugged in, so the ones that are not are listed too rather
# than losing their settings the moment they are unplugged.
monitor_state() {
  monitor_migrate
  jq -c -n \
    --argjson live "$(monitor_live)" \
    --argjson stored "$(jq -c '.monitors // {}' <<<"$(read_store)")" \
    --argjson configured "$(monitor_config_settings)" '
    def entry($name; $live):
      ($stored[$name] // {}) as $ours
      | ($configured[$name] // {}) as $theirs
      | { name: $name,
          connected: ($live != null),
          description: ($live.description // ""),
          disabled: ($live.disabled // false),
          modes: ($live.modes // []),
          width: $live.width,
          height: $live.height,
          refreshRate: $live.refreshRate,
          # What is in force: what was set here, else what their config gives
          # it, else what it is actually running.
          mode: ($ours.mode // $live.mode // $theirs.mode // "preferred"),
          scale: ($ours.scale // $live.scale // $theirs.scale // 1),
          settings: $ours,
          configured: $theirs };
    ($live | map(.name)) as $connected
    | ($connected + (($stored | keys) + ($configured | keys) | sort | unique)
       | reduce .[] as $n ([]; if index($n) then . else . + [$n] end)) as $names
    | [ $names[] as $n
        | entry($n; ($live | map(select(.name == $n)) | first)) ]'
}

# The Lua table a display's settings make, shared by the live apply and the
# generated file so the two can never say different things.
monitor_lua_table() {
  local name=$1 settings=$2
  jq -rn --arg n "$name" --argjson s "$settings" '
    "{ output = " + ($n | @json)
    + ([$s | to_entries[]
        | ", " + .key + " = "
          + (if (.value | type) == "string" then (.value | @json) else (.value | tostring) end)]
       | join(""))
    + " }"'
}

monitor_settings() {
  jq -c --arg n "$1" '(.monitors // {}) | .[$n] // {}' <<<"$(read_store)"
}

# A display that is not plugged in has nothing to apply to; the managed file
# already holds the rule, and Hyprland matches it again on the next connect.
monitor_apply_live() {
  local name=$1 settings
  settings=$(monitor_settings "$name")
  [[ $settings == "{}" ]] && return 0
  hyprctl eval "hl.monitor($(monitor_lua_table "$name" "$settings"))" >/dev/null 2>&1
}

# Hyprland takes a mode the display cannot do without complaining and quietly
# keeps something else, so the window would show a resolution the screen is
# not running. The list the display itself reports is the check.
monitor_mode_supported() {
  local name=$1 mode=$2
  [[ $mode == preferred ]] && return 0
  jq -e --arg n "$name" --arg m "$mode" '
    map(select(.name == $n)) | first
    | if . == null then true else (.modes | index($m) != null) end' \
    <<<"$(monitor_live)" >/dev/null
}

monitor_set() {
  local name=$1 field=$2 value=$3 json
  [[ -n $name ]] || die "no display given"
  monitor_migrate

  case $field in
    mode)
      [[ $value == preferred || $value =~ ^[0-9]+x[0-9]+@[0-9]+(\.[0-9]+)?$ ]] \
        || die "'$value' is not a resolution"
      monitor_mode_supported "$name" "$value" || die "$name cannot run $value"
      json=$(jq -Rn --arg v "$value" '$v') ;;
    scale)
      [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "'$value' is not a scale"
      json=$value ;;
    *) die "unknown display setting '$field'" ;;
  esac

  # A monitor rule is not merged with the ones before it: ours is more specific
  # than Omarchy's `output = ""` and loads last, so it replaces that rule whole.
  # Sending a mode on its own therefore took the scale with it — DP-2 dropped to
  # 1.0 the moment a resolution was picked. Whatever the user did not set is
  # filled in with what the display is doing now, so the rule says all of it.
  edit_store '.monitors = ((.monitors // {})
    | .[$n] = ($now + (.[$n] // {}) + { ($f): $v }))' \
    --arg n "$name" --arg f "$field" --argjson v "$json" \
    --argjson now "$(monitor_in_force "$name")"
  monitor_apply_live "$name"

  # Hyprland takes a scale it cannot do exactly, snaps to the nearest one that
  # gives whole pixels, and says so only in its own log. Recording what it
  # asked for would leave the page showing a number the screen is not using.
  local applied
  applied=$(monitor_value_now "$name" "$field")
  if [[ $field == scale && -n $applied && $applied != "$value" ]]; then
    edit_store '.monitors = ((.monitors // {}) | .[$n] = (.[$n] + { scale: $s }))' \
      --arg n "$name" --argjson s "$applied"
  fi
}

# What a display is running, in the shape a rule takes. No position: Omarchy's
# own rule places every display with `position = "auto"`, so leaving it out is
# what keeps the arrangement it already had.
monitor_in_force() {
  jq -c --arg n "$1" '
    map(select(.name == $n)) | first
    | if . == null then {} else { mode: .mode, scale: .scale } end' <<<"$(monitor_live)"
}

# Putting one back writes the value the display had and then drops the rule:
# a monitor rule is an override like a Hyprland key, and one left behind saying
# what the display already does would go on overriding a mode their config —
# or the display's own EDID — changes later.
monitor_unset() {
  local name=$1 field=$2 now
  # What is left has to be a whole rule, and in one write: Hyprland reloads a
  # config file the moment it changes, so a partial rule on disk is applied
  # before anything can fill it back in — which put the display at scale 1.0
  # between the two writes. So the value in force is read first, and the field
  # the user is dropping is replaced by it rather than deleted.
  now=$(monitor_in_force "$name")
  edit_store '.monitors = ((.monitors // {})
    | .[$n] = ($now + ((.[$n] // {}) | del(.[$f])))
    | with_entries(select(.value != {})))' \
    --arg n "$name" --arg f "$field" --argjson now "$now"
  monitor_apply_live "$name"
}

# Configuring a display before it is plugged in: the name is all that is
# needed, and the settings written against it are what makes it remembered.
monitor_remember() {
  local name=$1
  monitor_migrate
  [[ $name =~ $MONITOR_NAME_RE ]] || die "'$name' is not a display name, like DP-2 or HDMI-A-1"
  edit_store '.monitors = ((.monitors // {}) | (if has($n) then . else .[$n] = {} end))' \
    --arg n "$name"
}

# Handing a display back: our rule goes, and the reload is what makes their
# config — or the display's own preferred mode — take effect again.
monitor_forget() {
  local name=$1
  [[ -n $name ]] || die "no display given"
  edit_store '.monitors = ((.monitors // {}) | del(.[$n]))
    | if .written then .written |= with_entries(select(.key | startswith("monitor:" + $n + ":") | not)) else . end' \
    --arg n "$name"
  hyprctl reload >/dev/null 2>&1 || true
}

# What a display is set to now, for the change marks and the way back. A
# display that is not connected can only answer from what we wrote down.
monitor_value_now() {
  local name=$1 field=$2
  jq -r --arg n "$name" --arg f "$field" '
    map(select(.name == $n)) | first | if . == null then empty else .[$f] | tostring end' \
    <<<"$(monitor_live)"
}
