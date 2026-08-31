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

# ---------------------------------------------------------- asked together
#
# A state read is two dozen independent questions put to the system — the
# theme, the plugins, the network, the battery, the keyboard — and nearly all
# of its time is spent waiting for each answer rather than working out any of
# them. Asked one after another they took two and a half seconds. Asked
# together they take as long as the slowest one alone.
#
# This is not a nicety. Every button in the window waits for a state read
# before anything on screen moves, so it is the difference between a window
# that answers and one that thinks about it.
#
# Two rules keep it safe. **Only reads go in here** — anything that writes runs
# before the block, or two of them race for the same file. And **a producer
# must not depend on another one's output**: what is derived from several
# answers is derived after they are all in.
par_begin() {
  PAR_DIR=$(mktemp -d) || return 1
}

# The name is the answer's; the rest is the question. A producer that fails
# leaves an empty file, which par_get reads as the fallback.
par_run() {
  local name=$1
  shift
  ( "$@" >"$PAR_DIR/$name" 2>/dev/null ) &
}

par_wait() { wait; }

# Bounded, like every other read here. The answers are ours, written into a
# directory only this process can see, so there is no name to be swapped
# underneath them — but they are the output of tools that can say more than
# anyone expected, and this is the last place their size is ours to limit
# before the shell that lives as long as the bar parses them.
par_get() {
  local file=$PAR_DIR/$1
  [[ -s $file ]] && head -c "$OMASETTINGS_READ_MAX" "$file" && return
  printf '%s' "${2:-}"
}

par_end() {
  [[ -n ${PAR_DIR:-} ]] && rm -rf "$PAR_DIR"
  PAR_DIR=""
}

# Same bounds, but the tool's own complaint is what the caller is after: a
# validator that rejects a write has to be able to say why.
capture_err() {
  timeout "$OMASETTINGS_READ_TIMEOUT" "$@" 2>&1 | head -c "$OMASETTINGS_READ_MAX"
}

# Reading someone else's file means reading a name, and a name is not a
# promise: between the test and the open it can become a symlink somewhere
# else, a FIFO that never answers, or something far larger than a config. So
# the open happens first and every check is made against the descriptor, not
# the path. A config that is legitimately a symlink into a dotfiles repo still
# reads, because what is verified is that the descriptor is the regular file
# the path resolves to, and the read is bounded either way.
read_file() {
  timeout "$OMASETTINGS_READ_TIMEOUT" sh -c '
    exec 3<"$1" || exit 1
    [ -f /dev/fd/3 ] || exit 1
    opened=$(stat -Lc "%d:%i" /dev/fd/3 2>/dev/null) || exit 1
    named=$(stat -Lc "%d:%i" -- "$1" 2>/dev/null) || exit 1
    [ "$opened" = "$named" ] || exit 1
    head -c "$2" <&3
  ' sh "$1" "$OMASETTINGS_READ_MAX" 2>/dev/null
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
  [[ -e $file || -L $file ]] || return 0
  [[ -e $bak || -L $bak ]] && return 0
  tmp=$(mktemp "$file.omasettings.bak.XXXXXX") || return 1
  # A file we cannot read as a bounded regular file is one we will not write
  # either: the caller aborts rather than changing something it could not copy.
  read_file "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  chmod --reference="$file" "$tmp" 2>/dev/null
  ln "$tmp" "$bak" 2>/dev/null
  rm -f "$tmp"
}

# Creating a config that is not there yet means creating a *file*: opening a
# FIFO for writing waits for a reader that never comes, and a device node at
# that path is not something a setting belongs in. Anything already there has
# to be a regular file, symlinked or not, or nothing is written at all.
ensure_regular_file() {
  local file=$1
  if [[ -e $file || -L $file ]]; then
    [[ -f $file ]] || return 1
    return 0
  fi
  mkdir -p "$(dirname "$file")" || return 1
  : >"$file"
}

# `managed` marks a file OmaSettings generates in full: there is no
# hand-written version of it worth keeping a backup of.
write_file() {
  local file=$1 managed=${2:-} tmp target
  ensure_regular_file "$file" || return 1
  [[ -n $managed ]] || backup_once "$file" || return 1
  # A config symlinked into a dotfiles repo is a config, not a redirect to
  # refuse: the rename lands on what the link points at, so the link survives
  # and the repo sees the change. The resolved path has to be a regular file
  # for that to be true, which ensure_regular_file has already said.
  target=$(readlink -f -- "$file") && [[ -f $target ]] || target=$file
  mkdir -p "$(dirname "$target")"
  tmp=$(mktemp "$target.omasettings.XXXXXX") || return 1
  cat >"$tmp" || { rm -f "$tmp"; return 1; }
  chmod --reference="$target" "$tmp" 2>/dev/null
  mv "$tmp" "$target"
}

lines_to_array() { jq -Rn '[inputs | select(length > 0)]'; }
