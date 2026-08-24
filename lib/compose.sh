# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------- .XCompose

# One JSON object per sequence: the keys as written, and the string produced.
compose_entries() {
  [[ -f $XCOMPOSE ]] || { echo '[]'; return; }
  read_file "$XCOMPOSE" | grep -E '^[[:space:]]*<[^#]*:' \
    | jq -Rn '[inputs
        | capture("^\\s*(?<keys>(<[^>]+>\\s*)+)\\s*:\\s*\"(?<text>([^\"\\\\]|\\\\.)*)\"(\\s*(?<name>\\S+))?\\s*$")
        | { keys: (.keys | gsub("\\s+$"; "")), text: .text, name: (.name // "") }]' 2>/dev/null \
    || echo '[]'
}

compose_add() {
  local keys=$1 text=$2
  [[ -n $keys && -n $text ]] || die "compose add needs both a key sequence and a result"
  [[ $keys == *"<"* ]] || die "key sequence must look like '<Multi_key> <a> <b>'"

  # A file that does not include the system rules yet needs the include line
  # first, or adding one sequence silently drops every default one.
  if [[ ! -f $XCOMPOSE ]]; then
    write_file "$XCOMPOSE" <<<'include "%L"'
  elif ! read_file "$XCOMPOSE" | grep -q '^include '; then
    backup_once "$XCOMPOSE"
    printf 'include "%%L"\n%s' "$(read_file "$XCOMPOSE")" | write_file "$XCOMPOSE"
  fi

  compose_remove "$keys" quiet
  ensure_regular_file "$XCOMPOSE" || die "$XCOMPOSE is not a file this can write"
  backup_once "$XCOMPOSE" || die "could not back up $XCOMPOSE"
  printf '%s : "%s"\n' "$keys" "$text" >>"$XCOMPOSE"
}

compose_remove() {
  local keys=$1 quiet=${2:-}
  [[ -f $XCOMPOSE ]] || return 0
  local escaped
  escaped=$(sed 's/[][\.*^$/]/\\&/g' <<<"$keys")
  read_file "$XCOMPOSE" | grep -qE "^[[:space:]]*$escaped[[:space:]]*:" || { [[ -n $quiet ]] && return 0; return 0; }
  backup_once "$XCOMPOSE"
  read_file "$XCOMPOSE" | grep -vE "^[[:space:]]*$escaped[[:space:]]*:" | write_file "$XCOMPOSE"
}
