# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------------- setters

# ------------------------------------------------- settings we can put back
#
# A Hyprland setting has an unset state: dropping our key hands it back to
# whatever Omarchy, the theme or the user's own config says. These do not.
# They are written into Omarchy's own config by Omarchy's own commands, so the
# only way to put one back is to remember what it was before the first write
# and write that. The window says "changed" for both, because from the outside
# they are the same thing: you changed it, and it can go back.
#
# The live pages are deliberately absent — audio, network, bluetooth, power
# move on their own, so "changed" would mean nothing there.
setting_current() {
  local cfg
  case ${1:-} in
    theme) omarchy-theme-current 2>/dev/null | head -n1 ;;
    font) omarchy font current 2>/dev/null | head -n1 ;;
    text-scale) omarchy display text size 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?' | head -n1 ;;
    nightlight) nightlight_enabled ;;
    bar-position) jq -r '.bar.position // "top"' <<<"$(read_shell_json)" ;;
    bar-transparent) jq -r '((.bar.transparent // false) | tostring)' <<<"$(read_shell_json)" ;;
    bar-center-anchor) jq -r '.bar.centerAnchor // ""' <<<"$(read_shell_json)" ;;
    idle-screensaver) jq -r '.idle.screensaver // empty' <<<"$(read_shell_json)" ;;
    idle-lock) jq -r '.idle.lock // empty' <<<"$(read_shell_json)" ;;
    *) return 1 ;;
  esac
}

# The pages that keep their settings in someone else's config file. Same shape
# as the block above — read the value, write it back to undo — but the keys
# are named by what they configure, so they carry a prefix.
setting_current_prefixed() {
  local key=${1:-} name=${key#*:}
  case $key in
    # A display carries which of its settings the key means, since it has
    # more than one that can be put back. The bare form is what earlier
    # versions wrote, when scale was the only one.
    monitor:*:*) monitor_value_now "${name%:*}" "${name##*:}" ;;
    monitor:*) monitor_value_now "$name" scale ;;
    tmux:*) jq -r --arg k "$name" '.values | if has($k) then .[$k] | tostring else empty end' <<<"$(tmux_state)" ;;
    nvim:*) jq -r --arg k "$name" '.values | if has($k) then .[$k] | tostring else empty end' <<<"$(nvim_state)" ;;
    herdr:*) jq -r --arg k "$name" '.values | if has($k) then .[$k] | tostring else empty end' <<<"$(herdr_state)" ;;
    *) return 1 ;;
  esac
}

setting_tracked() {
  setting_current "$1" >/dev/null 2>&1 && return 0
  case ${1:-} in
    monitor:*) [[ -n $(setting_current_prefixed "$1" 2>/dev/null) ]] && return 0 || return 1 ;;
    tmux:*|nvim:*|herdr:*) return 0 ;;
  esac
  return 1
}

# Whatever a key is, this is what it is set to now.
setting_value_now() {
  setting_current "$1" 2>/dev/null || setting_current_prefixed "$1" 2>/dev/null
}

# Writing a prefixed key means handing it back to the page that owns it.
setting_write() {
  local key=${1:-} value=${2:-} name=${key#*:}
  # The page's own command records for itself; this call is the mechanism, not
  # a change of its own.
  local OMASETTINGS_TRACKING=0
  case $key in
    monitor:*:*) monitor_set "${name%:*}" "${name##*:}" "$value" ;;
    monitor:*) monitor_set "$name" scale "$value" ;;
    tmux:*) app_cmd tmux set "$name" "$value" ;;
    nvim:*) app_cmd nvim set "$name" "$value" ;;
    herdr:*) herdr_cmd set "$name" "$value" ;;
    *) set_key_apply "$key" "$value" ;;
  esac
}

# Remember what a key was before this window first wrote it, and forget it
# again the moment it is written back to that. Every page that writes through
# its own command calls this rather than reimplementing it.
# $3 is what the setting was *before* the write that prompted this. Reading it
# here instead would read what it has just become, and record the new value as
# the thing to go back to.
track_write() {
  local key=${1:-} value=${2:-} before=${3:-} store original
  store=$(read_store)
  if jq -e --arg k "$key" '(.written // {}) | has($k)' <<<"$store" >/dev/null; then
    original=$(jq -r --arg k "$key" '.written[$k]' <<<"$store")
  else
    original=$before
  fi

  if [[ $value == "$original" ]]; then
    edit_store 'if .written then .written |= del(.[$k]) else . end' --arg k "$key"
  else
    edit_store '.written = ((.written // {}) | (if has($k) then . else .[$k] = $o end))' \
      --arg k "$key" --arg o "$original"
  fi
}

# The keys this window has written and what they were before it did.
written_changed() {
  jq -c '(.written // {}) | keys' <<<"$(read_store)"
}

set_key() {
  local key=${1:-} value=${2:-}

  if setting_tracked "$key"; then
    # Unlike a Hyprland key there is nothing to delete — the value has to be
    # written either way. What goes is only the record that it differs.
    local before after
    before=$(setting_value_now "$key")
    setting_write "$key" "$value"
    # What took, not what was asked for: Hyprland snaps a scale it cannot do
    # exactly, and a mark saying "changed" beside the value it already had is
    # a mark that cannot be cleared.
    after=$(setting_value_now "$key")
    track_write "$key" "${after:-$value}" "$before"
    return
  fi

  set_key_apply "$key" "$value"
}

set_key_apply() {
  local key=${1:-} value=${2:-}
  case $key in
    monitor:*:*) local rest=${key#monitor:}; monitor_set "${rest%:*}" "${rest##*:}" "$value" ;;
    animation-speed)
      [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "'$value' is not a speed"
      extras_set animation-speed "$value" 1 ;;
    opaque-windows)
      [[ $value == true || $value == false ]] || die "'$value' is not true or false"
      extras_set opaque-windows "$value" false ;;
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
    # "<output>=<value>": both are per display, and the window sends the one
    # the user picked rather than assuming a single screen.
    monitor-scale|monitor-mode)
      local output=${value%%=*} setting=${value#*=}
      [[ -n $output && $output != "$value" ]] || die "expected <output>=<value>"
      monitor_set "$output" "${key#monitor-}" "$setting" ;;
    monitor-remember) monitor_remember "$value" ;;
    monitor-forget) monitor_forget "$value" ;;
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
    # Updating asks nothing this window has not already asked — the row says
    # how many commits are coming and what they say — so no terminal. It does
    # detach, because upstream's last act reloads every plugin's QML and would
    # otherwise kill the update it started. See plugin_update_start.
    update) plugin_update_start "$id" ;;
    # Not for the window to call: this is the detached half, re-entering to do
    # the work after rescanPlugins has torn the caller down.
    update-run) plugin_update_run "$id" ;;
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

# Putting one back: write what it was before, and forget it was ever changed.
# A Hyprland key goes the other way — see hypr_reset, which drops the key and
# lets the value come from wherever it came from before.
setting_reset() {
  local key=${1:-}
  [[ -n $key ]] || die "no setting given"

  # Everything this window has a hand in, each by its own way back. The
  # per-device overrides go through the same door as the rest rather than
  # being cleared behind their backs.
  if [[ $key == --all ]]; then
    local k
    while read -r k; do
      [[ -n $k ]] || continue
      setting_reset "$k"
    done < <(jq -r '(.written // {}) | keys[]' <<<"$(read_store)")
    while read -r k; do
      [[ -n $k ]] || continue
      setting_reset "$k"
    done < <(devices_changed | jq -r '.[]')
    hypr_reset --all
    return
  fi

  # A per-device setting is an override like a Hyprland key: clearing it hands
  # the device back to the global setting, so there is nothing to write back.
  if [[ $key == animation-speed ]]; then extras_set animation-speed 1 1; return; fi
  if [[ $key == opaque-windows ]]; then extras_set opaque-windows false false; return; fi

  if [[ $key == device:* ]]; then
    local rest=${key#device:} name option
    name=${rest%:*}
    option=${rest##*:}
    device_clear "$name" "$option"
    return
  fi

  if setting_tracked "$key"; then
    local original
    original=$(jq -r --arg k "$key" '(.written // {}) | if has($k) then .[$k] else empty end' <<<"$(read_store)")
    [[ -n $original ]] || return 0
    setting_write "$key" "$original"
    edit_store 'if .written then .written |= del(.[$k]) else . end' --arg k "$key"
    # A display keeps no record of its own once it is back to what it was. The
    # rule goes with the last setting on it, and not before: what is left in
    # there is the mode or scale filled in to keep the rule complete, which
    # nobody asked for and which would go on overriding their config.
    if [[ $key == monitor:*:* ]]; then
      local rest=${key#monitor:} display
      display=${rest%:*}
      if jq -e --arg n "$display" '(.written // {}) | keys | any(startswith("monitor:" + $n + ":"))' \
           <<<"$(read_store)" >/dev/null; then
        monitor_unset "$display" "${rest##*:}"
      else
        monitor_forget "$display"
      fi
    fi
    return
  fi

  hypr_reset "$key"
}
