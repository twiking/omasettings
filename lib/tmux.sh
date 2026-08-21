# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ---------------------------------------------------------------------- tmux

# tmux.conf is a script, not a settings file: the same option can be set more
# than once and the last one wins. So a value is replaced where it already
# stands, and appended only when the option is absent.
TMUX_CONFIG="${OMASETTINGS_TMUX_CONFIG:-$HOME_DIR/.config/tmux/tmux.conf}"

# key, type, default, scope (server/window). tmux spells booleans on/off.
tmux_schema() {
  cat <<'SCHEMA'
prefix	string	C-b	server
mouse	bool	off	server
status-position	string	bottom	server
mode-keys	string	emacs	window
base-index	int	0	server
pane-base-index	int	0	window
history-limit	int	2000	server
escape-time	int	500	server
renumber-windows	bool	off	server
set-clipboard	string	external	server
SCHEMA
}

# The live server is the truth when one is running; the file is all there is
# otherwise. A value set by hand in a running session is what the user sees,
# so that is what this page should show.
tmux_read() {
  if tmux has-session 2>/dev/null; then
    {
      # Server options (-s) hold escape-time and set-clipboard; the global and
      # window tables hold the rest.
      tmux show-options -s 2>/dev/null
      tmux show-options -g 2>/dev/null
      tmux show-options -gw 2>/dev/null
    } | awk '{ key = $1; $1 = ""; sub(/^ /, ""); gsub(/^"|"$/, "", $0); printf "%s\t%s\n", key, $0 }'
  else
    [[ -f $TMUX_CONFIG ]] || return 0
    awk '
      function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
      /^[ \t]*#/ { next }
      /^[ \t]*(set|setw|set-option|set-window-option)[ \t]/ {
        # Skip the flags (-g, -sg, -as, ...) to reach the option name.
        i = 2
        while (i <= NF && $i ~ /^-/) i++
        if (i > NF) next
        key = $i
        value = ""
        for (j = i + 1; j <= NF; j++) value = value (value == "" ? "" : " ") $j
        gsub(/^"|"$/, "", value)
        printf "%s\t%s\n", key, trim(value)
      }
    ' "$TMUX_CONFIG"
  fi
}

tmux_state() {
  local present running
  present=$(tmux_read | jq -R -s -c 'split("\n")
    | map(select(length > 0) | split("\t") | { key: .[0], value: (.[1] // "") })
    | from_entries')
  running=$(tmux has-session 2>/dev/null && echo true || echo false)

  tmux_schema | jq -R -s -c --argjson present "${present:-{\}}" --argjson running "$running" \
    --arg path "$TMUX_CONFIG" '
    def cast(v; t):
      if t == "bool" then (v == "on")
      elif t == "int" then (v | tonumber? // 0)
      else v end;
    { installed: true,
      running: $running,
      path: $path,
      values: (split("\n")
        | map(select(length > 0) | split("\t"))
        | map({ key: .[0], value: cast(($present[.[0]] // .[2]); .[1]) })
        | from_entries) }'
}

tmux_write() {
  local key=$1 raw=$2 type=$3 scope=$4 formatted

  case $type in
    bool)
      [[ $raw == true || $raw == false ]] || die "'$raw' is not true or false"
      [[ $raw == true ]] && formatted=on || formatted=off ;;
    int)
      [[ $raw =~ ^[0-9]+$ ]] || die "'$raw' is not a whole number"
      formatted=$raw ;;
    *)
      [[ -n $raw ]] || die "'$key' needs a value"
      formatted=$raw ;;
  esac

  [[ -f $TMUX_CONFIG ]] || { mkdir -p "$(dirname "$TMUX_CONFIG")"; : >"$TMUX_CONFIG"; }
  backup_once "$TMUX_CONFIG"

  local setter="set -g"
  [[ $scope == window ]] && setter="setw -g"

  awk -v key="$key" -v line="$setter $key $formatted" '
    BEGIN { replaced = 0 }
    {
      lines[NR] = $0
      if ($0 ~ /^[ \t]*(set|setw|set-option|set-window-option)[ \t]/ && $0 !~ /^[ \t]*#/) {
        i = 2
        while (i <= NF && $i ~ /^-/) i++
        if (i <= NF && $i == key) last = NR
      }
    }
    END {
      if (last) {
        # The last assignment is the one tmux honours, so that is the one to
        # rewrite; earlier ones stay as the record of what was tried.
        for (i = 1; i <= NR; i++) print (i == last ? line : lines[i])
      } else {
        for (i = 1; i <= NR; i++) print lines[i]
        print line
      }
    }
  ' "$TMUX_CONFIG" | write_file "$TMUX_CONFIG" managed

  # A running server takes the change immediately; without one the file is
  # enough, since tmux reads it at start.
  if tmux has-session 2>/dev/null; then
    local flag="-g"
    [[ $scope == window ]] && flag="-gw"
    tmux set-option $flag "$key" "$formatted" >/dev/null 2>&1 \
      || die "tmux rejected $key = $formatted"
  fi
}
