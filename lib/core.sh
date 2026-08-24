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

# The window is a long-lived shell process that retains and parses whatever a
# reader prints, so a producer that hangs or never stops is its problem too.
# Every read of the compositor or the system goes through here: bounded in
# time, and bounded in bytes before any of it is held.
OMASETTINGS_READ_TIMEOUT=${OMASETTINGS_READ_TIMEOUT:-5}
OMASETTINGS_READ_MAX=${OMASETTINGS_READ_MAX:-4194304}

capture() {
  timeout "$OMASETTINGS_READ_TIMEOUT" "$@" 2>/dev/null | head -c "$OMASETTINGS_READ_MAX"
}

# The first time OmaSettings writes to a file the user could have edited by
# hand, keep a copy of what was there. Only the first time: later writes must
# not overwrite the pristine backup with our own output.
# The backup path is predictable, so it is never written through: a symlink
# sitting there is treated as "already taken" rather than followed, and the
# copy is created exclusively by linking a fresh sibling into place.
backup_once() {
  local file=$1 bak tmp
  bak="$file.omasettings.bak"
  [[ -f $file ]] || return 0
  [[ -e $bak || -L $bak ]] && return 0
  tmp=$(mktemp "$file.omasettings.bak.XXXXXX") || return 1
  cat -- "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  chmod --reference="$file" "$tmp" 2>/dev/null
  ln "$tmp" "$bak" 2>/dev/null
  rm -f "$tmp"
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
