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

bar_cmd() {
  local action=${1:-}
  shift || true
  case $action in
    move) bar_move "${1:-}" "${2:-}" ;;
    shift) bar_shift "${1:-}" "${2:-}" ;;
    *) die "unknown bar action '$action'" ;;
  esac
}
