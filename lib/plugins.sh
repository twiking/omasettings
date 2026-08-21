# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ----------------------------------------------------------------- plugins

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
