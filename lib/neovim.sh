# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# -------------------------------------------------------------------- neovim

# LazyVim reads user options from lua/config/options.lua. Same rule as the
# other hand-written files: replace in place, append when absent.
NVIM_OPTIONS="${OMASETTINGS_NVIM_OPTIONS:-$HOME_DIR/.config/nvim/lua/config/options.lua}"

nvim_schema() {
  cat <<'SCHEMA'
number	bool	true
relativenumber	bool	true
wrap	bool	false
cursorline	bool	true
expandtab	bool	true
spell	bool	false
scrolloff	int	4
tabstop	int	2
shiftwidth	int	2
conceallevel	int	2
colorcolumn	string	
signcolumn	string	yes
SCHEMA
}

nvim_read() {
  [[ -f $NVIM_OPTIONS ]] || return 0
  awk '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    /^[ \t]*--/ { next }
    /^[ \t]*vim\.(opt|o)\.[A-Za-z_]+[ \t]*=/ {
      key = $0
      sub(/^[ \t]*vim\.(opt|o)\./, "", key)
      sub(/[ \t]*=.*$/, "", key)
      value = $0
      sub(/^[^=]*=[ \t]*/, "", value)
      sub(/[ \t]*--.*$/, "", value)
      value = trim(value)
      gsub(/^"|"$/, "", value)
      printf "%s\t%s\n", trim(key), value
    }
  ' "$NVIM_OPTIONS"
}

nvim_state() {
  local present installed
  present=$(nvim_read | jq -R -s -c 'split("\n")
    | map(select(length > 0) | split("\t") | { key: .[0], value: (.[1] // "") })
    | from_entries')
  installed=$(command -v nvim >/dev/null 2>&1 && echo true || echo false)

  nvim_schema | jq -R -s -c --argjson present "${present:-{\}}" --argjson installed "$installed" \
    --arg path "$NVIM_OPTIONS" '
    def cast(v; t):
      if t == "bool" then (v == "true")
      elif t == "int" then (v | tonumber? // 0)
      else v end;
    { installed: $installed,
      path: $path,
      values: (split("\n")
        | map(select(length > 0) | split("\t"))
        | map({ key: .[0], value: cast(($present[.[0]] // (.[2] // "")); .[1]) })
        | from_entries) }'
}

nvim_write() {
  local key=$1 raw=$2 type=$3 formatted

  case $type in
    bool)
      [[ $raw == true || $raw == false ]] || die "'$raw' is not true or false"
      formatted=$raw ;;
    int)
      [[ $raw =~ ^[0-9]+$ ]] || die "'$raw' is not a whole number"
      formatted=$raw ;;
    *)
      formatted=$(jq -Rn --arg v "$raw" '$v') ;;
  esac

  [[ -f $NVIM_OPTIONS ]] || { mkdir -p "$(dirname "$NVIM_OPTIONS")"; : >"$NVIM_OPTIONS"; }
  backup_once "$NVIM_OPTIONS"

  local previous
  previous=$(cat "$NVIM_OPTIONS")

  awk -v key="$key" -v line="vim.opt.$key = $formatted" '
    {
      lines[NR] = $0
      if ($0 !~ /^[ \t]*--/ && $0 ~ "^[ \t]*vim\\.(opt|o)\\." key "[ \t]*=") last = NR
    }
    END {
      if (last) {
        for (i = 1; i <= NR; i++) print (i == last ? line : lines[i])
      } else {
        for (i = 1; i <= NR; i++) print lines[i]
        print line
      }
    }
  ' "$NVIM_OPTIONS" | write_file "$NVIM_OPTIONS" managed

  # Lua that does not parse would break every future nvim start, so the file
  # is compiled before it is left in place.
  if command -v nvim >/dev/null 2>&1; then
    local report
    if ! report=$(nvim --headless --clean \
      -c "lua local fn, err = loadfile('$NVIM_OPTIONS'); if not fn then io.stderr:write(err) ; vim.cmd('cq') end" \
      -c "qa" 2>&1); then
      printf '%s' "$previous" | write_file "$NVIM_OPTIONS" managed
      die "that would not parse, so it was rolled back: $report"
    fi
  fi
}

app_cmd() {
  local app=${1:-} action=${2:-} key=${3:-} value=${4:-}
  case $app/$action in
    tmux/state) tmux_state ;;
    tmux/set)
      local spec type scope
      spec=$(tmux_schema | awk -F'\t' -v k="$key" '$1 == k { print $2 "\t" $4 }')
      [[ -n $spec ]] || die "unknown tmux setting '$key'"
      type=${spec%%$'\t'*}
      scope=${spec##*$'\t'}
      tmux_write "$key" "$value" "$type" "$scope" ;;
    nvim/state) nvim_state ;;
    nvim/set)
      local type
      type=$(nvim_schema | awk -F'\t' -v k="$key" '$1 == k { print $2 }')
      [[ -n $type ]] || die "unknown neovim setting '$key'"
      nvim_write "$key" "$value" "$type" ;;
    *) die "unknown app command '$app $action'" ;;
  esac
}
