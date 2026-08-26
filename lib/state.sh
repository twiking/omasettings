# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------------- state

nightlight_enabled() {
  local status
  status=$(capture omarchy-toggle-nightlight --status)
  [[ -n $status ]] && jq -r '.enabled' <<<"$status" 2>/dev/null && return
  echo false
}

state() {
  local cfg themes fonts theme font nightlight hypr hyprchanged searchindex monitors compose plugins pluginupdates selfupdate agents groups iconfonts datetime herdr textscale
  cfg=$(read_shell_json)
  # omarchy-theme-list finds every directory under the theme folders, dotted
  # ones included, so anything a stray tool left behind there shows up as a
  # theme. A theme is never hidden; drop those.
  themes=$(capture omarchy-theme-list | grep -v '^\.' | lines_to_array)
  fonts=$(capture omarchy font list | lines_to_array)
  theme=$(capture omarchy-theme-current | head -n1)
  font=$(capture omarchy font current | head -n1)
  nightlight=$(nightlight_enabled)
  hypr=$(hypr_state)
  # Not keywords, so they ride along with the ones that are: the window asks
  # for them the same way and does not have to know the difference.
  hypr=$(jq -c --argjson speed "$(extras_get animation-speed 1)" \
    --argjson opaque "$(extras_get opaque-windows false)" \
    '. + { "animation-speed": $speed, "opaque-windows": $opaque }' <<<"$hypr")
  # One list for the window: a setting is changed whether it is a Hyprland key
  # we override or a value we wrote into Omarchy's own config.
  # Everything this window has a hand in: the Hyprland keys it overrides, the
  # values it wrote into other people's config, and the per-device overrides,
  # which are their own kind of override again.
  hyprchanged=$(jq -c -s 'add' <(hypr_changed) <(written_changed) <(devices_changed) <(extras_changed))

  monitors=$(monitor_state 2>/dev/null || echo '[]')
  compose=$(compose_entries)
  plugins=$(plugins_state)
  pluginupdates=$(plugin_updates_cache)
  selfupdate=$(self_update_state)
  agents=$(agents_state)
  groups=$(jq -cn \
    --argjson browser "$(menu_group_state "setup.default.browser")" \
    --argjson terminal "$(menu_group_state "setup.default.terminal")" \
    --argjson editor "$(menu_group_state "setup.default.editor")" \
    --argjson dns "$(menu_group_state "setup.network.dns")" \
    '{ browser: $browser, terminal: $terminal, editor: $editor, dns: $dns }')
  iconfonts=$(icon_font_state)
  datetime=$(datetime_state)
  herdr=$(herdr_state)
  tmuxstate=$(tmux_state)
  nvimstate=$(nvim_state)
  bindings=$(bindings_state)
  devices=$(devices_state)
  wifi=$(wifi_state)
  bluetooth=$(bluetooth_state)
  power=$(power_state)
  audio=$(audio_state)
  textscale=$(capture omarchy display text size | grep -oE '[0-9]+(\.[0-9]+)?' | head -n1)
  # What a search can find. The section sources give the settings each page
  # declares; the rest of the state gives the things a page is a list of —
  # this keyboard, that network, your bindings — which no source can know.
  searchindex=$(jq -c -s '.[0] * .[1]' <(search_index) <(jq -cn \
    --argjson bt "${bluetooth:-{\}}" \
    --argjson wifi "${wifi:-{\}}" \
    --argjson audio "${audio:-{\}}" \
    --argjson bindings "${bindings:-{\}}" \
    --argjson plugins "${plugins:-[]}" \
    --argjson monitors "${monitors:-[]}" '''
    def entries(list; groupName; labelKey; descKey):
      [ list[]? | { group: groupName,
                    label: (.[labelKey] // "" | tostring),
                    description: (.[descKey] // "" | tostring) }
        | select(.label != "") ];
    { bluetooth: entries($bt.devices; "Devices"; "name"; "address"),
      network: entries($wifi.networks; "Networks"; "ssid"; "security"),
      audio: (entries($audio.outputs; "Output"; "description"; "name")
              + entries($audio.inputs; "Input"; "description"; "name")),
      bindings: entries($bindings.items; "Keybindings"; "keys"; "description"),
      plugins: entries($plugins; "Plugins"; "name"; "id"),
      displays: entries($monitors; "Displays"; "name"; "name") }'''))

  jq -cn \
    --argjson cfg "$cfg" \
    --argjson themes "${themes:-[]}" \
    --argjson fonts "${fonts:-[]}" \
    --arg theme "$theme" \
    --arg font "$font" \
    --argjson nightlight "${nightlight:-false}" \
    --argjson hypr "${hypr:-{\}}" \
    --argjson hyprChanged "${hyprchanged:-[]}" \
    --argjson searchIndex "${searchindex:-{\}}" \
    --argjson monitors "${monitors:-[]}" \
    --argjson compose "${compose:-[]}" \
    --argjson plugins "${plugins:-[]}" \
    --argjson pluginUpdates "${pluginupdates:-{\}}" \
    --argjson selfUpdate "${selfupdate:-{\}}" \
    --argjson agents "${agents:-null}" \
    --argjson iconFonts "${iconfonts:-{\}}" \
    --argjson datetime "${datetime:-{\}}" \
    --argjson groups "${groups:-{\}}" \
    --argjson herdr "${herdr:-{\}}" \
    --argjson tmux "${tmuxstate:-{\}}" \
    --argjson nvim "${nvimstate:-{\}}" \
    --argjson bindings "${bindings:-{\}}" \
    --argjson devices "${devices:-{\}}" \
    --argjson wifi "${wifi:-{\}}" \
    --argjson bluetooth "${bluetooth:-{\}}" \
    --argjson power "${power:-{\}}" \
    --argjson audio "${audio:-{\}}" \
    --arg textScale "${textscale:-1}" \
    '{
      theme: $theme,
      themes: $themes,
      font: $font,
      fonts: $fonts,
      nightlight: $nightlight,
      textScale: (($textScale | tonumber?) // 1),
      bar: {
        position: (($cfg.bar.position // "top") | tostring),
        transparent: (($cfg.bar.transparent // false) == true),
        centerAnchor: (($cfg.bar.centerAnchor // "") | tostring),
        # Just the ids, in bar order: the window pairs them with the plugin
        # list for names, and per-widget settings stay in shell.json where
        # only the widget itself cares about them.
        layout: {
          left: [($cfg.bar.layout.left // [])[] | .id],
          center: [($cfg.bar.layout.center // [])[] | .id],
          right: [($cfg.bar.layout.right // [])[] | .id]
        }
      },
      idle: {
        screensaver: (($cfg.idle.screensaver // 150) | tonumber? // 150),
        lock: (($cfg.idle.lock // 300) | tonumber? // 300)
      },
      hypr: $hypr,
      # The settings this window has written, so a page can say which of its
      # values were chosen here rather than supplied by the system.
      hyprChanged: $hyprChanged,
      searchIndex: $searchIndex,
      monitors: $monitors,
      compose: $compose,
      plugins: $plugins,
      pluginUpdates: $pluginUpdates,
      selfUpdate: $selfUpdate,
      agents: $agents,
      groups: $groups,
      datetime: $datetime,
      herdr: $herdr,
      tmux: $tmux,
      nvim: $nvim,
      bindings: $bindings,
      devices: $devices,
      wifi: $wifi,
      bluetooth: $bluetooth,
      power: $power,
      audio: $audio,
      iconFonts: $iconFonts
    }'
}
