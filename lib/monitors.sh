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
#
# ------------------------------------------------------ which display is which
#
# A connector is not an identity. DP-2 is whichever screen is in that socket:
# the work monitor at the desk and the one at home are both DP-2, and settings
# written against the connector followed the cable rather than the screen — a
# 4K desktop panel handed the laptop dock's scale the moment it was plugged in.
#
# So a display is keyed by what it says about itself. Hyprland matches monitor
# rules on `desc:<description>` as well as on connector name, which is what the
# hand-written `monitor = desc:Dell Inc. DELL U2724D 1A2B3C4, ...` lines in a
# .conf setup have always used. A key here is therefore:
#
#   desc:Dell Inc. DELL U2724D 1A2B3C4   — a display with an EDID description
#   DP-2                                  — the fallback, for a display that
#                                           reports no description at all
#
# The key is what the store is keyed by, what `output` says in the managed Lua,
# and what a setting key (`monitor:<key>:scale`) names. The connector name is
# kept alongside it for the page to show, and for the one place that still has
# to speak connectors: see monitor_lua_scale.
MONITOR_NAME_RE='^[A-Za-z][A-Za-z0-9]*(-[A-Za-z0-9]+)+$'

# A description goes into Lua as a quoted string and into a setting key that is
# split on colons, so the two characters that would break either are refused
# rather than escaped.
MONITOR_DESC_RE='^[^"\\]+$'

MONITOR_SCHEMA=3

# What an earlier version of this page wrote down.
#
# Schema 2: it recorded a scale and the mode it read off the display, then
# applied both with `hyprctl keyword monitor` — which does nothing on a Lua
# config. So every entry it left is a setting that never took effect: this
# machine's store asked for scale 1.80 while both displays ran at 1.6. Now that
# these entries are rendered into the managed file, keeping them would apply
# years-old fiction to someone's screens on the next reload. They are dropped
# once instead, and the page starts from what the displays are actually doing.
#
# Schema 3: entries were keyed by connector name. Those are re-keyed to the
# description of whatever is in that connector now — the best guess there is,
# and the same one the user was making when they set it.
monitor_migrate() {
  local schema
  schema=$(jq -r '(.monitorsSchema // 0)' <<<"$(read_store)")
  [[ $schema =~ ^[0-9]+$ ]] || schema=0
  ((schema >= MONITOR_SCHEMA)) && return 0

  # On a .conf setup the keyword worked, so those entries are real settings and
  # not fiction — they are kept, and only the flag is written.
  if ((schema < 2)) && [[ -f $HYPR_DIR/hyprland.lua ]]; then
    edit_store '.monitors = {}
      | if .written then .written |= with_entries(select(.key | startswith("monitor:") | not)) else . end'
  fi

  ((schema < 3)) && monitor_rekey_to_description

  edit_store '.monitorsSchema = $v' --argjson v "$MONITOR_SCHEMA"
}

# Connector name → description key, for everything already written down. Only
# the displays plugged in right now can be re-keyed: nothing else says what was
# ever in that socket. An entry for a display that is not here keeps its
# connector key and goes on working as one.
monitor_rekey_to_description() {
  local map
  map=$(jq -c '
    map(select(.key != .name)) | map({ (.name): .key }) | add // {}' <<<"$(monitor_live)")
  [[ -z $map || $map == "{}" ]] && return 0

  edit_store '
    def rekey($k): $map[$k] // $k;
    .monitors = ((.monitors // {}) | with_entries(.key |= rekey(.)))
    | if .written then
        .written |= with_entries(
          if (.key | startswith("monitor:")) then
            ((.key | ltrimstr("monitor:")) | split(":")) as $parts
            | if ($parts | length) >= 2
              then .key = "monitor:" + rekey($parts[:-1] | join(":")) + ":" + $parts[-1]
              else .key = "monitor:" + rekey($parts | join(":"))
              end
          else . end)
      else . end' --argjson map "$map"
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
      | ($m.description // "") as $desc
      | { name: $m.name,
          key: (if $desc == "" then $m.name else "desc:" + $desc end),
          description: $desc,
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

# The live display a key names, or `null`. A key matches its own display, and a
# connector name still matches the display in that socket, so a setting written
# before this file knew about descriptions goes on finding its screen.
#
# `desc:` is a prefix match, the way Hyprland matches it: a hand-written
# `desc:Dell Inc. DELL U2724D` names the display whose full description
# carries a serial the user did not type.
#
# $2 is the live list when the caller already has it — one page load asks about
# every display, and `hyprctl monitors all` is not free.
monitor_find() {
  local key=$1 live=${2:-}
  [[ -n $live ]] || live=$(monitor_live)
  jq -c --arg n "$key" '
    def matches($e):
      $e.key == $n
      or $e.name == $n
      or (($n | startswith("desc:")) and $e.description != ""
          and ($e.description | startswith($n[5:])));
    (map(select(matches(.))) | first) // null' <<<"$live"
}

# The key this window should file a display under, given whatever it was handed:
# a connector name, a partial description, or a key already. A display that is
# not connected cannot be resolved, so what was typed stands as the key.
monitor_key() {
  local found
  found=$(monitor_find "$1" "${2:-}")
  [[ $found == null ]] && { printf '%s\n' "$1"; return 0; }
  jq -r '.key' <<<"$found"
}

# The connector a key is plugged into, or nothing. Only for talking to things
# that deal in connectors — Hyprland itself takes the key.
monitor_output_name() {
  local found
  found=$(monitor_find "$1" "${2:-}")
  [[ $found == null ]] && return 0
  jq -r '.name' <<<"$found"
}

# Their own hl.monitor lines. Read, never written: a display already set up in
# monitors.lua would otherwise read as unconfigured here, and a resolution
# picked from this page would silently fight the line they wrote.
#
# One call per line is what Omarchy's own template writes, and all that is
# read: a table split over several lines is left to say nothing rather than be
# half understood. The global rule (`output = ""`) is not a display.
#
# Their output string is put through monitor_key, so a rule they wrote against
# DP-2 and one this window wrote against the description of the screen in DP-2
# are recognised as being about the same display.
monitor_config_settings() {
  local file line name mode scale live out='{}'
  live=$(monitor_live)
  while IFS= read -r line; do
    name=$(sed -nE 's/.*output *= *"([^"]+)".*/\1/p' <<<"$line")
    [[ -n $name ]] || continue
    name=$(monitor_key "$name" "$live")
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
#
# `name` is the key — it is what a setting key is built from, so the page keeps
# calling it the display's name. `label` is what to put on the group, since
# "desc:Dell Inc. DELL U2724D 1A2B3C4" is an identity and not a title.
monitor_state() {
  monitor_migrate
  jq -c -n \
    --argjson live "$(monitor_live)" \
    --argjson stored "$(jq -c '.monitors // {}' <<<"$(read_store)")" \
    --argjson configured "$(monitor_config_settings)" '
    def entry($name; $live):
      ($stored[$name] // {}) as $ours
      | ($configured[$name] // {}) as $theirs
      | ($live.description // (if ($name | startswith("desc:")) then $name[5:] else "" end)) as $desc
      | { name: $name,
          output: ($live.name // ""),
          description: $desc,
          # The description alone: the connector has a row of its own, and a
          # description out of Hyprland is long enough without it. No
          # apostrophe in this comment: the whole filter is one shell string.
          label: (if $desc != "" then $desc
                  elif $live != null then $live.name
                  else $name end),
          connected: ($live != null),
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
    ($live | map(.key)) as $connected
    | ($connected + (($stored | keys) + ($configured | keys) | sort | unique)
       | reduce .[] as $n ([]; if index($n) then . else . + [$n] end)) as $names
    | [ $names[] as $n
        | entry($n; ($live | map(select(.key == $n)) | first)) ]'
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
  local name=$1 mode=$2 found
  [[ $mode == preferred ]] && return 0
  found=$(monitor_find "$name")
  [[ $found == null ]] && return 0
  jq -e --arg m "$mode" '.modes | index($m) != null' <<<"$found" >/dev/null
}

monitor_set() {
  local name=$1 field=$2 value=$3 json
  [[ -n $name ]] || die "no display given"
  monitor_migrate
  # Whatever the caller named the display, the store speaks keys: a rule filed
  # under DP-2 would be handed to the next screen in that socket.
  name=$(monitor_key "$name")

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

  [[ $field == scale ]] && monitor_is_internal "$name" \
    && monitor_lua_scale "$name" "$(monitor_settings "$name" | jq -r '.scale')"
  return 0
}

# What a display is running, in the shape a rule takes. No position: Omarchy's
# own rule places every display with `position = "auto"`, so leaving it out is
# what keeps the arrangement it already had.
monitor_in_force() {
  local found
  found=$(monitor_find "$1")
  [[ $found == null ]] && { echo '{}'; return 0; }
  jq -c '{ mode: .mode, scale: .scale }' <<<"$found"
}

# Putting one back writes the value the display had and then drops the rule:
# a monitor rule is an override like a Hyprland key, and one left behind saying
# what the display already does would go on overriding a mode their config —
# or the display's own EDID — changes later.
monitor_unset() {
  local name=$1 field=$2 now
  name=$(monitor_key "$name")
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
  [[ $field == scale ]] && monitor_is_internal "$name" && monitor_lua_scale "$name" --
  return 0
}

# ------------------------------------------------- the laptop panel is theirs
#
# Omarchy watches the internal panel and puts its scale back. While a laptop is
# docked, `omarchy-hyprland-monitor-clamshell` runs every couple of seconds,
# reads the scale out of ~/.config/hypr/monitors.lua, and re-applies it if the
# panel is running anything else — so a scale set from here survived about a
# second. It won every time, and no error said so.
#
# The way to set the internal panel's scale is therefore to make that file say
# it too: the rule for the panel, in the file Omarchy reads, edited in place the
# way every other hand-written config here is. Then the watcher enforces the
# number this page chose instead of fighting it.
#
# Only the scale, and only the internal panel: an external display is nobody
# else's business, and stays in the managed file alone.
#
# This is also the one place that has to write a connector name rather than a
# description key. The watcher looks the panel's rule up by the output name
# `omarchy-hyprland-monitor-laptop` prints, so a `desc:` rule in that file is a
# rule it cannot see — it would read no scale, fall back, and fight us again.
monitor_internal() {
  command -v omarchy-hyprland-monitor-laptop >/dev/null 2>&1 || return 0
  omarchy-hyprland-monitor-laptop 2>/dev/null
}

monitor_is_internal() {
  local internal output
  internal=$(monitor_internal)
  [[ -n $internal ]] || return 1
  output=$(monitor_output_name "$1")
  # A key that resolves to nothing may still be the panel's own connector,
  # written down before it knew about descriptions.
  [[ -z $output ]] && output=$1
  [[ $output == "$internal" ]]
}

MONITOR_LUA_MARKER="-- omasettings"

# `--` removes what this window added; a number writes it. A rule the user wrote
# themselves only ever has its scale replaced — the rest of their line, comment
# included, is copied through.
#
# Every line this adds carries the marker, the comments as well as the rule, so
# removing it takes the whole block rather than leaving three lines of
# explanation for a rule that is no longer there.
monitor_lua_scale() {
  local name=$1 value=$2 file="$HYPR_DIR/monitors.lua" previous next
  [[ -f $file ]] || return 0

  # The watcher reads this file by connector name, so that is what goes in it —
  # see the block above. A key that names no connected display cannot be
  # written here at all.
  local output
  output=$(monitor_output_name "$name")
  [[ -n $output ]] || output=$name
  [[ $output =~ $MONITOR_NAME_RE ]] || return 0
  name=$output

  previous=$(read_file "$file")
  # The pattern is built here rather than inside awk: a quoted output name in
  # an awk string literal inside a shell single-quoted program is three levels
  # of quoting, and it collapsed silently — every rule read as no rule.
  local pattern="output[ \t]*=[ \t]*\"$name\""
  next=$(awk -v value="$value" -v name="$name" -v marker="$MONITOR_LUA_MARKER" -v pattern="$pattern" '
    function flush() {
      for (i = 1; i <= held; i++) print holding[i]
      held = 0
    }
    # Lines this window wrote are held back until it is clear whether the rule
    # they explain is staying.
    index($0, marker ":") == 1 { holding[++held] = $0; next }
    /^[ \t]*--/ { flush(); print; next }
    $0 ~ /hl\.monitor/ && $0 ~ pattern {
      if (value == "--") {
        # Ours goes, comments and all; theirs stays, since the scale in it is
        # the one this reset has just written back.
        if (index($0, marker)) { held = 0; next }
        flush()
        print
        found = 1
        next
      }
      flush()
      if ($0 ~ /scale[ \t]*=/) sub(/scale[ \t]*=[ \t]*[^,;} \t]+/, "scale = " value)
      else sub(/\}[ \t]*\)/, ", scale = " value " })")
      print
      found = 1
      next
    }
    { flush(); print }
    END {
      flush()
      if (!found && value != "--") {
        print marker ": the internal panel'"'"'s scale is kept here as well, because"
        print marker ": omarchy-hyprland-monitor-clamshell reads this file and puts"
        print marker ": the panel back to it every couple of seconds while docked."
        printf "hl.monitor({ output = \"%s\", mode = \"preferred\", position = \"auto\", scale = %s })  %s\n", name, value, marker
      }
    }' <<<"$previous")

  [[ -n $next ]] || return 0
  [[ $next == "$previous" ]] && return 0

  backup_once "$file" || return 1
  write_file "$file" <<<"$next" || return 1

  # Their config, so the edit is checked in their terms and put back if it
  # broke: an unparseable monitors.lua is a session that does not come up.
  if ! luac -p "$file" >/dev/null 2>&1; then
    write_file "$file" <<<"$previous"
    die "the edit to monitors.lua would not compile; nothing was changed"
  fi
}

# Configuring a display before it is plugged in. What identifies it is the
# question: a connector name is what you can read off the back of the machine,
# but it is also the one thing that will not still mean this screen once
# something else is in that socket. So a description is taken as well, and
# preferred — `Dell Inc. DELL U2724D 1A2B3C4`, as `hyprctl monitors all`
# prints it, or as much of the front of it as is unique.
#
# A connector name that is plugged in right now resolves to that display's
# description; one that is not stands as its own key, since nothing here can
# say what will be in it.
monitor_remember() {
  local given=$1 name
  monitor_migrate
  [[ -n $given ]] || die "no display given"

  if [[ $given =~ $MONITOR_NAME_RE ]]; then
    name=$(monitor_key "$given")
  else
    local desc=${given#desc:}
    [[ $desc =~ $MONITOR_DESC_RE ]] \
      || die "'$given' is not a display name, like DP-2, or a model, like DELL U2724D"
    name=$(monitor_key "desc:$desc")
  fi

  edit_store '.monitors = ((.monitors // {}) | (if has($n) then . else .[$n] = {} end))' \
    --arg n "$name"
}

# Handing a display back: our rule goes, and the reload is what makes their
# config — or the display's own preferred mode — take effect again.
monitor_forget() {
  local name=$1
  [[ -n $name ]] || die "no display given"
  # Only a key that is actually in the store is resolved: forgetting must be
  # able to reach an entry whose display is long gone.
  jq -e --arg n "$name" '(.monitors // {}) | has($n)' <<<"$(read_store)" >/dev/null \
    || name=$(monitor_key "$name")
  edit_store '.monitors = ((.monitors // {}) | del(.[$n]))
    | if .written then .written |= with_entries(select(.key | startswith("monitor:" + $n + ":") | not)) else . end' \
    --arg n "$name"
  monitor_is_internal "$name" && monitor_lua_scale "$name" --
  hyprctl reload >/dev/null 2>&1 || true
}

# What a display is set to now, for the change marks and the way back. A
# display that is not connected can only answer from what we wrote down.
monitor_value_now() {
  local name=$1 field=$2 found
  found=$(monitor_find "$name")
  [[ $found == null ]] && return 0
  jq -r --arg f "$field" 'if has($f) then .[$f] | tostring else empty end' <<<"$found"
}
