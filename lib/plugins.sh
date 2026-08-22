# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ----------------------------------------------------------------- plugins

# An update check is a network round trip per plugin, so its answer outlives
# the sweep: the page shows the last verdict the moment it opens instead of a
# blank list waiting to be re-checked. It is derived data, re-earnable at any
# time by checking again, so it lives in the cache rather than next to the
# settings the user actually chose.
UPDATE_CACHE="${OMASETTINGS_UPDATE_CACHE:-${XDG_CACHE_HOME:-$HOME_DIR/.cache}/omarchy/omasettings/plugin-updates.json}"

plugin_updates_cache() {
  [[ -f $UPDATE_CACHE ]] && jq -c '{ checkedAt: (.checkedAt // 0), results: (.results // {}) }' "$UPDATE_CACHE" 2>/dev/null && return
  echo '{"checkedAt":0,"results":{}}'
}

plugins_state() {
  omarchy plugin list --json 2>/dev/null | jq -c '[.[] | {
    id: .id,
    name: (.name // .id),
    kinds: (.kinds // []),
    enabled: (.enabled == true),
    firstParty: (.firstParty // .isFirstParty // false),
    description: (.description // "")
  }]' 2>/dev/null || echo '[]'
}

# Whether each installed plugin has commits waiting upstream. One line per
# plugin, printed the moment that plugin's own fetch settles rather than at
# the end, so the window can retire one spinner at a time. The count is the
# payload; -1 means the plugin is not a git checkout and -2 that the fetch
# failed (no network, private remote, gone).
plugin_updates() {
  local dir="$HOME_DIR/.config/omarchy/plugins"
  [[ -d $dir ]] || return 0

  # The comparison is omarchy-plugin-update's own, on purpose: it fetches
  # origin HEAD — the remote's default branch, not the local branch's
  # upstream — and fast-forwards onto it. Counting anything else here would
  # promise an update the Update button then refuses to make. A plugin parked
  # on a non-default branch is therefore measured against the default one,
  # upstream's limitation and ours alike.
  #
  # The fetches are network-bound and independent, so they run together —
  # sequentially this takes a second per plugin and feels broken.
  local out
  out=$(mktemp) || return 1

  # The verdicts stream out as they land and are kept at the same time; the
  # window wants them one by one, the next window wants them all at once.
  { find -L "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort |
    PLUGINS_DIR="$dir" xargs -r -P 6 -I{} bash -c '
      id=$1
      repo="$PLUGINS_DIR/$id"
      if [[ ! -d $repo/.git ]]; then
        printf "%s\t-1\n" "$id"
      elif GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}" \
           git -C "$repo" fetch -q origin HEAD 2>/dev/null; then
        printf "%s\t%s\n" "$id" "$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null || echo 0)"
      else
        printf "%s\t-2\n" "$id"
      fi' _ {}
  } | tee "$out"

  mkdir -p "$(dirname "$UPDATE_CACHE")"
  jq -Rn --argjson at "$(date +%s)" '
    { checkedAt: $at,
      results: ([inputs | split("\t") | select(length == 2) | { key: .[0], value: (.[1] | tonumber) }] | from_entries) }' \
    <"$out" >"$UPDATE_CACHE.tmp" 2>/dev/null && mv "$UPDATE_CACHE.tmp" "$UPDATE_CACHE"
  rm -f "$out" "$UPDATE_CACHE.tmp"
}

# ------------------------------------------------------- our own update
#
# The window is itself a plugin, and a plugin that is behind says so in its
# own corner rather than waiting to be noticed on the Plugins page. The id
# comes from the manifest beside this code, so a fork or a clone reports on
# itself rather than on whoever it was forked from.
OMASETTINGS_DIR="${OMASETTINGS_DIR:-$(cd "$OMASETTINGS_LIB/.." 2>/dev/null && pwd)}"

self_id() {
  jq -r '.id // empty' "$OMASETTINGS_DIR/manifest.json" 2>/dev/null
}

# What the last sweep — the Plugins page, or self_check below — learned about
# us. Reading the cache costs nothing, so the corner can be drawn immediately
# and corrected once the check behind it lands.
self_update_state() {
  local id
  id=$(self_id)
  [[ -n $id ]] || { echo '{"behind":0,"checkedAt":0}'; return; }

  plugin_updates_cache | jq -c --arg id "$id" '
    { id: $id, behind: ((.results[$id] // 0)), checkedAt: (.checkedAt // 0) }'
}

# One fetch, ours only, folded into the same cache the Plugins page reads.
# The window runs it in the background on open: it is a network round trip,
# and nothing should wait on it.
self_check() {
  local id repo behind
  id=$(self_id)
  [[ -n $id ]] || return 0
  repo="$HOME_DIR/.config/omarchy/plugins/$id"
  [[ -d $repo/.git ]] || { self_update_state; return 0; }

  if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}" \
     git -C "$repo" fetch -q origin HEAD 2>/dev/null; then
    behind=$(git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null || echo 0)
  else
    behind=-2
  fi

  mkdir -p "$(dirname "$UPDATE_CACHE")"
  jq -c --arg id "$id" --argjson behind "${behind:-0}" --argjson at "$(date +%s)" \
    '.checkedAt = $at | .results = ((.results // {}) | .[$id] = $behind)' \
    <<<"$(plugin_updates_cache)" >"$UPDATE_CACHE.tmp" 2>/dev/null \
    && mv "$UPDATE_CACHE.tmp" "$UPDATE_CACHE"
  rm -f "$UPDATE_CACHE.tmp"

  self_update_state
}
