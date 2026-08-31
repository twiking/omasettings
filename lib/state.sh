# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ------------------------------------------------------------------- state

nightlight_enabled() {
  local status
  status=$(capture omarchy-toggle-nightlight --status)
  [[ -n $status ]] && jq -r '.enabled' <<<"$status" 2>/dev/null && return
  echo false
}

# The handful of answers that are a pipeline rather than a single call. They
# are functions so they can be handed to par_run whole, arguments and all.
#
# omarchy-theme-list finds every directory under the theme folders, dotted ones
# included, so anything a stray tool left behind there shows up as a theme. A
# theme is never hidden; drop those.
state_themes() { capture omarchy-theme-list | grep -v '^\.' | lines_to_array; }
state_fonts() { capture omarchy font list | lines_to_array; }
state_theme() { capture omarchy-theme-current | head -n1; }
state_font() { capture omarchy font current | head -n1; }
state_textscale() { capture omarchy display text size | grep -oE '[0-9]+(\.[0-9]+)?' | head -n1; }
state_monitors() { monitor_state 2>/dev/null || echo '[]'; }

# Speed and full opacity are not keywords, so they ride along with the ones
# that are: the window asks for them the same way and does not have to know
# the difference.
state_hypr() {
  jq -c --argjson speed "$(extras_get animation-speed 1)" \
    --argjson opaque "$(extras_get opaque-windows false)" \
    '. + { "animation-speed": $speed, "opaque-windows": $opaque }' <<<"$(hypr_state)"
}

# Everything this window has a hand in: the Hyprland keys it overrides, the
# values it wrote into other people's config, and the per-device overrides,
# which are their own kind of override again.
state_changed() {
  jq -c -s 'add' <(hypr_changed) <(written_changed) <(devices_changed) <(extras_changed)
}

# Each group asks the system which of its entries is current, by running the
# check each entry carries — so the four of them together were the longest
# thing in a state read, and asking them one after another inside a single
# producer made that the critical path. They are four questions, so they are
# four producers.

# What the Bar page reads, as one expression, because it is read two ways: as
# part of the whole document, and alone when a bar edit needs nothing else
# re-read. Written out twice it would drift, and the page would show one shape
# or the other depending on which read answered last.
BAR_STATE_JQ='{
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
  },
  # The one exception, and only because the page has to show it: a
  # spacer is nothing but its width, so a row cannot describe itself
  # without it. Null for every other widget, and in step with the ids
  # above, since a spacer is named by its place rather than by an id.
  # The settings of a widget are the keys of its layout entry beside the
  # id, so the width is read from there and not from a nested object.
  # (No apostrophes in here: this whole filter is one single-quoted
  # string, and one would end it.)
  sizes: {
    left: [($cfg.bar.layout.left // [])[] | if .id == "omarchy.spacer" then ((.size // 12) | tonumber? // 12) else null end],
    center: [($cfg.bar.layout.center // [])[] | if .id == "omarchy.spacer" then ((.size // 12) | tonumber? // 12) else null end],
    right: [($cfg.bar.layout.right // [])[] | if .id == "omarchy.spacer" then ((.size // 12) | tonumber? // 12) else null end]
  }
}'

# A scoped read. The window answers a click with one of these: a bar edit
# waits on shell.json and nothing else, where the whole document waits on
# bluetoothctl, the battery daemon and the default-browser check — none of
# which the page being refreshed shows.
#
# It is a fast path and never the only one: whatever asks for a slice asks for
# the whole document a moment behind it, so a page that names too few slices
# updates late rather than showing something untrue.
# A scoped read: the same producers as the whole document, but only the ones
# named. The window answers a click with one of these — a bar edit waits on
# shell.json alone, a tmux edit on the tmux server, where the whole document
# waits on bluetoothctl, the battery daemon and the default-browser check no
# matter which page asked.
#
# Every name here is a key of the document, and every value comes from the
# same producer the full read uses, so a slice cannot say something the whole
# read would not.
#
# It is a fast path and never the only one: whatever asks for slices asks for
# the whole document a moment behind them, so a caller that names too few
# leaves the window a moment late rather than wrong.
state_slice() {
  local name=${1:-}
  case $name in
    # Straight from shell.json, and the only two that need no producer at all.
    bar) jq -cn --argjson cfg "$(read_shell_json)" "{ bar: $BAR_STATE_JQ }" ;;
    idle) jq -cn --argjson cfg "$(read_shell_json)" \
      '{ idle: { screensaver: (($cfg.idle.screensaver // 150) | tonumber? // 150),
                 lock: (($cfg.idle.lock // 300) | tonumber? // 300) } }' ;;

    # Words rather than documents, so they are quoted as words.
    theme) jq -cn --arg v "$(state_theme)" '{ theme: $v }' ;;
    font) jq -cn --arg v "$(state_font)" '{ font: $v }' ;;
    textScale) jq -cn --arg v "$(state_textscale)" '{ textScale: (($v | tonumber?) // 1) }' ;;

    themes) jq -cn --argjson v "$(state_themes)" '{ themes: $v }' ;;
    fonts) jq -cn --argjson v "$(state_fonts)" '{ fonts: $v }' ;;
    nightlight) jq -cn --argjson v "$(nightlight_enabled)" '{ nightlight: $v }' ;;

    hypr) jq -cn --argjson v "$(state_hypr)" '{ hypr: $v }' ;;
    hyprChanged) jq -cn --argjson v "$(state_changed)" '{ hyprChanged: $v }' ;;
    monitors) jq -cn --argjson v "$(state_monitors)" '{ monitors: $v }' ;;
    compose) jq -cn --argjson v "$(compose_entries)" '{ compose: $v }' ;;
    plugins) jq -cn --argjson v "$(plugins_state)" '{ plugins: $v }' ;;
    pluginUpdates) jq -cn --argjson v "$(plugin_updates_cache)" '{ pluginUpdates: $v }' ;;
    selfUpdate) jq -cn --argjson v "$(self_update_state)" '{ selfUpdate: $v }' ;;
    agents) jq -cn --argjson v "$(agents_state)" '{ agents: $v }' ;;
    iconFonts) jq -cn --argjson v "$(icon_font_state)" '{ iconFonts: $v }' ;;
    datetime) jq -cn --argjson v "$(datetime_state)" '{ datetime: $v }' ;;
    herdr) jq -cn --argjson v "$(herdr_state)" '{ herdr: $v }' ;;
    tmux) jq -cn --argjson v "$(tmux_state)" '{ tmux: $v }' ;;
    nvim) jq -cn --argjson v "$(nvim_state)" '{ nvim: $v }' ;;
    bindings) jq -cn --argjson v "$(bindings_state)" '{ bindings: $v }' ;;
    devices) jq -cn --argjson v "$(devices_state)" '{ devices: $v }' ;;
    wifi) jq -cn --argjson v "$(wifi_state)" '{ wifi: $v }' ;;
    bluetooth) jq -cn --argjson v "$(bluetooth_state)" '{ bluetooth: $v }' ;;
    power) jq -cn --argjson v "$(power_state)" '{ power: $v }' ;;
    audio) jq -cn --argjson v "$(audio_state)" '{ audio: $v }' ;;
    groups) jq -cn \
      --argjson browser "$(menu_group_state setup.default.browser)" \
      --argjson terminal "$(menu_group_state setup.default.terminal)" \
      --argjson editor "$(menu_group_state setup.default.editor)" \
      --argjson dns "$(menu_group_state setup.network.dns)" \
      '{ groups: { browser: $browser, terminal: $terminal, editor: $editor, dns: $dns } }' ;;

    # searchIndex is deliberately absent: half of it is the rest of the
    # document, so it is only ever as fresh as a whole read.
    *) die "unknown state slice '$name'" ;;
  esac
}

# Asked together, like the whole document is, since two slices are two
# independent questions as much as two producers are.
state_slices() {
  local name out
  par_begin
  for name in "$@"; do
    par_run "$name" state_slice "$name"
  done
  par_wait

  # An answer is expected from every name asked for. A producer runs in the
  # background, where its own `die` can only end the subshell it is in, so a
  # name that is not a slice — or one whose producer failed — would otherwise
  # be reported as success with that key quietly missing, which is exactly the
  # shape of bug a fast path must not have.
  out='{}'
  local answer
  for name in "$@"; do
    answer=$(par_get "$name" '')
    [[ -n $answer ]] || { par_end; die "state slice '$name' answered nothing"; }
    out=$(jq -c -s '.[0] * .[1]' <(printf '%s' "$out") <(printf '%s' "$answer")) \
      || { par_end; return 1; }
  done
  par_end
  printf '%s\n' "$out"
}

state() {
  # Named slices answer on their own; with nothing named, the whole document.
  if (( $# > 0 )); then state_slices "$@"; return; fi

  local cfg themes fonts theme font nightlight hypr hyprchanged searchindex monitors compose plugins pluginupdates selfupdate agents groups iconfonts datetime herdr textscale
  cfg=$(read_shell_json)

  # Before the block, both of them: this is the one part of a state read that
  # writes, and the menu cache is filled here so that every producer inherits
  # it rather than each subshell parsing the menu again and losing it.
  heal_managed_lua
  menu_entries >/dev/null

  par_begin
  par_run themes state_themes
  par_run fonts state_fonts
  par_run theme state_theme
  par_run font state_font
  par_run textscale state_textscale
  par_run nightlight nightlight_enabled
  par_run hypr state_hypr
  par_run hyprchanged state_changed
  par_run monitors state_monitors
  par_run compose compose_entries
  par_run plugins plugins_state
  par_run pluginupdates plugin_updates_cache
  par_run selfupdate self_update_state
  par_run agents agents_state
  par_run browser menu_group_state setup.default.browser
  par_run terminal menu_group_state setup.default.terminal
  par_run editor menu_group_state setup.default.editor
  par_run dns menu_group_state setup.network.dns
  par_run iconfonts icon_font_state
  par_run datetime datetime_state
  par_run herdr herdr_state
  par_run tmuxstate tmux_state
  par_run nvimstate nvim_state
  par_run bindings bindings_state
  par_run devices devices_state
  par_run wifi wifi_state
  par_run bluetooth bluetooth_state
  par_run power power_state
  par_run audio audio_state
  # The half of the search index that comes from the section sources. The
  # other half is the state itself, and is put together once it is all in.
  par_run searchsources search_index
  par_wait

  themes=$(par_get themes '[]')
  fonts=$(par_get fonts '[]')
  theme=$(par_get theme)
  font=$(par_get font)
  textscale=$(par_get textscale)
  nightlight=$(par_get nightlight false)
  hypr=$(par_get hypr '{}')
  hyprchanged=$(par_get hyprchanged '[]')
  monitors=$(par_get monitors '[]')
  compose=$(par_get compose '[]')
  plugins=$(par_get plugins '[]')
  pluginupdates=$(par_get pluginupdates '{}')
  selfupdate=$(par_get selfupdate '{}')
  agents=$(par_get agents null)
  groups=$(jq -cn \
    --argjson browser "$(par_get browser '{}')" \
    --argjson terminal "$(par_get terminal '{}')" \
    --argjson editor "$(par_get editor '{}')" \
    --argjson dns "$(par_get dns '{}')" \
    '{ browser: $browser, terminal: $terminal, editor: $editor, dns: $dns }')
  iconfonts=$(par_get iconfonts '{}')
  datetime=$(par_get datetime '{}')
  herdr=$(par_get herdr '{}')
  tmuxstate=$(par_get tmuxstate '{}')
  nvimstate=$(par_get nvimstate '{}')
  bindings=$(par_get bindings '{}')
  devices=$(par_get devices '{}')
  wifi=$(par_get wifi '{}')
  bluetooth=$(par_get bluetooth '{}')
  power=$(par_get power '{}')
  audio=$(par_get audio '{}')
  local searchsources
  searchsources=$(par_get searchsources '{}')
  par_end
  # What a search can find. The section sources give the settings each page
  # declares; the rest of the state gives the things a page is a list of —
  # this keyboard, that network, your bindings — which no source can know.
  searchindex=$(jq -c -s '.[0] * .[1]' <(printf '%s' "$searchsources") <(jq -cn \
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
      bar: '"$BAR_STATE_JQ"',
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
