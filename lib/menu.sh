# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ----------------------------------------------------------------- agents

# The Omarchy menu's own definition is the source of truth for which agents
# exist and what picking one runs, so the Agents section mirrors it rather
# than keeping a second list that can drift. Both files are JSONC.
MENU_DEFAULTS="${OMARCHY_PATH:-/usr/share/omarchy}/default/omarchy/omarchy-menu.jsonc"
MENU_USER="$HOME_DIR/.config/omarchy/extensions/omarchy-menu.jsonc"

read -r -d '' JSONC_TO_JSON <<'AWK'
# Strip JSONC comments and trailing commas without disturbing string content.
# A character scan is the only honest way to do it: "https://…" inside a string
# is not a comment, and a comma before a closing brace is not a separator.
# The scan runs per line, and each line is rebuilt in a small buffer — walking
# the whole file as one string makes the concatenation quadratic.
function flush(line) {
  if (held != "") print held
  held = line
}
BEGIN { inStr = 0; inBlock = 0; held = "" }
{
  out = ""; n = length($0); esc = 0
  for (i = 1; i <= n; i++) {
    c = substr($0, i, 1)
    if (inBlock) {
      if (c == "*" && substr($0, i + 1, 1) == "/") { inBlock = 0; i++ }
      continue
    }
    if (inStr) {
      out = out c
      if (esc) esc = 0
      else if (c == "\\") esc = 1
      else if (c == "\"") inStr = 0
      continue
    }
    if (c == "\"") { inStr = 1; out = out c; continue }
    if (c == "/" && substr($0, i + 1, 1) == "/") break
    if (c == "/" && substr($0, i + 1, 1) == "*") { inBlock = 1; i++; continue }
    # A closer on this same line settles any comma still pending before it.
    if (c == "}" || c == "]") sub(/,[ \t\r]*$/, "", out)
    out = out c
  }

  # A comma is only a trailing comma once the next meaningful character turns
  # out to be a closing brace or bracket, which can be on a later line — so
  # one line is held back until the next one says.
  first = out
  sub(/^[ \t\r]+/, "", first)
  if (first ~ /^[}\]]/) sub(/,[ \t\r]*$/, "", held)
  flush(out)
}
END { if (held != "") print held }
AWK

jsonc_to_json() {
  [[ -f $1 ]] || { echo '{}'; return; }
  read_file "$1" | awk "$JSONC_TO_JSON" 2>/dev/null | jq -c . 2>/dev/null || echo '{}'
}

# User extensions override defaults under the same id, the way the menu itself
# merges them.
# Parsed once per process. A state read asks for five groups — browser,
# terminal, editor, DNS, agents — and each one was re-reading and re-merging
# both menu files: the definition cannot change underneath a single read, and
# four fifths of that work bought nothing. It was the largest single cost in
# a state read, and every button in the window pays for a state read.
MENU_ENTRIES_CACHE=""

menu_entries() {
  [[ -n $MENU_ENTRIES_CACHE ]] && { printf '%s\n' "$MENU_ENTRIES_CACHE"; return; }
  MENU_ENTRIES_CACHE=$(jq -c -s '.[0] * .[1]' \
    <(jsonc_to_json "$MENU_DEFAULTS") <(jsonc_to_json "$MENU_USER") 2>/dev/null) || MENU_ENTRIES_CACHE=""
  [[ -n $MENU_ENTRIES_CACHE ]] || MENU_ENTRIES_CACHE='{}'
  printf '%s\n' "$MENU_ENTRIES_CACHE"
}

# Every direct child of a menu id, in menu order: the entries OmaSettings
# renders as a pick-one group.
menu_group() {
  local prefix=$1
  menu_entries | jq -c --arg prefix "$prefix" '[to_entries[]
    | select(.key | startswith($prefix + ".") and (.[($prefix | length) + 1:] | contains(".") | not))
    | { id: (.key | split(".") | last),
        entry: .key,
        label: (.value.label // (.key | split(".") | last)),
        icon: (.value.icon // ""),
        iconFont: (.value.iconFont // ""),
        action: (.value.action // ""),
        check: (.value.checked // "") }]'
}

agent_entries() { menu_group "setup.default.agent"; }

# Each entry carries a bash expression saying whether it is the current choice.
# They all run in one shell rather than one process per entry: a settings
# window that takes a second to open is a settings window nobody opens.
evaluate_checks() {
  local entries=$1 script
  script=$(jq -r '.[] | select(.check != "") | "if " + .check + "; then echo \"" + .id + "\ttrue\"; else echo \"" + .id + "\tfalse\"; fi"' <<<"$entries")
  [[ -n $script ]] || { echo '{}'; return; }
  bash -c "$script" 2>/dev/null | jq -R -s -c 'split("\n")
    | map(select(length > 0) | split("\t") | { key: .[0], value: (.[1] == "true") })
    | from_entries'
}

# A group as the window wants it: the entries plus which one is current.
menu_group_state() {
  local entries checked
  entries=$(menu_group "$1")
  checked=$(evaluate_checks "$entries")
  jq -cn --argjson entries "$entries" --argjson checked "${checked:-{\}}" \
    '{ items: [$entries[] | . + { checked: (($checked[.id]) // false) }] }
     | . + { current: ((.items[] | select(.checked) | .id) // "") }'
}

agents_state() {
  local state current
  state=$(menu_group_state "setup.default.agent")
  # The agent group's own checked tests already say which is current; the
  # command is asked only as a fallback for a menu without them.
  current=$(jq -r '.current' <<<"$state")
  [[ -n $current && $current != "" ]] || current=$(capture omarchy-default-agent | head -n1)
  jq -c --arg current "$current" '.current = $current' <<<"$state"
}

# Run a menu entry's action exactly as the menu would. Picking an agent that
# is not installed, changing the timezone, or setting a DNS provider opens a
# terminal or a picker of its own, so this must outlive the settings window:
# detach it.
menu_run() {
  local id=$1 command
  command=$(menu_entries | jq -r --arg id "$id" '.[$id].action // ""')
  [[ -n $command ]] || die "menu entry '$id' has no action"
  setsid bash -lc "$command" >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

# What the Date & Time section shows next to those two actions.
datetime_state() {
  local zone ntp synced now
  zone=$(capture timedatectl show -p Timezone --value)
  ntp=$(capture timedatectl show -p NTP --value)
  synced=$(capture timedatectl show -p NTPSynchronized --value)
  now=$(date '+%Y-%m-%d %H:%M %Z' 2>/dev/null)

  jq -cn --arg zone "$zone" --arg now "$now" \
    --argjson ntp "$([[ $ntp == yes ]] && echo true || echo false)" \
    --argjson synced "$([[ $synced == yes ]] && echo true || echo false)" \
    '{ timezone: $zone, now: $now, ntp: $ntp, synchronized: $synced }'
}

agents_cmd() {
  local action=${1:-} id=${2:-}
  case $action in
    list) agents_state ;;
    run)
      [[ -n $id ]] || die "no agent given"
      agent_entries | jq -e --arg id "$id" 'any(.[]; .id == $id)' >/dev/null \
        || die "unknown agent '$id'"
      menu_run "setup.default.agent.$id" ;;
    *) die "unknown agents action '$action'" ;;
  esac
}

# Menu entries can name a custom icon font ("omarchy"), and asking Qt for that
# family by name is not enough: an old user-installed omarchy.ttf carrying a
# single glyph shadows the complete system one, and the icons come out blank —
# which is exactly what happens in the Omarchy menu itself when that copy is
# present. Resolve the file instead, picking whichever copy actually carries
# the glyphs the entries use, and hand the window a path to load directly.
icon_font_file() {
    local family=$1
    shift
    local needed=("$@") file best="" best_score=-1 charset score

    while read -r file; do
      [[ -n $file ]] || continue
      charset=$(capture fc-query -f '%{charset}' "$file")
      score=$(COVER_CHARSET="$charset" awk -v want="${needed[*]}" '
        BEGIN {
          n = split(ENVIRON["COVER_CHARSET"], tokens, /[ \t\n]+/)
          for (t = 1; t <= n; t++) {
            if (tokens[t] ~ /-/) {
              split(tokens[t], range, "-")
              lo = strtonum("0x" range[1]); hi = strtonum("0x" range[2])
            } else if (tokens[t] != "") {
              lo = hi = strtonum("0x" tokens[t])
            } else continue
            for (c = lo; c <= hi; c++) have[c] = 1
          }
          w = split(want, wanted, / /)
          for (i = 1; i <= w; i++)
            if (wanted[i] != "" && have[strtonum("0x" wanted[i])]) covered++
          print covered + 0
        }')
      if ((score > best_score)); then
        best_score=$score
        best=$file
      fi
    done < <(capture fc-list ":family=$family" file | sed 's/: *$//')

    [[ $best_score -gt 0 ]] && echo "$best"
}

# The codepoints the current agent entries actually need, so the check follows
# the menu rather than a list of glyphs frozen in here.
icon_font_state() {
  local codepoints path
  codepoints=$(agent_entries | jq -r '.[] | select(.iconFont == "omarchy") | .icon' \
    | while read -r glyph; do
        [[ -n $glyph ]] && printf '%x\n' "'$glyph"
      done)
  # No custom-font entries means nothing to resolve.
  [[ -n $codepoints ]] || { echo '{}'; return; }
  # shellcheck disable=SC2086
  path=$(icon_font_file omarchy $codepoints)
  jq -cn --arg path "${path:-}" '{ omarchy: $path }'
}

# ------------------------------------------------------------------ search
#
# What settings exist on a page the window has not opened yet. Only the open
# page is instantiated — that is what keeps the window cheap — so the index is
# read from the section sources instead, which is also what keeps it honest:
# a setting added to a page is in the index the moment it is written, with no
# second list to remember to update.
#
# A label built from data rather than written in the source — a device name, a
# plugin name — cannot be indexed this way and is not searchable.
search_index() {
  local dir="$OMASETTINGS_DIR"
  [[ -d $dir/sections ]] || { echo '{}'; return; }

  # Which file is which page, taken from the window's own routing rather than
  # a copy of it.
  local pages
  pages=$(sed -n 's/.*case "\([a-z.]*\)": return "sections\/\([A-Za-z]*\.qml\)".*/\1\t\2/p' \
    "$dir/SettingsWindow.qml" 2>/dev/null)
  [[ -n $pages ]] || { echo '{}'; return; }

  while IFS=$'\t' read -r page file; do
    [[ -n $page && -f $dir/sections/$file ]] || continue
    awk -v page="$page" '
      # A group heading gives a row context a search can match on: "blur" finds
      # the settings under Blur even when the word is not in their own labels.
      /^[ \t]*title: "/ {
        line = $0
        sub(/^[ \t]*title: "/, "", line)
        sub(/".*$/, "", line)
        group = line
        next
      }
      /^[ \t]*label: "/ {
        if (label != "") print page "\t" group "\t" label "\t" desc
        line = $0
        sub(/^[ \t]*label: "/, "", line)
        sub(/".*$/, "", line)
        label = line
        desc = ""
        next
      }
      /^[ \t]*description: "/ {
        if (label == "" || desc != "") next
        line = $0
        sub(/^[ \t]*description: "/, "", line)
        sub(/".*$/, "", line)
        desc = line
      }
      END { if (label != "") print page "\t" group "\t" label "\t" desc }
    ' "$dir/sections/$file"
  done <<<"$pages" | jq -R -s -c '
    [ split("\n")[] | select(length > 0) | split("\t")
      | { page: .[0], group: .[1], label: .[2], description: .[3] } ]
    | group_by(.page)
    | map({ key: .[0].page, value: map({ group, label, description }) })
    | from_entries'
}
