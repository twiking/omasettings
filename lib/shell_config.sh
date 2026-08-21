# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------- shell.json

read_shell_json() {
  [[ -f $SHELL_JSON ]] && jq -c . "$SHELL_JSON" 2>/dev/null && return
  echo '{}'
}

edit_shell_json() {
  local filter=$1
  shift
  local next
  next=$(jq "$filter" "$@" <<<"$(read_shell_json)") || die "failed to update $SHELL_JSON"
  write_file "$SHELL_JSON" <<<"$next" || die "failed to write $SHELL_JSON"
}
