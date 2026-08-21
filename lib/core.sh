# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Paths, and the handful of helpers every other module leans on: how a file is
# written, and the promise that a hand-written file is copied before it is
# first touched.

HOME_DIR=${HOME:?}
SHELL_JSON="${OMARCHY_SHELL_JSON:-$HOME_DIR/.config/omarchy/shell.json}"
STORE="${OMASETTINGS_STORE:-$HOME_DIR/.config/omarchy/omasettings.json}"
HYPR_DIR="${OMASETTINGS_HYPR_DIR:-$HOME_DIR/.config/hypr}"
MANAGED_LUA="$HYPR_DIR/omasettings.lua"
MANAGED_CONF="$HYPR_DIR/omasettings.conf"
XCOMPOSE="${OMASETTINGS_XCOMPOSE:-$HOME_DIR/.XCompose}"

MANAGED_MARKER="omasettings:managed"

die() { echo "omasettings: $*" >&2; exit 1; }

# The first time OmaSettings writes to a file the user could have edited by
# hand, keep a copy of what was there. Only the first time: later writes must
# not overwrite the pristine backup with our own output.
backup_once() {
  local file=$1
  [[ -f $file ]] || return 0
  [[ -e "$file.omasettings.bak" ]] && return 0
  cp -p "$file" "$file.omasettings.bak"
}

# `managed` marks a file OmaSettings generates in full: there is no
# hand-written version of it worth keeping a backup of.
write_file() {
  local file=$1 managed=${2:-} tmp
  [[ -n $managed ]] || backup_once "$file"
  mkdir -p "$(dirname "$file")"
  tmp=$(mktemp "$file.omasettings.XXXXXX") || return 1
  cat >"$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file"
}

lines_to_array() { jq -Rn '[inputs | select(length > 0)]'; }
