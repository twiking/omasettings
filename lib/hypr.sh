# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------- Hyprland plumbing

# Every Hyprland setting the window can touch: our key, the Hyprland keyword,
# and the value type used to read it back out of `hyprctl getoption`.
hypr_keyword() {
  case $1 in
    gaps-in) echo "general:gaps_in css" ;;
    gaps-out) echo "general:gaps_out css" ;;
    border-size) echo "general:border_size int" ;;
    rounding) echo "decoration:rounding int" ;;
    active-opacity) echo "decoration:active_opacity float" ;;
    inactive-opacity) echo "decoration:inactive_opacity float" ;;
    dim-inactive) echo "decoration:dim_inactive bool" ;;
    dim-strength) echo "decoration:dim_strength float" ;;
    blur) echo "decoration:blur:enabled bool" ;;
    blur-size) echo "decoration:blur:size int" ;;
    blur-passes) echo "decoration:blur:passes int" ;;
    animations) echo "animations:enabled bool" ;;
    animations-wraparound) echo "animations:workspace_wraparound bool" ;;

    # Gaps and borders beyond the two everyone changes.
    float-gaps) echo "general:float_gaps css" ;;
    gaps-workspaces) echo "general:gaps_workspaces int" ;;
    border-part-of-window) echo "decoration:border_part_of_window bool" ;;
    snap) echo "general:snap:enabled bool" ;;
    snap-window-gap) echo "general:snap:window_gap int" ;;
    snap-monitor-gap) echo "general:snap:monitor_gap int" ;;

    # The tiling engine, and the knobs that belong to whichever one is on.
    layout) echo "general:layout str" ;;
    dwindle-preserve-split) echo "dwindle:preserve_split bool" ;;
    dwindle-smart-split) echo "dwindle:smart_split bool" ;;
    dwindle-force-split) echo "dwindle:force_split int" ;;
    dwindle-split-width-multiplier) echo "dwindle:split_width_multiplier float" ;;
    dwindle-default-split-ratio) echo "dwindle:default_split_ratio float" ;;
    master-mfact) echo "master:mfact float" ;;
    master-orientation) echo "master:orientation str" ;;
    master-new-status) echo "master:new_status str" ;;
    scrolling-column-width) echo "scrolling:column_width float" ;;
    scrolling-fullscreen-on-one-column) echo "scrolling:fullscreen_on_one_column bool" ;;

    rounding-power) echo "decoration:rounding_power float" ;;
    fullscreen-opacity) echo "decoration:fullscreen_opacity float" ;;
    dim-around) echo "decoration:dim_around float" ;;
    dim-modal) echo "decoration:dim_modal bool" ;;
    dim-special) echo "decoration:dim_special float" ;;

    blur-noise) echo "decoration:blur:noise float" ;;
    blur-contrast) echo "decoration:blur:contrast float" ;;
    blur-brightness) echo "decoration:blur:brightness float" ;;
    blur-vibrancy) echo "decoration:blur:vibrancy float" ;;
    blur-vibrancy-darkness) echo "decoration:blur:vibrancy_darkness float" ;;
    blur-xray) echo "decoration:blur:xray bool" ;;
    blur-special) echo "decoration:blur:special bool" ;;
    blur-popups) echo "decoration:blur:popups bool" ;;

    shadow) echo "decoration:shadow:enabled bool" ;;
    shadow-range) echo "decoration:shadow:range int" ;;
    shadow-render-power) echo "decoration:shadow:render_power int" ;;
    shadow-scale) echo "decoration:shadow:scale float" ;;
    shadow-sharp) echo "decoration:shadow:sharp bool" ;;

    glow) echo "decoration:glow:enabled bool" ;;
    glow-range) echo "decoration:glow:range int" ;;
    glow-render-power) echo "decoration:glow:render_power int" ;;

    groupbar) echo "group:groupbar:enabled bool" ;;
    groupbar-height) echo "group:groupbar:height int" ;;
    groupbar-font-size) echo "group:groupbar:font_size int" ;;
    groupbar-render-titles) echo "group:groupbar:render_titles bool" ;;
    groupbar-indicator-height) echo "group:groupbar:indicator_height int" ;;
    groupbar-rounding) echo "group:groupbar:rounding int" ;;
    groupbar-gradients) echo "group:groupbar:gradients bool" ;;
    groupbar-stacked) echo "group:groupbar:stacked bool" ;;
    groupbar-disable-when-only) echo "group:groupbar:disable_when_only bool" ;;
    kb-layout) echo "input:kb_layout str" ;;
    kb-variant) echo "input:kb_variant str" ;;
    kb-options) echo "input:kb_options str" ;;
    repeat-rate) echo "input:repeat_rate int" ;;
    repeat-delay) echo "input:repeat_delay int" ;;
    numlock) echo "input:numlock_by_default bool" ;;
    sensitivity) echo "input:sensitivity float" ;;
    accel-profile) echo "input:accel_profile str" ;;
    follow-mouse) echo "input:follow_mouse int" ;;
    natural-scroll) echo "input:touchpad:natural_scroll bool" ;;
    disable-while-typing) echo "input:touchpad:disable_while_typing bool" ;;
    clickfinger) echo "input:touchpad:clickfinger_behavior bool" ;;
    tap-to-click) echo "input:touchpad:tap-to-click bool" ;;
    scroll-factor) echo "input:touchpad:scroll_factor float" ;;
    *) return 1 ;;
  esac
}

# The live value, straight from the compositor — authoritative regardless of
# which file (ours, theirs, a theme's) last set it.
hypr_read() {
  local key=$1 spec keyword type raw
  spec=$(hypr_keyword "$key") || return 1
  keyword=${spec%% *}
  type=${spec##* }
  raw=$(hyprctl -j getoption "$keyword" 2>/dev/null) || return 1
  [[ -n $raw ]] || return 1
  case $type in
    int) jq -c '(.int // 0)' <<<"$raw" ;;
    # Gaps come back as a CSS-style "2 2 2 2" box rather than an int; the
    # window edits them as one number, so read the first side.
    css) jq -c '((.css // "0") | split(" ") | .[0] | tonumber? // 0)' <<<"$raw" ;;
    float) jq -c '((.float // 0) * 1000 | round) / 1000' <<<"$raw" ;;
    # Hyprland answers booleans with a bool field; older builds only had int,
    # and reading int alone made every switch on this page read "off" no
    # matter what the compositor was actually doing.
    bool) jq -c 'if has("bool") then (.bool == true) else ((.int // 0) != 0) end' <<<"$raw" ;;
    # Hyprland spells "no value set" as [[EMPTY]]; the window wants "".
    str) jq -c '((.str // "") | if . == "[[EMPTY]]" then "" else . end)' <<<"$raw" ;;
  esac
}

# Every key the window reads on open. One list rather than a second copy of
# the case above: a setting added there and forgotten here is a control that
# never shows its value.
hypr_keys() {
  cat <<'KEYS'
gaps-in gaps-out float-gaps gaps-workspaces border-size border-part-of-window
snap snap-window-gap snap-monitor-gap
layout dwindle-preserve-split dwindle-smart-split dwindle-force-split
dwindle-split-width-multiplier dwindle-default-split-ratio
master-mfact master-orientation master-new-status
scrolling-column-width scrolling-fullscreen-on-one-column
rounding rounding-power
active-opacity inactive-opacity fullscreen-opacity
dim-inactive dim-strength dim-around dim-modal dim-special
blur blur-size blur-passes blur-noise blur-contrast blur-brightness
blur-vibrancy blur-vibrancy-darkness blur-xray blur-special blur-popups
shadow shadow-range shadow-render-power shadow-scale shadow-sharp
glow glow-range glow-render-power
animations animations-wraparound
groupbar groupbar-height groupbar-font-size groupbar-render-titles
groupbar-indicator-height groupbar-rounding groupbar-gradients
groupbar-stacked groupbar-disable-when-only
kb-layout kb-variant kb-options repeat-rate repeat-delay numlock
sensitivity accel-profile follow-mouse natural-scroll
disable-while-typing clickfinger tap-to-click scroll-factor
KEYS
}

hypr_state() {
  local out='{}' key value
  for key in $(hypr_keys); do
    value=$(hypr_read "$key") || continue
    out=$(jq -c --arg k "$key" --argjson v "$value" '.[$k] = $v' <<<"$out")
  done
  echo "$out"
}

lua_value() {
  local value=$1
  case $value in
    true|false) echo "$value" ;;
    ''|*[!0-9.-]*) printf '"%s"' "$value" ;;
    *) echo "$value" ;;
  esac
}

# Render the store into a generated Lua file (or a conf file on pre-Lua
# setups), and make sure the user's top-level config loads it.
render_managed() {
  local store keys
  store=$(read_store)

  if [[ -f $HYPR_DIR/hyprland.lua ]]; then
    render_managed_lua "$store"
    ensure_loaded "$HYPR_DIR/hyprland.lua" 'require("hypr.omasettings")'
  else
    render_managed_conf "$store"
    ensure_loaded "$HYPR_DIR/hyprland.conf" 'source = ~/.config/hypr/omasettings.conf'
  fi
}

render_managed_lua() {
  local store=$1 pairs

  # Each stored key knows its Hyprland keyword path (e.g. input:touchpad:
  # natural_scroll); jq then folds those paths back into the nested tables the
  # Lua config expects, so two touchpad settings share one touchpad table
  # instead of overwriting each other.
  pairs=$(while read -r key; do
    spec=$(hypr_keyword "$key") || continue
    jq -cn --arg key "$key" --arg keyword "${spec%% *}" '{key: $key, path: ($keyword | split(":"))}'
  done < <(jq -r '.hypr // {} | keys[]' <<<"$store") | jq -s -c .)

  {
    echo "-- Generated by OmaSettings ($MANAGED_MARKER) — do not edit by hand."
    echo "-- Every value here was set from the OmaSettings window; delete a line"
    echo "-- to hand that setting back to your own config."
    echo ""
    jq -r --argjson pairs "$pairs" '
      def lua(v):
        if v == true or v == false then (v | tostring)
        elif (v | type) == "number" then (v | tostring)
        else "\"" + (v | tostring) + "\"" end;
      def render(obj; indent):
        [obj | to_entries[]
          | if (.value | type) == "object"
            then indent + .key + " = {\n" + render(.value; indent + "  ") + indent + "},\n"
            else indent + .key + " = " + lua(.value) + ",\n" end]
        | join("");
      . as $store
      | reduce $pairs[] as $p ({}; setpath($p.path; $store.hypr[$p.key]))
      | to_entries[]
      | "hl.config({\n  " + .key + " = {\n" + render(.value; "    ") + "  },\n})\n"
    ' <<<"$store"

    # Per-device overrides, one hl.device call each.
    jq -r '(.devices // {}) | to_entries[]
      | "hl.device({\n  name = \"" + .key + "\","
        + ([.value | to_entries[]
            | "\n  " + .key + " = "
              + (if (.value | type) == "string" then "\"" + .value + "\"" else (.value | tostring) end) + ","]
           | join(""))
        + "\n})\n"' <<<"$store"
  } | write_file "$MANAGED_LUA" managed
}

render_managed_conf() {
  local store=$1 body="" keyword value
  while read -r key; do
    spec=$(hypr_keyword "$key") || continue
    keyword=${spec%% *}
    value=$(jq -r --arg k "$key" '.hypr[$k]' <<<"$store")
    body+="$(tr ':' ':' <<<"$keyword") = $value"$'\n'
  done < <(jq -r '.hypr // {} | keys[]' <<<"$store")

  {
    echo "# Generated by OmaSettings ($MANAGED_MARKER) — do not edit by hand."
    echo ""
    printf "%s" "$body"
  } | write_file "$MANAGED_CONF" managed
}

# Append the load line to the user's top-level config exactly once.
ensure_loaded() {
  local file=$1 line=$2
  [[ -f $file ]] || return 0
  grep -qF "$line" "$file" && return 0
  backup_once "$file"
  {
    echo ""
    echo "-- Load settings written by OmaSettings ($MANAGED_MARKER)."
    echo "$line"
  } >>"$file"
}

# Applying a setting without waiting for a config reload.
#
# `hyprctl keyword` only works against the legacy parser: on a Lua config it
# answers "keyword can't work with non-legacy parsers. Use eval." So the value
# is handed to the Lua parser as the same nested table the generated file
# would hold, and the keyword form is kept for setups still on .conf.
hypr_apply_live() {
  local keyword=$1 value=$2 type=$3

  if [[ -f $HYPR_DIR/hyprland.lua ]]; then
    local lua_value=$value
    [[ $type == str ]] && lua_value=$(jq -Rn --arg v "$value" '$v')
    hyprctl eval "hl.config($(hypr_lua_table "$keyword" "$lua_value"))" >/dev/null 2>&1
    return
  fi

  local applied=$value
  [[ $type == bool ]] && { [[ $value == true ]] && applied=1 || applied=0; }
  hyprctl keyword "$keyword" "$applied" >/dev/null 2>&1
}

# "input:touchpad:natural_scroll" + true -> { input = { touchpad = { natural_scroll = true } } }
hypr_lua_table() {
  local keyword=$1 value=$2
  awk -v keyword="$keyword" -v value="$value" '
    BEGIN {
      n = split(keyword, parts, ":")
      out = value
      for (i = n; i >= 1; i--) out = "{ " parts[i] " = " out " }"
      print out
    }
  '
}

hypr_set() {
  local key=$1 value=$2 spec keyword type
  spec=$(hypr_keyword "$key") || return 1
  keyword=${spec%% *}
  type=${spec##* }

  case $type in
    int|css) [[ $value =~ ^-?[0-9]+$ ]] || die "'$value' is not a whole number" ;;
    float) [[ $value =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || die "'$value' is not a number" ;;
    bool) [[ $value == true || $value == false ]] || die "'$value' is not true or false" ;;
  esac

  hypr_apply_live "$keyword" "$value" "$type"

  local json
  if [[ $type == bool ]]; then json=$value
  elif [[ $type == str ]]; then json=$(jq -Rn --arg v "$value" '$v')
  else json=$value
  fi
  edit_store '.hypr = ((.hypr // {}) | .[$key] = $value)' --arg key "$key" --argjson value "$json"
}
