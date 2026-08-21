# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ---------------------------------------------------------------- our store

read_store() {
  [[ -f $STORE ]] && jq -c . "$STORE" 2>/dev/null && return
  echo '{}'
}

# jq-edit the store, then re-render the generated Hyprland config from it.
edit_store() {
  local filter=$1
  shift
  local current next
  current=$(read_store)
  next=$(jq -c "$filter" "$@" <<<"$current") || die "failed to update $STORE"
  write_file "$STORE" managed <<<"$next" || die "failed to write $STORE"
  render_managed
}

store_get() { jq -r --arg k "$1" '.hypr[$k] // empty' <<<"$(read_store)"; }
