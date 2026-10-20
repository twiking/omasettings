# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ---------------------------------------------------------------- pointer style
#
# The pointer's theme and size are two extras, like animation speed: values of
# our own in the store, rendered into the managed Lua as hl.env lines. That
# file loads last, so a pick here wins over a hand-written cursor.lua, and
# putting it back leaves the pointer to whatever set it before. hyprctl
# setcursor switches the one on screen; the env is for the next login.
#
# Reading the themes needs Xcursor parsing and PNG writing, which bash cannot
# do, so that half is cursors.py beside this file.

POINTER_SIZES=(24 32 40 48 64)

pointer_py() { python3 -I "$OMASETTINGS_LIB/cursors.py" "$@"; }

# What is in force: ours if set, else the session's own.
pointer_theme() { extras_get pointer-theme "${XCURSOR_THEME:-Adwaita}"; }
pointer_size() {
  local size
  size=$(extras_get pointer-size "${XCURSOR_SIZE:-24}")
  [[ $size =~ ^[0-9]+$ ]] || size=24
  echo "$size"
}

pointer_state() {
  local listing
  listing=$(pointer_py list 2>/dev/null) || listing='{"themes":[],"downloads":[],"sizes":[]}'
  jq -c --arg theme "$(pointer_theme)" --argjson size "$(pointer_size)" \
    '. + { theme: $theme, size: $size }' <<<"$listing"
}

pointer_apply_live() {
  local theme size
  theme=$(pointer_theme)
  size=$(pointer_size)
  hyprctl setcursor "$theme" "$size" >/dev/null 2>&1 || true
  # GTK apps read the pointer from gsettings, not the environment.
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface cursor-theme "$theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null || true
  fi
}

pointer_set_theme() {
  local theme=${1:-}
  pointer_py has "$theme" || die "no cursor theme called '$theme'"
  extras_set pointer-theme "$theme" ""
  pointer_apply_live
}

pointer_set_size() {
  local size=${1:-} s
  for s in "${POINTER_SIZES[@]}"; do
    if [[ $size == "$s" ]]; then
      extras_set pointer-size "$size" ""
      pointer_apply_live
      return
    fi
  done
  die "pointer size must be one of ${POINTER_SIZES[*]}"
}

# Called from render_extras_lua. Nothing is written until a theme is picked:
# a size alone would override the session's size and leave its theme.
render_pointer_lua() {
  local theme size
  theme=$(extras_get pointer-theme "")
  [[ -n $theme ]] || return 0
  size=$(extras_get pointer-size "${XCURSOR_SIZE:-24}")
  echo ""
  echo "-- Pointer style, from the Mouse & Touchpad page."
  printf 'hl.env("XCURSOR_THEME", "%s")\nhl.env("XCURSOR_SIZE", "%s")\n' "$theme" "$size"
  printf 'hl.env("HYPRCURSOR_THEME", "%s")\nhl.env("HYPRCURSOR_SIZE", "%s")\n' "$theme" "$size"
}

pointer_cmd() {
  local action=${1:-}
  case $action in
    fetch) [[ ${2:-} =~ ^[0-9]+$ ]] || die "usage: omasettings pointer fetch <index>"; pointer_py fetch "$2" ;;
    *) die "usage: omasettings pointer fetch <index>" ;;
  esac
}
