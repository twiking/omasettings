# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------- shell.json

read_shell_json() {
  [[ -f $SHELL_JSON ]] && read_file "$SHELL_JSON" | jq -c . 2>/dev/null && return
  echo '{}'
}

edit_shell_json() {
  local filter=$1
  shift
  local next
  next=$(jq "$filter" "$@" <<<"$(read_shell_json)") || die "failed to update $SHELL_JSON"
  write_file "$SHELL_JSON" <<<"$next" || die "failed to write $SHELL_JSON"
}

# ------------------------------------------------------------- bar layout
#
# A bar widget lives in one of three sections, in a definite order, and carries
# its own settings in the same object. Every edit here moves that object whole:
# rebuilding it from the id alone would quietly drop the widget's settings.

BAR_SECTIONS='["left","center","right"]'

bar_widget_section() {
  local id=$1
  # Inside the map, . is the section name, so the document has to be held
  # onto separately to look the section up in it.
  read_shell_json | jq -r --arg id "$id" --argjson sections "$BAR_SECTIONS" '
    . as $doc
    | ($sections | map(select((($doc.bar.layout[.]) // []) | any(.id == $id))) | first) // ""' 2>/dev/null
}

# Move a widget to another section, at the end of it.
bar_move() {
  local id=$1 target=$2
  [[ -n $id ]] || die "no widget id given"
  case $target in
    left | center | right) ;;
    *) die "expected left, center or right" ;;
  esac
  [[ -n $(bar_widget_section "$id") ]] || die "'$id' is not in the bar"

  edit_shell_json --arg id "$id" --arg target "$target" '
    .bar //= {}
    | .bar.layout //= {}
    | ([(.bar.layout.left // []), (.bar.layout.center // []), (.bar.layout.right // [])]
       | flatten | map(select(.id == $id)) | first) as $widget
    | .bar.layout.left = ((.bar.layout.left // []) | map(select(.id != $id)))
    | .bar.layout.center = ((.bar.layout.center // []) | map(select(.id != $id)))
    | .bar.layout.right = ((.bar.layout.right // []) | map(select(.id != $id)))
    | .bar.layout[$target] = ((.bar.layout[$target] // []) + [$widget])'
}

# Move a widget one place within its own section. Asking to go past either end
# is a no-op rather than an error: the button is simply at the end of its run.
bar_shift() {
  local id=$1 direction=$2
  [[ -n $id ]] || die "no widget id given"
  case $direction in
    up | down) ;;
    *) die "expected up or down" ;;
  esac

  local section
  section=$(bar_widget_section "$id")
  [[ -n $section ]] || die "'$id' is not in the bar"

  edit_shell_json --arg id "$id" --arg section "$section" --arg direction "$direction" '
    .bar //= {}
    | .bar.layout //= {}
    | (.bar.layout[$section] // []) as $list
    | ($list | map(.id) | index($id)) as $from
    | ($from + (if $direction == "up" then -1 else 1 end)) as $to
    | if $from == null or $to < 0 or $to >= ($list | length) then .
      else .bar.layout[$section] = ($list | .[$from] as $moved | .[$to] as $displaced
                                          | .[$from] = $displaced | .[$to] = $moved)
      end'
}

# --------------------------------------------------------- turning one off
#
# A widget is in the bar or it is not: the layout is the whole of its enabled
# state, and Omarchy's own `plugin disable` says so by removing the entry.
#
# It is not used here, though, and this is the reason: it removes the entry and
# nothing else, so the widget's own settings go with it. Omatop came back from
# a disable/enable round trip without its `showValues`, and Spotify would come
# back without its account, its playlists and its session. `plugin enable` also
# appends, so a widget switched off and on again walks to the end of its
# section.
#
# So the object is kept — whole, the way every other edit here moves it —
# along with where it was, and putting the widget back is putting that object
# back in its place.
bar_hidden() {
  jq -c '.barHidden // {}' <<<"$(read_store)"
}

bar_disable() {
  local id=$1 section index widget
  [[ -n $id ]] || die "no widget id given"

  section=$(bar_widget_section "$id")
  [[ -n $section ]] || return 0

  index=$(read_shell_json | jq -r --arg id "$id" --arg s "$section" \
    '(.bar.layout[$s] // []) | map(.id) | index($id)')
  widget=$(read_shell_json | jq -c --arg id "$id" --arg s "$section" \
    '(.bar.layout[$s] // []) | map(select(.id == $id)) | first')

  edit_store '.barHidden = ((.barHidden // {}) | .[$id] = { section: $s, index: ($i | tonumber), widget: $w })' \
    --arg id "$id" --arg s "$section" --arg i "$index" --argjson w "$widget"

  edit_shell_json --arg id "$id" '
    .bar //= {}
    | .bar.layout //= {}
    | .bar.layout |= with_entries(
        if (.value | type) == "array" then .value |= map(select(.id != $id)) else . end)'
}

bar_enable() {
  local id=$1 stash
  [[ -n $id ]] || die "no widget id given"

  # Already there — put back by hand, or by Omarchy — so what this remembered
  # about where it used to sit is no longer about anything.
  if [[ -n $(bar_widget_section "$id") ]]; then
    jq -e --arg id "$id" '(.barHidden // {}) | has($id)' <<<"$(read_store)" >/dev/null \
      && edit_store 'if .barHidden then .barHidden |= del(.[$id]) else . end' --arg id "$id"
    return 0
  fi

  stash=$(bar_hidden | jq -c --arg id "$id" 'if has($id) then .[$id] else empty end')

  # A widget this window never switched off has no place to go back to, so the
  # question of where it belongs is Omarchy's to answer, not ours to invent.
  if [[ -z $stash ]]; then
    capture omarchy plugin enable "$id" >/dev/null 2>&1 \
      || die "could not enable '$id'"
    return 0
  fi

  edit_shell_json --argjson stash "$stash" '
    .bar //= {}
    | .bar.layout //= {}
    | ($stash.section) as $s
    | (.bar.layout[$s] // []) as $list
    # Its old place, unless the section has since grown shorter than it.
    | ([$stash.index, ($list | length)] | min) as $at
    | .bar.layout[$s] = ($list[0:$at] + [$stash.widget] + $list[$at:])'

  edit_store 'if .barHidden then .barHidden |= del(.[$id]) else . end' --arg id "$id"
}

bar_cmd() {
  local action=${1:-}
  shift || true
  case $action in
    move) bar_move "${1:-}" "${2:-}" ;;
    shift) bar_shift "${1:-}" "${2:-}" ;;
    enable) bar_enable "${1:-}" ;;
    disable) bar_disable "${1:-}" ;;
    hidden) bar_hidden ;;
    *) die "unknown bar action '$action'" ;;
  esac
}
