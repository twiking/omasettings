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

# ---------------------------------------------------- addressing an entry
#
# A widget is normally named by its id, which is unique — except for the ones
# whose manifest says `allowMultiple`, the spacer among them. Those have no
# identity of their own at all: two spacers in a section are the same object
# twice, and the bar tells them apart by nothing but where they sit. So the
# edits a spacer needs are addressed by section and place in it, and the id is
# carried alongside only to be checked, so a page working from a list read a
# moment ago cannot resize the widget that has since moved into that slot.
bar_check_section() {
  case $1 in
    left | center | right) ;;
    *) die "expected left, center or right" ;;
  esac
}

bar_entry_id_at() {
  local section=$1 index=$2
  read_shell_json | jq -r --arg s "$section" --argjson i "$index" \
    '((.bar.layout[$s] // [])[$i] // {}) | .id // ""' 2>/dev/null
}

# Every positional edit starts here, so none of them can act on a slot that is
# not there or no longer holds what the caller thought it did.
bar_check_at() {
  local section=$1 index=$2 want=${3:-} found
  bar_check_section "$section"
  [[ $index =~ ^[0-9]+$ ]] || die "'$index' is not a place in the bar"
  found=$(bar_entry_id_at "$section" "$index")
  [[ -n $found ]] || die "there is no widget $index places into $section"
  [[ -z $want || $found == "$want" ]] ||
    die "$section $index holds '$found', not '$want'"
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

# The same two moves as above, addressed by place rather than by id, which is
# the only way to say which of several identical widgets is meant. The object
# moves whole here too.
bar_move_at() {
  local section=$1 index=$2 target=$3 id=${4:-}
  bar_check_at "$section" "$index" "$id"
  bar_check_section "$target"
  [[ $section == "$target" ]] && return 0

  edit_shell_json --arg s "$section" --argjson i "$index" --arg t "$target" '
    .bar.layout[$s][$i] as $widget
    | .bar.layout[$s] = (.bar.layout[$s] | del(.[$i]))
    | .bar.layout[$t] = ((.bar.layout[$t] // []) + [$widget])'
}

bar_shift_at() {
  local section=$1 index=$2 direction=$3 id=${4:-}
  bar_check_at "$section" "$index" "$id"
  case $direction in
    up | down) ;;
    *) die "expected up or down" ;;
  esac

  edit_shell_json --arg s "$section" --argjson i "$index" --arg d "$direction" '
    (.bar.layout[$s] // []) as $list
    | ($i + (if $d == "up" then -1 else 1 end)) as $to
    | if $to < 0 or $to >= ($list | length) then .
      else .bar.layout[$s] = ($list | .[$i] as $moved | .[$to] as $displaced
                                    | .[$i] = $displaced | .[$to] = $moved)
      end'
}

# ------------------------------------------------------------- the spacer
#
# Blank space is the one bar widget you add rather than own: its manifest says
# `allowMultiple`, so there is no list of spacers you have and none to enable
# — there is only how many you have put in the bar and how wide each is. That
# is why it is added and removed here rather than enabled and disabled, and
# why it is kept out of the Disabled group: nothing is waiting there to come
# back.
BAR_SPACER_ID="omarchy.spacer"
BAR_SPACER_DEFAULT=12
BAR_SPACER_MAX=400

bar_spacer_size_valid() {
  [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 0 && $1 <= BAR_SPACER_MAX ))
}

bar_spacer_add() {
  # Passed through empty by the router when the caller said nothing, which is
  # not the same as unset.
  local section=$1 size=${2:-}
  [[ -n $size ]] || size=$BAR_SPACER_DEFAULT
  bar_check_section "$section"
  bar_spacer_size_valid "$size" || die "'$size' is not a width in pixels"

  edit_shell_json --arg s "$section" --arg id "$BAR_SPACER_ID" --argjson size "$size" '
    .bar //= {}
    | .bar.layout //= {}
    | .bar.layout[$s] = ((.bar.layout[$s] // []) + [{ id: $id, size: $size }])'
}

# A widget's settings are its layout entry, every key of it except `id` — so
# the width is written beside the id and not under a `settings` key of its
# own. Nested, it arrives at the widget as `settings.settings.size`, which is
# not a number it can read: it falls back to its default and the width silently
# does nothing, at every value, which is exactly how that looks from outside.
#
# This is the one bar edit that changes an object rather than moving one.
bar_spacer_size() {
  local section=$1 index=$2 size=$3
  bar_check_at "$section" "$index" "$BAR_SPACER_ID"
  bar_spacer_size_valid "$size" || die "'$size' is not a width in pixels"

  edit_shell_json --arg s "$section" --argjson i "$index" --argjson size "$size" '
    .bar.layout[$s][$i].size = $size'
}

# Removal is deletion, with nothing kept: a spacer has no settings worth
# remembering beyond the width, and no identity to put back. Only a spacer can
# be removed this way — for anything else, taking it out of the bar is
# `bar disable`, which keeps the widget's settings and its place.
bar_spacer_remove() {
  local section=$1 index=$2
  bar_check_at "$section" "$index" "$BAR_SPACER_ID"

  edit_shell_json --arg s "$section" --argjson i "$index" '
    .bar.layout[$s] = ((.bar.layout[$s] // []) | del(.[$i]))'
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
    # The positional forms. The id is optional and only checked, so a stale
    # list cannot move the widget that has taken that place since.
    move-at) bar_move_at "${1:-}" "${2:-}" "${3:-}" "${4:-}" ;;
    shift-at) bar_shift_at "${1:-}" "${2:-}" "${3:-}" "${4:-}" ;;
    spacer)
      case ${1:-} in
        add) bar_spacer_add "${2:-}" "${3:-}" ;;
        size) bar_spacer_size "${2:-}" "${3:-}" "${4:-}" ;;
        remove) bar_spacer_remove "${2:-}" "${3:-}" ;;
        *) die "unknown spacer action '${1:-}'" ;;
      esac ;;
    enable) bar_enable "${1:-}" ;;
    disable) bar_disable "${1:-}" ;;
    hidden) bar_hidden ;;
    *) die "unknown bar action '$action'" ;;
  esac
}
