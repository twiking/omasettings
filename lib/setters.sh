# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------------- setters

set_key() {
  local key=${1:-} value=${2:-}
  case $key in
    theme) [[ -n $value ]] || die "no theme given"; omarchy-theme-set "$value" ;;
    font) [[ -n $value ]] || die "no font given"; omarchy font set "$value" ;;
    text-scale) [[ -n $value ]] || die "no text size given"; omarchy display text size "$value" ;;
    nightlight)
      # The toggle script has no absolute set, so only flip when the requested
      # state differs from the live one — repeated clicks stay idempotent.
      [[ $(nightlight_enabled) == "$value" ]] || omarchy-toggle-nightlight ;;
    bar-position)
      case $value in
        top|bottom|left|right) omarchy bar position "$value" ;;
        *) die "bad bar position '$value'" ;;
      esac ;;
    bar-transparent)
      case $value in
        true|false|toggle) omarchy bar transparent "$value" ;;
        *) die "bad bar transparency '$value'" ;;
      esac ;;
    bar-center-anchor)
      [[ -n $value ]] || die "no widget id given"
      edit_shell_json '.bar = ((.bar // {}) | .centerAnchor = $id)' --arg id "$value" ;;
    idle-screensaver|idle-lock)
      local field=${key#idle-}
      [[ $value =~ ^[0-9]+$ ]] || die "'$value' is not a number of seconds"
      edit_shell_json '.idle = ((.idle // {}) | .[$field] = ($seconds | tonumber))' \
        --arg field "$field" --arg seconds "$value" ;;
    monitor-scale)
      # "<output>=<scale>": scaling is per output, and the window sends the one
      # the user picked rather than assuming a single screen.
      local output=${value%%=*} scale=${value#*=}
      [[ -n $output && $scale =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "expected <output>=<scale>"
      local mode
      mode=$(hyprctl -j monitors 2>/dev/null | jq -r --arg o "$output" '.[] | select(.name == $o) | "\(.width)x\(.height)@\(.refreshRate | floor)"')
      [[ -n $mode ]] || die "no monitor named '$output'"
      hyprctl keyword monitor "$output,$mode,auto,$scale" >/dev/null 2>&1
      edit_store '.monitors = ((.monitors // {}) | .[$o] = { scale: ($s | tonumber), mode: $m })' \
        --arg o "$output" --arg s "$scale" --arg m "$mode" ;;
    *)
      hypr_set "$key" "$value" || die "unknown key '$key'" ;;
  esac
}

search_cmd() { search_index; }

plugin_cmd() {
  local action=${1:-} id=${2:-}
  # The update sweep is about every plugin at once, so it is the one action
  # that takes no id.
  [[ $action == updates ]] && { plugin_updates; return; }
  [[ $action == updates-cached ]] && { plugin_updates_cache; return; }
  [[ $action == self ]] && { self_update_state; return; }
  [[ $action == self-check ]] && { self_check; return; }
  [[ -n $id ]] || die "no plugin id given"
  case $action in
    enable) omarchy plugin enable "$id" ;;
    disable) omarchy plugin disable "$id" ;;
    # Removal asks for confirmation and prints what it deleted, so it belongs
    # in a terminal of its own — and one that outlives this window.
    remove)
      setsid bash -lc "omarchy-launch-floating-terminal-with-presentation $(printf '%q' "omarchy-plugin-remove $(printf '%q' "$id")")" >/dev/null 2>&1 &
      disown 2>/dev/null || true ;;
    # Updating shows the incoming diff and asks before pulling, so it gets a
    # terminal of its own too.
    update)
      setsid bash -lc "omarchy-launch-floating-terminal-with-presentation $(printf '%q' "omarchy-plugin-update $(printf '%q' "$id")")" >/dev/null 2>&1 &
      disown 2>/dev/null || true ;;
    *) die "unknown plugin action '$action'" ;;
  esac
}

compose_cmd() {
  local action=${1:-}
  shift || true
  case $action in
    list) compose_entries ;;
    add) compose_add "${1:-}" "${2:-}" ;;
    remove) compose_remove "${1:-}" ;;
    *) die "unknown compose action '$action'" ;;
  esac
}
