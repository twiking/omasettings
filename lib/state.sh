# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------------- state

nightlight_enabled() {
  local status
  status=$(omarchy-toggle-nightlight --status 2>/dev/null)
  [[ -n $status ]] && jq -r '.enabled' <<<"$status" 2>/dev/null && return
  echo false
}

state() {
  local cfg themes fonts theme font nightlight hypr hyprchanged monitors compose plugins pluginupdates selfupdate agents groups iconfonts datetime herdr textscale
  cfg=$(read_shell_json)
  # omarchy-theme-list finds every directory under the theme folders, dotted
  # ones included, so anything a stray tool left behind there shows up as a
  # theme. A theme is never hidden; drop those.
  themes=$(omarchy-theme-list 2>/dev/null | grep -v '^\.' | lines_to_array)
  fonts=$(omarchy font list 2>/dev/null | lines_to_array)
  theme=$(omarchy-theme-current 2>/dev/null | head -n1)
  font=$(omarchy font current 2>/dev/null | head -n1)
  nightlight=$(nightlight_enabled)
  hypr=$(hypr_state)
  # One list for the window: a setting is changed whether it is a Hyprland key
  # we override or a value we wrote into Omarchy's own config.
  hyprchanged=$(jq -c -s 'add' <(hypr_changed) <(written_changed))
  monitors=$(hyprctl -j monitors 2>/dev/null | jq -c '[.[] | {name, scale, width, height, refreshRate: (.refreshRate | floor), transform}]' 2>/dev/null || echo '[]')
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
  textscale=$(omarchy display text size 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?' | head -n1)

  jq -cn \
    --argjson cfg "$cfg" \
    --argjson themes "${themes:-[]}" \
    --argjson fonts "${fonts:-[]}" \
    --arg theme "$theme" \
    --arg font "$font" \
    --argjson nightlight "${nightlight:-false}" \
    --argjson hypr "${hypr:-{\}}" \
    --argjson hyprChanged "${hyprchanged:-[]}" \
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
