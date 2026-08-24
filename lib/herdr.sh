# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# --------------------------------------------------------------------- herdr

# Herdr keeps its own TOML config. It is a hand-written file with comments
# explaining every choice, so it is edited in place, one value at a time,
# rather than regenerated: a settings window that eats your comments is worse
# than no settings window.
HERDR_CONFIG="${OMASETTINGS_HERDR_CONFIG:-$HOME_DIR/.config/herdr/config.toml}"

# The settings this page manages: dotted key, type, and herdr's own default
# for when the file leaves it out.
herdr_schema() {
  cat <<'SCHEMA'
theme.name	string	catppuccin
terminal.new_cwd	string	follow
keys.prefix	string	ctrl+b
ui.accent	string	cyan
ui.window_title	string	{hostname}: {workspace}
ui.tab_bar_position	string	top
ui.sidebar_collapsed_mode	string	compact
ui.sidebar_width	int	26
ui.mouse_scroll_lines	int	3
ui.pane_borders	bool	true
ui.pane_outer_borders	bool	true
ui.pane_scrollbars	bool	true
ui.pane_gaps	bool	true
ui.show_agent_labels_on_pane_borders	bool	false
ui.hide_tab_bar_when_single_tab	bool	false
ui.sidebar_start_collapsed	bool	false
ui.mouse_capture	bool	true
ui.copy_on_select	bool	true
ui.confirm_close	bool	true
ui.prompt_new_tab_name	bool	true
ui.prompt_new_workspace_name	bool	false
ui.toast.delivery	string	off
ui.sound.enabled	bool	true
SCHEMA
}

# Read the scalars we manage out of the file. Only the keys in the schema are
# looked at; arrays, inline tables and anything else stay untouched and
# unreported rather than being half-understood.
herdr_read() {
  [[ -f $HERDR_CONFIG ]] || { echo '{}'; return; }
  awk '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    /^[ \t]*#/ { next }
    /^[ \t]*\[/ {
      section = $0
      gsub(/^[ \t]*\[|\][ \t]*$/, "", section)
      section = trim(section)
      next
    }
    /=/ {
      key = trim(substr($0, 1, index($0, "=") - 1))
      value = trim(substr($0, index($0, "=") + 1))
      sub(/[ \t]+#.*$/, "", value)
      if (key == "" || value ~ /^[\[{]/) next
      full = (section == "" ? key : section "." key)
      # Strings arrive quoted; the window wants the text, not the quoting.
      if (value ~ /^".*"$/) value = substr(value, 2, length(value) - 2)
      printf "%s\t%s\n", full, value
    }
  ' <(read_file "$HERDR_CONFIG") | jq -R -s -c 'split("\n")
    | map(select(length > 0) | split("\t") | { key: .[0], value: .[1] })
    | from_entries'
}

herdr_state() {
  local present installed
  present=$(herdr_read)
  installed=$(command -v herdr >/dev/null 2>&1 && echo true || echo false)

  # Each setting is reported with its effective value: what the file says, or
  # herdr's default when the file is silent.
  herdr_schema | jq -R -s -c --argjson present "$present" --argjson installed "$installed" \
    --arg path "$HERDR_CONFIG" '
    def cast(v; t):
      if t == "bool" then (v == "true")
      elif t == "int" then (v | tonumber? // 0)
      else (v | sub("^\"";"") | sub("\"$";"")) end;
    { installed: $installed,
      path: $path,
      values: (split("\n")
        | map(select(length > 0) | split("\t"))
        | map({ key: .[0],
                value: cast(($present[.[0]] // .[2]); .[1]),
                fromFile: ($present[.[0]] != null) })
        | from_entries) }'
}

# Rewrite one key in place: replace it where it already stands, or add it to
# its table, leaving every comment and every other line exactly as it was.
herdr_write() {
  local key=$1 raw=$2 type=$3
  local table=${key%.*} name=${key##*.} formatted

  case $type in
    bool)
      [[ $raw == true || $raw == false ]] || die "'$raw' is not true or false"
      formatted=$raw ;;
    int)
      [[ $raw =~ ^-?[0-9]+$ ]] || die "'$raw' is not a whole number"
      formatted=$raw ;;
    *)
      formatted=$(jq -Rn --arg v "$raw" '$v') ;;
  esac

  ensure_regular_file "$HERDR_CONFIG" || die "$HERDR_CONFIG is not a file this can write"
  backup_once "$HERDR_CONFIG"

  local previous
  previous=$(read_file "$HERDR_CONFIG")

  awk -v table="$table" -v name="$name" -v line="$name = $formatted" '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    BEGIN { section = ""; done = 0; lastInTable = 0 }
    {
      lines[NR] = $0
      current = $0
      if (current ~ /^[ \t]*\[/) {
        s = current
        gsub(/^[ \t]*\[|\][ \t]*$/, "", s)
        section = trim(s)
        sectionStart[section] = NR
      } else if (section == table && current !~ /^[ \t]*#/ && current ~ /=/) {
        k = trim(substr(current, 1, index(current, "=") - 1))
        if (k == name) { replace = NR }
        lastInTable = NR
      } else if (section == table && trim(current) != "") {
        lastInTable = NR
      }
    }
    END {
      # Replacing in place keeps the setting where its comment explains it.
      if (replace) {
        for (i = 1; i <= NR; i++) print (i == replace ? line : lines[i])
        exit
      }
      # Otherwise it goes at the end of its table, or the table is started.
      anchor = lastInTable ? lastInTable : sectionStart[table]
      if (!anchor) {
        for (i = 1; i <= NR; i++) print lines[i]
        if (NR > 0 && trim(lines[NR]) != "") print ""
        print "[" table "]"
        print line
        exit
      }
      for (i = 1; i <= NR; i++) {
        print lines[i]
        if (i == anchor) print line
      }
    }
  ' <(read_file "$HERDR_CONFIG") | write_file "$HERDR_CONFIG" managed

  # herdr validates its own config; a rejected write is rolled back rather
  # than left for the next herdr start to trip over.
  if command -v herdr >/dev/null 2>&1; then
    local report
    if ! report=$(capture_err herdr config check); then
      printf '%s' "$previous" | write_file "$HERDR_CONFIG" managed
      die "herdr rejected that change, so it was rolled back: $report"
    fi
    herdr server reload-config >/dev/null 2>&1 || true
  fi
}

herdr_cmd() {
  local action=${1:-} key=${2:-} value=${3:-}
  case $action in
    state) herdr_state ;;
    set)
      local type
      type=$(herdr_schema | awk -F'\t' -v k="$key" '$1 == k { print $2 }')
      [[ -n $type ]] || die "unknown herdr setting '$key'"
      local before_herdr
      before_herdr=$(setting_value_now "herdr:$key")
      herdr_write "$key" "$value" "$type"
      [[ ${OMASETTINGS_TRACKING:-1} == 1 ]] && track_write "herdr:$key" "$value" "$before_herdr"
      true ;;
    *) die "unknown herdr action '$action'" ;;
  esac
}
