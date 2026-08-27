# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ----------------------------------------------------------------- plugins

# An update check is a network round trip per plugin, so its answer outlives
# the sweep: the page shows the last verdict the moment it opens instead of a
# blank list waiting to be re-checked. It is derived data, re-earnable at any
# time by checking again, so it lives in the cache rather than next to the
# settings the user actually chose.
OMASETTINGS_FETCH_TIMEOUT="${OMASETTINGS_FETCH_TIMEOUT:-30}"
UPDATE_CACHE="${OMASETTINGS_UPDATE_CACHE:-${XDG_CACHE_HOME:-$HOME_DIR/.cache}/omarchy/omasettings/plugin-updates.json}"

# The cache path is as predictable as any other, and it is read straight into
# the window, so it is read the same bounded, descriptor-checked way as
# anything else we did not write this second.
plugin_updates_cache() {
  read_file "$UPDATE_CACHE" \
    | jq -c --argjson now "$(date +%s)" '
        { checkedAt: (.checkedAt // 0),
          results: (.results // {}),
          changes: (.changes // {}),
          # An update detached from this window can be killed with the shell
          # it was started from, and would then spin forever. A marker older
          # than the longest plausible update is not an update in flight.
          running: ((.running // {}) | with_entries(select(.value > $now - 600))),
          last: (.last // {}) }' 2>/dev/null && return
  echo '{"checkedAt":0,"results":{},"changes":{},"running":{},"last":{}}'
}

# Same for putting it back: a fresh random sibling, renamed into place, so a
# name planted at the cache path is replaced rather than written through.
write_update_cache() {
  local tmp
  mkdir -p "$(dirname "$UPDATE_CACHE")" || return 1
  tmp=$(mktemp "$UPDATE_CACHE.XXXXXX") || return 1
  cat >"$tmp" || { rm -f "$tmp"; return 1; }
  [[ -s $tmp ]] || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$UPDATE_CACHE"
}

plugins_state() {
  capture omarchy plugin list --json | jq -c '[.[] | {
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
    PLUGINS_DIR="$dir" FETCH_TIMEOUT="$OMASETTINGS_FETCH_TIMEOUT" xargs -r -P 6 -I{} bash -c '
      id=$1
      repo="$PLUGINS_DIR/$id"
      if [[ ! -d $repo/.git ]]; then
        printf "%s\t-1\n" "$id"
      elif GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}" \
           timeout "${FETCH_TIMEOUT:-30}" git -C "$repo" fetch -q origin HEAD 2>/dev/null; then
        # The bounds are spelled out rather than shared: this runs in a bash
        # xargs started, which never sourced anything of ours.
        # Double quotes on purpose: this whole worker is a single-quoted
        # string, so a single quote here ends it and the script stops parsing.
        #
        # The subjects come off the FETCH_HEAD the count was just taken from,
        # so saying what is coming costs no second round trip. They stand in
        # for the diff the terminal used to print: enough to decide with,
        # short enough to sit on a row.
        printf "%s\t%s\t%s\n" "$id" \
          "$(timeout 10 git -C "$repo" rev-list --count HEAD..FETCH_HEAD 2>/dev/null | head -c 32 || echo 0)" \
          "$(timeout 10 git -C "$repo" log --format=%s -n 3 HEAD..FETCH_HEAD 2>/dev/null \
             | tr "\t|" "  " | paste -s -d "|" - | head -c 300)"
      else
        printf "%s\t-2\n" "$id"
      fi' _ {}
  } | tee "$out"

  # What an update said about itself outlives a sweep: the sweep is about the
  # counts, and rebuilding the whole document would throw away the answer the
  # page is still showing.
  jq -Rn --argjson at "$(date +%s)" --argjson prev "$(plugin_updates_cache)" '
    [inputs | split("\t") | select(length >= 2)] as $rows
    | { checkedAt: $at,
        results: ([$rows[] | { key: .[0], value: (.[1] | tonumber) }] | from_entries),
        changes: ([$rows[] | select((.[2] // "") != "") | { key: .[0], value: .[2] }] | from_entries),
        running: ($prev.running // {}),
        last: ($prev.last // {}) }' \
    <"$out" 2>/dev/null | write_update_cache
  rm -f "$out"
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
    behind=$(capture git -C "$repo" rev-list --count HEAD..FETCH_HEAD || echo 0)
  else
    behind=-2
  fi

  jq -c --arg id "$id" --argjson behind "${behind:-0}" --argjson at "$(date +%s)" \
    '.checkedAt = $at | .results = ((.results // {}) | .[$id] = $behind)' \
    <<<"$(plugin_updates_cache)" 2>/dev/null | write_update_cache

  self_update_state
}

# ---------------------------------------------------------- applying one
#
# `omarchy-plugin-update <id> --yes` is entirely non-interactive: the diff and
# the gum confirm it prints are the *unattended* half of the flow, skipped by
# --yes. Only the asking needed a terminal, and this window has already asked
# — the row says how many commits are coming and what they say.
#
# It does not run as a child of the window, though. Its last act is
# `omarchy-shell shell rescanPlugins`, which unloads and reloads every
# plugin's QML — this window included. A child of the window would be killed
# part-way through its own `git merge`, and the answer would die with the
# window that asked. So the work is detached, and it says what it did in the
# cache the page already reads: whoever is looking when it lands sees it, and
# so does the window that comes back afterwards.
plugin_update_start() {
  local id=$1

  jq -c --arg id "$id" --argjson at "$(date +%s)" \
    '.running = ((.running // {}) | .[$id] = $at) | .last = ((.last // {}) | del(.[$id]))' \
    <<<"$(plugin_updates_cache)" 2>/dev/null | write_update_cache

  setsid bash "$OMASETTINGS_BIN" plugin update-run "$id" >/dev/null 2>&1 &
  disown 2>/dev/null || true

  # The window wants the spinner now, not at the next poll.
  plugin_updates_cache
}

plugin_update_run() {
  local id=$1 out rc msg
  out=$(omarchy-plugin-update "$id" --yes 2>&1)
  rc=$?

  # Upstream's own last line is the message worth showing: "Updated x.",
  # "x is up to date.", or why it refused.
  msg=$(printf '%s' "$out" | grep -v '^[[:space:]]*$' | tail -n 1 | head -c 400)
  if [[ -z $msg ]]; then
    (( rc == 0 )) && msg="Updated." || msg="Update failed."
  fi

  # A successful update makes the recorded count a lie; the cheapest honest
  # answer is zero, which is what a fresh check would find anyway.
  jq -c --arg id "$id" --argjson ok "$(( rc == 0 ? 1 : 0 ))" --arg msg "$msg" \
     --argjson at "$(date +%s)" '
       .running = ((.running // {}) | del(.[$id]))
       | .last = ((.last // {}) | .[$id] = { ok: ($ok == 1), message: $msg, at: $at })
       | if $ok == 1 then
           .results = ((.results // {}) | .[$id] = 0)
           | .changes = ((.changes // {}) | del(.[$id]))
         else . end' \
    <<<"$(plugin_updates_cache)" 2>/dev/null | write_update_cache
}
