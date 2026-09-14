# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# --------------------------------------------------------------- keybindings

# Omarchy's bindings live in Lua and are reported by `hyprctl binds` as an
# opaque __lua dispatcher, so the list comes from Omarchy's own reader. What
# OmaSettings adds or disables is kept in its store and rendered into a marked
# block at the end of the user's bindings file — the rest of that file, which
# is theirs, is never parsed or rewritten.
BINDINGS_LUA="${OMASETTINGS_BINDINGS_LUA:-$HYPR_DIR/bindings.lua}"
BINDINGS_CONF="${OMASETTINGS_BINDINGS_CONF:-$HYPR_DIR/bindings.conf}"
BINDINGS_BEGIN="-- >>> omasettings bindings (generated; edit them in OmaSettings)"
BINDINGS_END="-- <<< omasettings bindings"

# Normalised so "super+shift+r", "SUPER + SHIFT + R" and "Super Shift R" are
# one binding rather than three.
keys_normalise() {
  tr 'a-z' 'A-Z' <<<"$1" | sed -E 's/[[:space:]]*\+[[:space:]]*/ + /g; s/[[:space:]]+/ + /g; s/(\+ ){2,}/+ /g; s/^ *| *$//g'
}

bindings_store() { read_store | jq -c '.bindings // {added: [], disabled: []}'; }

BINDINGS_SCHEMA=1

# Schema 1: keys, descriptions and commands were written down Lua-escaped,
# because the Lua renderer pasted them between bare quotes. The .conf renderer
# reads the same fields, where that escaping is wrong — and `awk -v` happened
# to strip it back off on the way out, so both formats came out right by
# accident. Escaping now happens where the Lua is built, so what is stored is
# the value as typed, and what an older version wrote is unescaped once. The
# old escaping doubled backslashes and then prefixed quotes, so undoing it in
# that order is exact.
bindings_migrate() {
  local schema
  schema=$(jq -r '(.bindingsSchema // 0)' <<<"$(read_store)")
  # A flag we cannot read is not a reason to transform again: re-running
  # the unescape would halve every backslash a second time.
  [[ $schema =~ ^[0-9]+$ ]] || return 0
  ((schema >= BINDINGS_SCHEMA)) && return 0

  edit_bindings '
    def unescape: if type == "string"
      then gsub("\\\\\""; "\"") | gsub("\\\\\\\\"; "\\") else . end;
    if .bindings then
      .bindings.added = ((.bindings.added // [])
          | map(.keys |= unescape | .description |= unescape | .command |= unescape))
      | .bindings.disabled = ((.bindings.disabled // []) | map(unescape))
    else . end
    | .bindingsSchema = $v' --argjson v "$BINDINGS_SCHEMA"
}

render_bindings() {
  local store target begin_line body
  store=$(bindings_store)

  target=$BINDINGS_LUA
  [[ -f $BINDINGS_LUA ]] || { [[ -f $BINDINGS_CONF ]] && target=$BINDINGS_CONF; }
  [[ -f $target ]] || return 0

  if [[ $target == *.lua ]]; then
    body=$(jq -r '
      ((.disabled // [])[] | "hl.unbind(" + (. | @json) + ")"),
      ((.added // [])[] | "o.bind(" + (.keys | @json) + ", " + (.description | @json)
        + ", " + (.command | @json) + ")")
    ' <<<"$store")
  else
    body=$(jq -r '
      ((.disabled // [])[] | "unbind = " + (. | sub(" \\+ (?<k>[A-Z0-9_]+)$"; ", \(.k)") | sub(" \\+ "; " "; "g"))),
      ((.added // [])[] | "bindd = " + (.keys | sub(" \\+ (?<k>.+)$"; ", \(.k)") | sub(" \\+ "; " "; "g")) + ", " + .description + ", exec, " + .command)
    ' <<<"$store")
  fi

  backup_once "$target"

  # The block is rewritten whole; everything outside it is copied through.
  # `awk -v` expands backslash escapes in the value it is given, which would
  # undo the escaping applied above. ENVIRON does not.
  omasettings_body="$body" awk -v begin_marker="$BINDINGS_BEGIN" -v end_marker="$BINDINGS_END" '
    BEGIN { inside = 0; seen = 0; body = ENVIRON["omasettings_body"] }
    # With nothing left to generate the block goes away entirely, rather
    # than leaving a pair of markers around nothing.
    $0 == begin_marker { inside = 1; seen = 1; if (body != "") { print; print body } next }
    $0 == end_marker { inside = 0; if (body != "") print; next }
    inside { next }
    { print }
    END {
      if (!seen && body != "") {
        print ""
        print begin_marker
        print body
        print end_marker
      }
    }
  ' "$target" | awk '
    # Hold blank lines back so removing the block does not leave a gap at the
    # end of the file.
    /^[[:space:]]*$/ { pending = pending $0 "\n"; next }
    { printf "%s", pending; pending = ""; print }
  ' | write_file "$target" managed

  hyprctl reload >/dev/null 2>&1 || true
}

edit_bindings() {
  local filter=$1
  shift
  local current next
  current=$(read_store)
  next=$(jq -c "$filter" "$@" <<<"$current") || die "failed to update $STORE"
  write_file "$STORE" managed <<<"$next" || die "failed to write $STORE"
  render_bindings
}

# Every binding Hyprland currently has, as Omarchy reads them, marked with
# where it came from so the window can offer the right action.
bindings_state() {
  local listed store
  listed=$(capture omarchy-menu-keybindings --print \
    | sed -E 's/[[:space:]]+→[[:space:]]+/\t/' \
    | jq -R -s -c 'split("\n")
      | map(select(length > 0) | split("\t")
        | { keys: (.[0] | gsub("^\\s+|\\s+$"; "")), description: ((.[1] // "") | gsub("^\\s+|\\s+$"; "")) })')
  store=$(bindings_store)

  # Omarchy prints "SUPER SHIFT + R" while the config spells it
  # "SUPER + SHIFT + R"; both are the same binding, so both are canonicalised
  # before anything is compared.
  jq -cn --argjson listed "${listed:-[]}" --argjson store "$store" '
    def canonical: ascii_upcase | gsub("\\+"; " ") | gsub("\\s+"; " ")
      | sub("^ "; "") | sub(" $"; "") | split(" ") | join(" + ");

    ($store.added // []) as $added
    | ($store.disabled // []) as $disabled
    | ($added | map({ key: (.keys | canonical), value: . }) | from_entries) as $mine
    | [$listed[]
        | (.keys | canonical) as $key
        | { keys: .keys,
            canonical: $key,
            description: (if $mine[$key] then $mine[$key].description else .description end),
            command: (if $mine[$key] then $mine[$key].command else "" end),
            source: (if $mine[$key] then "yours" else "omarchy" end) }] as $live
    | ($live | map(.canonical)) as $liveKeys
    | { added: $added,
        disabled: $disabled,
        items: ($live
                # A key that was turned off is not in the live list any more,
                # so it is listed from the store instead — otherwise turning
                # something off would make it vanish with no way back.
                + [$disabled[]
                    | (. | canonical) as $key
                    | select(($mine[$key] | not) and ($liveKeys | index($key) | not))
                    | { keys: ., canonical: $key, description: "Turned off",
                        command: "", source: "disabled" }]
                # A binding added here shows up even before Hyprland has
                # reloaded, so adding one never looks like it did nothing.
                + [$added[]
                    | (.keys | canonical) as $key
                    | select($liveKeys | index($key) | not)
                    | { keys: .keys, canonical: $key, description: .description,
                        command: .command, source: "yours" }]) }'
}

keys_cmd() {
  bindings_migrate
  local action=${1:-} keys=${2:-} description=${3:-} command=${4:-}
  case $action in
    list) bindings_state ;;
    add)
      keys=$(keys_normalise "$keys")
      [[ -n $keys ]] || die "no key combination given"
      [[ -n $command ]] || die "no command given"
      [[ -n $description ]] || description="Custom"
      # Adding over an existing binding has to unbind it first, or Hyprland
      # keeps the one it already had.
      edit_bindings '
        .bindings = ((.bindings // {added: [], disabled: []})
          | .added = (((.added // []) | map(select(.keys != $keys))) + [{keys: $keys, description: $description, command: $command}])
          | .disabled = (((.disabled // []) + [$keys]) | unique))' \
        --arg keys "$keys" --arg description "$description" --arg command "$command" ;;
    remove)
      keys=$(keys_normalise "$keys")
      edit_bindings '
        .bindings = ((.bindings // {added: [], disabled: []})
          | .added = ((.added // []) | map(select(.keys != $keys)))
          | .disabled = ((.disabled // []) | map(select(. != $keys))))' \
        --arg keys "$keys" ;;
    disable)
      keys=$(keys_normalise "$keys")
      [[ -n $keys ]] || die "no key combination given"
      edit_bindings '
        .bindings = ((.bindings // {added: [], disabled: []})
          | .disabled = (((.disabled // []) + [$keys]) | unique))' \
        --arg keys "$keys" ;;
    *) die "unknown keys action '$action'" ;;
  esac
}
