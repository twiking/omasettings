import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ui" as Ui

// OmaSettings — one window for the settings that otherwise live scattered
// across ~/.config/omarchy/shell.json, the Hyprland config in ~/.config/hypr,
// and ~/.XCompose.
//
// The window never parses or rewrites those files itself. It reads one JSON
// document from bin/omasettings and sends every change back as a `set` call;
// that script owns hyprctl, the omarchy commands, the generated Lua, and the
// one-time backup taken before any hand-written file is touched.
Item {
  id: root

  // ---------------- window lifecycle ---------------------------------------
  readonly property bool shown: window.visible

  // While the search box is being typed into it owns the keyboard, the same
  // way an open dropdown or a field being edited does.
  readonly property bool searchFocused: searchField.activeFocus

  // Which screen the window was opened on. Hyprland knows which one has the
  // focus; Quickshell knows the screens by name, and the two are matched here.
  property var openedOn: null

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    if (name === "") return null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (String(screens[i].name) === name) return screens[i]
    return null
  }

  function show() {
    openedOn = focusedScreen()
    window.visible = true
    refresh()
    if (!selfCheckProcess.running) selfCheckProcess.running = true
  }
  function hide() { window.visible = false }
  function close() { hide() }

  // ---------------- palette ------------------------------------------------
  // Settings tracks the foundational palette rather than a themable surface of
  // its own, so it renders consistently under every theme.
  readonly property color foreground: Ui.Palette.foreground
  // Popup surfaces are allowed to be translucent; a window full of text is
  // not, so the same colour is taken at full opacity.
  readonly property color background: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
  readonly property color accent: Color.accent
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property color hairline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)
  readonly property string fontFamily: Style.font.family

  readonly property string helperPath: String(Qt.resolvedUrl("bin/omasettings")).replace(/^file:\/\//, "")

  // ---------------- state --------------------------------------------------
  property var state: ({})
  property bool loaded: false
  property bool busy: false
  property string lastError: ""

  readonly property var hypr: state.hypr !== undefined ? state.hypr : ({})
  readonly property var barState: state.bar !== undefined ? state.bar : ({})
  readonly property var idleState: state.idle !== undefined ? state.idle : ({})
  readonly property var monitors: state.monitors !== undefined ? state.monitors : []
  readonly property var composeEntries: state.compose !== undefined ? state.compose : []
  readonly property var plugins: state.plugins !== undefined ? state.plugins : []
  readonly property var agentsState: state.agents !== undefined ? state.agents : ({})
  readonly property var datetime: state.datetime !== undefined ? state.datetime : ({})
  readonly property var groups: state.groups !== undefined ? state.groups : ({})

  // Mute and volume are the server's, not this window's: the media keys, the
  // bar widget and any other panel move them too. While the Audio page is up,
  // PulseAudio's event stream is followed directly so the switches and sliders
  // track what is actually happening rather than what was true at last read.
  property var audioLive: null
  readonly property var audio: audioLive !== null ? audioLive
    : (state.audio !== undefined ? state.audio : ({}))

  Process {
    id: audioWatchProcess
    command: ["bash", root.helperPath, "audio", "watch"]
    running: root.shown && root.pageId === "audio"
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        try {
          var next = JSON.parse(line)
          if (next && typeof next === "object") root.audioLive = next
        } catch (e) {
          // A half-written line is not worth acting on; the next event
          // brings the whole state again.
        }
      }
    }
    // A stale live reading is worse than none: the page falls back to the
    // state document once nothing is watching.
    onRunningChanged: if (!running) root.audioLive = null
  }

  // Input devices. Each page lists its own, one group per device, so the
  // Keyboard and Mouse pages never have to say which device a control means.
  readonly property var devices: state.devices !== undefined ? state.devices : ({})

  function setDevice(name, key, value, kind) {
    run(["devices", "set", name, key, String(value), kind])
  }

  function clearDevice(name) { run(["devices", "clear", name]) }

  // Removes everything for a device, including an hl.device the user wrote
  // themselves — that one is commented out rather than deleted.
  function removeDevice(name) { run(["devices", "remove", name]) }

  // The profile is moved by the bar's power plugin, the menu and the daemon
  // itself, and the battery reading changes on its own. While the Power page
  // is up, those events are followed directly rather than waited for.
  property var powerLive: null
  readonly property var power: powerLive !== null ? powerLive
    : (state.power !== undefined ? state.power : ({}))

  Process {
    id: powerWatchProcess
    command: ["bash", root.helperPath, "power", "watch"]
    running: root.shown && root.pageId === "power"
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        try {
          var next = JSON.parse(line)
          if (next && typeof next === "object") root.powerLive = next
        } catch (e) {
          // A half-written line is not worth acting on; the next event
          // brings the whole state again.
        }
      }
    }
    onRunningChanged: if (!running) root.powerLive = null
  }

  // Like Wi-Fi: the Bluetooth page keeps its own list current while it is on
  // screen, without re-reading the whole state to do it.
  property var bluetoothLive: null
  readonly property var bluetooth: bluetoothLive !== null ? bluetoothLive
    : (state.bluetooth !== undefined ? state.bluetooth : ({}))

  function pollBluetooth() {
    if (bluetoothPollProcess.running) return
    bluetoothPollProcess.command = ["bash", root.helperPath, "bluetooth", "poll"]
    bluetoothPollProcess.running = true
  }

  Process {
    id: bluetoothPollProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var next = JSON.parse(text)
          if (next && typeof next === "object") root.bluetoothLive = next
        } catch (e) {
          // A failed poll leaves the last good list on screen.
        }
      }
    }
  }

  // What the switch says underneath itself: the devices in hand, or why there
  // are none.
  readonly property string bluetoothSummary: {
    if (bluetooth.available === false) return "No Bluetooth adapter"
    if (bluetooth.powered !== true) return "Off"
    var devices = bluetooth.devices !== undefined ? bluetooth.devices : []
    var names = []
    for (var i = 0; i < devices.length; i++)
      if (devices[i].connected) names.push(devices[i].name !== "" ? devices[i].name : devices[i].address)
    return names.length === 0 ? "Nothing connected" : "Connected to " + names.join(", ")
  }

  // While the Network page is open it polls Wi-Fi on its own, far more often
  // than the whole state is worth re-reading. That poll's answer stands in
  // for the Wi-Fi part of the state until the next full read replaces it.
  property var wifiLive: null
  readonly property var wifi: wifiLive !== null ? wifiLive
    : (state.wifi !== undefined ? state.wifi : ({}))

  function pollWifi() {
    if (wifiPollProcess.running) return
    wifiPollProcess.command = ["bash", root.helperPath, "wifi", "poll"]
    wifiPollProcess.running = true
  }

  Process {
    id: wifiPollProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var next = JSON.parse(text)
          if (next && typeof next === "object") root.wifiLive = next
        } catch (e) {
          // A failed poll leaves the last good list on screen.
        }
      }
    }
  }
  readonly property var wifiNetworks: wifi.networks !== undefined ? wifi.networks : []
  readonly property var wifiConnection: wifi.connection !== undefined ? wifi.connection : ({})
  readonly property var wifiBand: wifi.band !== undefined ? wifi.band : ({})

  // Automatic plus whichever bands this radio and access point actually
  // offer, so a 2.4-only network never shows a 5 GHz choice that cannot work.
  function bandOptions() {
    var out = [{ value: "auto", label: "Automatic" }]
    var available = wifiBand.available !== undefined ? wifiBand.available : []
    for (var i = 0; i < available.length; i++)
      out.push({ value: String(available[i]), label: String(available[i]) + " GHz" })
    return out
  }
  // The network whose password field is open, if any.
  property string wifiPrompting: ""

  function connectWifi(ssid, password) {
    wifiPrompting = ""
    if (password !== undefined && password !== "") {
      // The passphrase goes over stdin, never argv: anything on the command
      // line is readable by every process on the machine for as long as the
      // connection takes.
      root.busy = true
      wifiConnectProc.secret = password
      wifiConnectProc.command = ["bash", root.helperPath, "wifi", "connect", ssid, "--password-stdin"]
      wifiConnectProc.running = true
    } else {
      run(["wifi", "connect", ssid])
    }
  }

  Process {
    id: wifiConnectProc
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(secret + "\n")
      secret = ""
      stdinEnabled = false
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastError = text.trim()
    }
    onRunningChanged: if (!running) {
      root.busy = false
      settleTimer.restart()
    }
  }

  readonly property var bindings: state.bindings !== undefined ? state.bindings : ({})
  property string bindingFilter: ""

  // Matching on keys and description together is what people actually search
  // by: "super f" for the chord, "screenshot" for the thing it does.
  readonly property var visibleBindings: {
    var items = bindings.items !== undefined ? bindings.items : []
    var needle = bindingFilter.trim().toLowerCase()
    if (needle === "") return items
    var words = needle.split(/\s+/)
    var out = []
    for (var i = 0; i < items.length; i++) {
      var hay = (String(items[i].keys) + " " + String(items[i].description) + " " + String(items[i].command)).toLowerCase()
      var all = true
      for (var w = 0; w < words.length; w++)
        if (hay.indexOf(words[w]) === -1) { all = false; break }
      if (all) out.push(items[i])
    }
    return out
  }

  readonly property var herdr: state.herdr !== undefined ? state.herdr : ({})
  readonly property var herdrValues: herdr.values !== undefined ? herdr.values : ({})

  function herdrValue(key, fallback) {
    var value = herdrValues ? herdrValues[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function setHerdr(key, value) { run(["herdr", "set", key, String(value)]) }

  readonly property var tmux: state.tmux !== undefined ? state.tmux : ({})
  readonly property var tmuxValues: tmux.values !== undefined ? tmux.values : ({})

  function tmuxValue(key, fallback) {
    var value = tmuxValues ? tmuxValues[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function setTmux(key, value) { run(["tmux", "set", key, String(value)]) }

  readonly property var nvim: state.nvim !== undefined ? state.nvim : ({})
  readonly property var nvimValues: nvim.values !== undefined ? nvim.values : ({})

  function nvimValue(key, fallback) {
    var value = nvimValues ? nvimValues[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function setNvim(key, value) { run(["nvim", "set", key, String(value)]) }

  function editConfig(path) {
    editProcess.command = ["bash", "-lc", "omarchy-launch-config-editor \"" + path + "\""]
    editProcess.running = true
  }

  Process { id: editProcess }

  function group(name) {
    var g = groups ? groups[name] : undefined
    return g !== undefined && g !== null ? g : { items: [], current: "" }
  }

  function agentOptions() {
    var items = agentsState.items !== undefined ? agentsState.items : []
    var out = []
    for (var i = 0; i < items.length; i++)
      out.push({ value: String(items[i].id), label: String(items[i].label) })
    return out
  }

  // A menu group as dropdown options, labelled the way the menu labels them.
  function groupOptions(name) {
    var items = group(name).items || []
    var out = []
    for (var i = 0; i < items.length; i++)
      out.push({ value: String(items[i].id), label: String(items[i].label) })
    return out
  }

  // Menu entries can ask for Omarchy's own icon font. Asking Qt for the family
  // by name is not enough — a stale user-installed omarchy.ttf with a single
  // glyph shadows the complete system copy, and the icons come out blank — so
  // the helper resolves which file actually carries the glyphs and this loads
  // that file directly. Falling back to the family name keeps a system without
  // fontconfig from losing the icons entirely.
  readonly property string omarchyFontPath: state.iconFonts && state.iconFonts.omarchy
    ? String(state.iconFonts.omarchy) : ""
  readonly property string omarchyFontFamily: omarchyFontLoader.status === FontLoader.Ready
    && omarchyFontLoader.font.family !== "" ? omarchyFontLoader.font.family : "omarchy"

  FontLoader {
    id: omarchyFontLoader
    source: root.omarchyFontPath !== "" ? "file://" + root.omarchyFontPath : ""
  }

  // Which Hyprland settings this window has written, and the way to hand one
  // back. Anything not in this list is showing a value the system supplies,
  // which is not ours to reset.
  // Not "hyprChanged": the hypr property above already generates a signal of
  // that name, and the two would collide.
  readonly property var changedSettings: state.hyprChanged !== undefined ? state.hyprChanged : []
  function isChanged(key) { return changedSettings.indexOf(key) !== -1 }
  // Both families: a Hyprland key is dropped, anything else is written back
  // the way it was found. The helper knows which is which.
  function resetSetting(key) { run(["reset", key]) }

  // Whether this window is itself behind its remote. The cached answer draws
  // the corner at once; the check behind it corrects the cache a moment later.
  readonly property var selfUpdate: state.selfUpdate !== undefined ? state.selfUpdate : ({})
  readonly property int selfBehind: selfUpdate.behind !== undefined ? Number(selfUpdate.behind) : 0
  readonly property string selfId: selfUpdate.id !== undefined ? String(selfUpdate.id) : ""

  Process {
    id: selfCheckProcess
    command: ["bash", root.helperPath, "plugin", "self-check"]
    // Once per opening, and never on the path of anything the user is waiting
    // for: a fetch is a network round trip.
    running: false
    onRunningChanged: if (!running) Qt.callLater(function() { root.refresh() })
  }

  // ---------------- search --------------------------------------------------
  //
  // Only the open page exists, so what the other pages hold cannot be asked of
  // them. The index arrives with the state instead: what each page declares,
  // read from its source, plus the things a page is a list of — this keyboard,
  // that network, your bindings — which no source can know and only the
  // running system can say.
  property string searchQuery: ""
  readonly property var searchIndex: state.searchIndex !== undefined ? state.searchIndex : ({})
  readonly property string searchTerm: searchQuery.trim().toLowerCase()
  readonly property bool searching: searchTerm !== ""

  // Everything that names a setting counts, not just the setting: the heading
  // above it, the page it is on, and the heading that page sits under. So
  // "bluetooth" finds every setting on the Bluetooth page, none of which has
  // the word in its own name, and "blur" finds the eleven under Blur.
  function matchesTerm(label, description, group) {
    if (!searching) return true
    var hay = (String(label || "") + " " + String(description || "") + " " + String(group || "")).toLowerCase()
    return hay.indexOf(searchTerm) !== -1
  }

  // The menu names for a page: its own, and its parent's if it has one.
  function pageNames(pageId) {
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].id === pageId) return String(sections[i].title || "")
      var children = sections[i].children || []
      for (var c = 0; c < children.length; c++)
        if (children[c].id === pageId)
          return String(children[c].title || "") + " " + String(sections[i].title || "")
    }
    return ""
  }

  function matchesOnPage(pageId, label, description, group) {
    return matchesTerm(label, description, String(group || "") + " " + pageNames(pageId))
  }

  // Rows ask about themselves, and are always on the open page.
  function rowMatches(label, description, group) {
    return matchesOnPage(pageId, label, description, group)
  }

  // A page whose own name matches is a match, whatever its settings are
  // called — and some pages, the device lists especially, have no names in
  // their source to match at all.
  function pageTitleMatches(pageId) {
    if (!searching) return false
    return matchesTerm("", "", pageNames(pageId))
  }

  // A page for an application you do not have is a page of settings with
  // nowhere to go. The binary is the test, not its config file: an application
  // can be installed and never yet configured, and a config can outlive the
  // thing it configured.
  function pageAvailable(id) {
    switch (id) {
    case "apps.tmux": return state.tmux === undefined || state.tmux.installed !== false
    case "apps.nvim": return state.nvim === undefined || state.nvim.installed !== false
    case "apps.herdr": return state.herdr === undefined || state.herdr.installed !== false
    default: return true
    }
  }

  function pageMatchCount(pageId) {
    if (!pageAvailable(pageId)) return 0
    if (!searching) return 0
    var entries = searchIndex[pageId]
    if (!entries) return 0
    var n = 0
    for (var i = 0; i < entries.length; i++)
      if (matchesOnPage(pageId, entries[i].label, entries[i].description, entries[i].group)) n++
    return n
  }

  // A parent stands or falls with its children.
  function sectionMatchCount(section) {
    var children = section.children || []
    if (children.length === 0) return pageMatchCount(section.id)
    var n = 0
    for (var i = 0; i < children.length; i++) n += pageMatchCount(children[i].id)
    return n
  }

  // Whether a page belongs in the menu at all: something on it matched, or it
  // is itself what was searched for.
  // An application removed while its page is open leaves the window on a page
  // that is no longer there; step off it.
  onStateChanged: if (!pageAvailable(pageId)) pageId = "appearance"

  function sectionShows(section) {
    if (!searching) return true
    if (sectionMatchCount(section) > 0) return true
    if (pageTitleMatches(section.id)) return true
    var children = section.children || []
    for (var i = 0; i < children.length; i++)
      if (pageAvailable(children[i].id) && pageTitleMatches(children[i].id)) return true
    return false
  }

  function pageShows(pageId) {
    if (!pageAvailable(pageId)) return false
    return !searching || pageMatchCount(pageId) > 0 || pageTitleMatches(pageId)
  }

  // Searching onto a page with nothing on it would show an empty page; move to
  // the first page that has something instead.
  onSearchTermChanged: {
    if (!searching) return
    if (pageShows(pageId)) return
    // Walked from the sections rather than from sidebarRows: that list is a
    // binding on this very term, and read from inside the change it is still
    // the list for the term before, which lands you on a page that no longer
    // matches.
    for (var i = 0; i < sections.length; i++) {
      var children = sections[i].children || []
      if (children.length === 0) {
        if (pageShows(sections[i].id)) { pageId = sections[i].id; return }
        continue
      }
      for (var c = 0; c < children.length; c++)
        if (pageShows(children[c].id)) { pageId = children[c].id; return }
    }
  }

  // ---------------- keyboard navigation ------------------------------------
  //
  // One cursor runs down the settings of the open page, and a second one — the
  // sidebar — is reached with Alt. The vocabulary is the shell's own, the one
  // PanelKeyCatcher defines for every Omarchy panel: Up/Down or j/k to move,
  // Left/Right or h/l to change a value, Enter or Space to act, Tab to change
  // section, Escape to close.
  property var navRows: []
  property int navIndex: -1
  // Alt puts the cursor on the sidebar; moving in the page takes it back, so
  // Enter always acts on whichever list was last moved.
  property bool navInSidebar: false
  property int sidebarIndex: 0

  function registerNavRow(row) {
    var rows = navRows.slice()
    rows.push(row)
    navRows = rows
  }

  function unregisterNavRow(row) {
    var rows = []
    for (var i = 0; i < navRows.length; i++)
      if (navRows[i] !== row && navRows[i] !== null) rows.push(navRows[i])
    navRows = rows
    if (navIndex >= rows.length) navIndex = rows.length - 1
  }

  // Registration order follows construction, which is not reading order once a
  // page has groups that come and go. Sorting by where a row actually sits
  // keeps the cursor moving the way the page looks.
  function navOrdered() {
    var out = []
    for (var i = 0; i < navRows.length; i++) {
      var row = navRows[i]
      if (!row || !row.visible || !row.enabled) continue
      var point = row.mapToItem(bodyLoader, 0, 0)
      if (!point) continue
      out.push({ row: row, y: point.y })
    }
    out.sort(function(a, b) { return a.y - b.y })
    return out
  }

  function navCurrent() {
    var ordered = navOrdered()
    if (navIndex < 0 || navIndex >= ordered.length) return null
    return ordered[navIndex].row
  }

  function navSync() {
    var ordered = navOrdered()
    for (var i = 0; i < ordered.length; i++)
      ordered[i].row.current = (!navInSidebar && i === navIndex)
  }

  function navMove(delta) {
    var ordered = navOrdered()
    if (ordered.length === 0) return
    navInSidebar = false
    navIndex = navIndex < 0
      ? (delta > 0 ? 0 : ordered.length - 1)
      : Math.max(0, Math.min(ordered.length - 1, navIndex + delta))
    navSync()
    navReveal(ordered[navIndex])
  }

  function navJump(where) {
    var ordered = navOrdered()
    if (ordered.length === 0) return
    navInSidebar = false
    navIndex = where < 0 ? 0 : ordered.length - 1
    navSync()
    navReveal(ordered[navIndex])
  }

  // Keep the cursor on screen, with a margin so it never sits flush against
  // the edge it just arrived from.
  function navReveal(entry) {
    if (!entry) return
    var margin = Style.space(24)
    var top = entry.y - margin
    var bottom = entry.y + entry.row.height + margin
    if (top < bodyScroll.contentY) bodyScroll.contentY = Math.max(0, top)
    else if (bottom > bodyScroll.contentY + bodyScroll.height)
      bodyScroll.contentY = Math.min(Math.max(0, bodyScroll.contentHeight - bodyScroll.height),
                                     bottom - bodyScroll.height)
  }

  // The sidebar scrolls too, so Alt can walk the cursor off the bottom of a
  // menu taller than the window.
  function sidebarReveal() {
    // Computed from the index rather than read off the delegate: a Repeater
    // sits among the rows it made, so children[i] is not row i.
    var rowHeight = Style.spacing.controlHeight + Style.space(4)
    var top = sidebarIndex * (rowHeight + Style.space(4))
    var bottom = top + rowHeight
    if (top < sidebarScroll.contentY) sidebarScroll.contentY = Math.max(0, top)
    else if (bottom > sidebarScroll.contentY + sidebarScroll.height)
      sidebarScroll.contentY = Math.min(Math.max(0, sidebarScroll.contentHeight - sidebarScroll.height),
                                        bottom - sidebarScroll.height)
  }

  function navActivate() {
    if (navInSidebar) {
      var entry = sidebarRows[sidebarIndex]
      if (!entry) return
      if (entry.expandable) toggleSection(entry.id)
      else pageId = entry.id
      return
    }
    var row = navCurrent()
    if (row) row.navActivate()
  }

  // Backspace on a changed setting is the (reset) beside its name. A setting
  // this window has not written has nothing to hand back, so the key does
  // nothing rather than something surprising.
  function navReset() {
    if (navInSidebar) return
    var row = navCurrent()
    if (row && row.changed) row.resetRequested()
  }

  // A field that has finished editing hands the keyboard back here; clearing
  // the field's own focus is not enough, since the focus has to land
  // somewhere and this is where the navigation keys live.
  function navTakeFocus() { keySink.forceActiveFocus() }

  // The legend at the foot of the window. Everything the keyboard can do here
  // would be fourteen keys and unreadable, so it says what the keys do *here*:
  // the ones that always apply, plus whatever the cursor is resting on.
  readonly property var navLegend: {
    var keys = []

    if (searchFocused) {
      keys.push({ key: "\u21b5", label: "To settings" })
      keys.push({ key: "Esc", label: "Clear" })
      return keys
    }

    var row = navBlocker !== null ? navBlocker : navCurrent()
    var own = row && row.navKeys ? row.navKeys : []
    for (var i = 0; i < own.length; i++) keys.push(own[i])

    // Only offered when there is something to hand back.
    if (row && row.changed === true) keys.push({ key: "\u232b", label: "Reset" })

    if (navBlocked) return keys

    keys.push({ key: "\u2191\u2193", label: "Move" })
    keys.push({ key: "Alt \u2191\u2193", label: "Page" })
    keys.push({ key: "/", label: "Search" })
    keys.push({ key: "Esc", label: "Close" })
    return keys
  }

  function navStep(delta) {
    if (navInSidebar) return
    var row = navCurrent()
    if (row) row.navStep(delta)
  }

  // Alt walks the sidebar as it is drawn, submenu entries included. Landing on
  // a page opens it; landing on a parent waits for Enter, since opening a
  // submenu is not the same as opening a page.
  function navSidebar(delta) {
    var rows = sidebarRows
    if (rows.length === 0) return
    if (!navInSidebar) {
      navInSidebar = true
      for (var i = 0; i < rows.length; i++)
        if (rows[i].id === pageId) { sidebarIndex = i; break }
    }
    sidebarIndex = Math.max(0, Math.min(rows.length - 1, sidebarIndex + delta))
    sidebarReveal()
    navSync()
    if (rows[sidebarIndex].selectable) pageId = rows[sidebarIndex].id
  }

  // A row that has taken the keyboard — an open dropdown, a field being typed
  // into — keeps it until it says otherwise. The row reports it rather than
  // the window deducing it, so a list rebuilt mid-edit cannot lose track of
  // who is holding the keys.
  property var navBlocker: null
  readonly property bool navBlocked: navBlocker !== null

  function setNavBlocked(row, blocking) {
    if (blocking) navBlocker = row
    else if (navBlocker === row) navBlocker = null
  }

  function hyprValue(key, fallback) {
    var value = hypr ? hypr[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function refresh() {
    if (stateProc.running) return
    stateProc.command = ["bash", root.helperPath, "state"]
    stateProc.running = true
  }

  // Every mutation is the same shape: hand the helper a command, then re-read
  // the world once it settles rather than guessing what changed.
  function run(args) {
    root.busy = true
    applyProc.command = ["bash", root.helperPath].concat(args)
    applyProc.running = true
  }

  function set(key, value) { run(["set", key, String(value)]) }
  function setHypr(key, value) { set(key, value) }

  Process {
    id: stateProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var next = JSON.parse(text)
          if (next && typeof next === "object") {
            root.state = next
            root.loaded = true
            root.wifiLive = null
            root.bluetoothLive = null
          }
        } catch (e) {
          // A partial read leaves the last good state on screen.
        }
      }
    }
  }

  Process {
    id: applyProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastError = text.trim()
    }
    onRunningChanged: if (!running) {
      root.busy = false
      // Theme and font switches ripple through other processes; re-reading a
      // beat later picks up settled values rather than mid-switch ones.
      settleTimer.restart()
    }
  }

  Timer {
    id: settleTimer
    interval: 400
    onTriggered: root.refresh()
  }

  // ---------------- sections ----------------------------------------------
  // A section is either a page of its own or a parent holding pages; the
  // sidebar renders parents as headings and only pages are selectable.
  property string pageId: "appearance"
  // A new page brings new rows, so the cursor starts at its top rather than
  // wherever it happened to be on the page before.
  onPageIdChanged: {
    navIndex = -1
    navRows = []
    bodyLoader.setSource(sectionSource(pageId), { app: root })
  }

  // A page may say something truer about itself than its file path — what the
  // adapter is connected to, say. When it does, that is what the header shows.
  readonly property string pageHeaderNote: bodyLoader.item && bodyLoader.item.headerNote !== undefined
    ? String(bodyLoader.item.headerNote) : ""

  // Ordered the way settings apps are: how it looks, what you type with, the
  // devices, the system, and what extends it. Appearance leads rather than
  // the network, which is where GNOME and macOS start — their top task is
  // getting online, and this window is opened to change how the desktop looks.
  readonly property var sections: [
    // Look and feel
    { id: "appearance", title: "Appearance", icon: "\uf1fc", source: "~/.config/omarchy/shell.toml" },
    { id: "bar", title: "Bar", icon: "\uf0ca", source: "~/.config/omarchy/shell.json" },
    { id: "windows", title: "Windows", icon: "\uf2d0", source: "~/.config/hypr/looknfeel.lua" },
    { id: "layout", title: "Layout", icon: "\uf009", source: "~/.config/hypr/looknfeel.lua" },
    { id: "effects", title: "Effects", icon: "\uf0eb", source: "~/.config/hypr/looknfeel.lua" },
    { id: "groups", title: "Groups", icon: "\uf009", source: "~/.config/hypr/looknfeel.lua" },

    // Input
    { id: "keyboard", title: "Keyboard", icon: "\uf11c", source: "~/.config/hypr/input.lua" },
    { id: "bindings", title: "Keybindings", icon: "\uf11c", source: "~/.config/hypr/bindings.lua" },
    { id: "compose", title: "Compose Keys", icon: "\uf031", source: "~/.XCompose" },
    { id: "pointer", title: "Mouse & Touchpad", icon: "\uf245", source: "~/.config/hypr/input.lua" },

    // Devices
    { id: "displays", title: "Displays", icon: "\uf108", source: "~/.config/hypr/monitors.lua" },
    { id: "audio", title: "Audio", icon: "\uf028", source: "pactl" },
    { id: "network", title: "Network", icon: "\uf1eb", source: "/etc/systemd/resolved.conf.d" },
    { id: "bluetooth", title: "Bluetooth", icon: "\uf294", source: "bluetoothctl" },
    { id: "power", title: "Power", icon: "\uf0e7", source: "powerprofilesctl" },

    // System
    { id: "idle", title: "Idle & Lock", icon: "\uf023", source: "~/.config/omarchy/shell.json" },
    { id: "datetime", title: "Date & Time", icon: "\uf017", source: "/etc/localtime" },

    // What extends it
    { id: "plugins", title: "Plugins", icon: "\uf1e6", source: "~/.config/omarchy/shell.json" },
    { id: "apps", title: "Applications", icon: "\uf085", children: [
      { id: "apps.defaults", title: "Defaults", source: "~/.config/omarchy/defaults" },
      { id: "apps.herdr", title: "Herdr", source: "~/.config/herdr/config.toml" },
      { id: "apps.tmux", title: "Tmux", source: "~/.config/tmux/tmux.conf" },
      { id: "apps.nvim", title: "Neovim", source: "~/.config/nvim/lua/config/options.lua" }
    ] }
  ]

  // Which parents are open. A parent holding the current page is always
  // open — collapsing the branch you are looking at would leave the sidebar
  // with nothing highlighted.
  property var expandedSections: ({})

  function isExpanded(section) {
    var children = section.children || []
    for (var c = 0; c < children.length; c++)
      if (children[c].id === pageId) return true
    return expandedSections[section.id] === true
  }

  function toggleSection(id) {
    var next = ({})
    for (var k in expandedSections) next[k] = expandedSections[k]
    next[id] = !next[id]
    expandedSections = next
  }

  // One flat list the sidebar Repeater can walk: parents that open and close,
  // pages for everything selectable, each carrying the depth it renders at.
  readonly property var sidebarRows: {
    var rows = []
    for (var i = 0; i < sections.length; i++) {
      var section = sections[i]
      var children = section.children || []
      var open = children.length > 0 && isExpanded(section)
      var sectionCount = sectionMatchCount(section)
      // A page with no matches is not dimmed or emptied, it is gone: that is
      // what says "there is nothing here for what you typed".
      if (!sectionShows(section)) continue
      rows.push({
        id: section.id,
        title: section.title,
        icon: section.icon || "",
        selectable: children.length === 0,
        expandable: children.length > 0,
        // A parent holds its children open while searching, or its matches
        // would be counted but unreachable.
        expanded: open || (searching && children.length > 0),
        indented: false,
        matches: sectionCount
      })
      if (!(open || (searching && children.length > 0))) continue
      for (var c = 0; c < children.length; c++) {
        if (!pageAvailable(children[c].id)) continue
        var childCount = pageMatchCount(children[c].id)
        if (!pageShows(children[c].id)) continue
        rows.push({
          id: children[c].id,
          title: children[c].title,
          icon: "",
          selectable: true,
          expandable: false,
          expanded: false,
          indented: true,
          matches: childCount
        })
      }
    }
    return rows
  }

  function pageFor(id) {
    for (var i = 0; i < sections.length; i++) {
      var section = sections[i]
      if (section.id === id) return section
      var children = section.children || []
      for (var c = 0; c < children.length; c++)
        if (children[c].id === id) return children[c]
    }
    return { title: "", source: "" }
  }

  // Pages live one to a file under sections/; the window only has to know
  // which file answers to which id.
  function sectionSource(id) {
    switch (id) {
    case "appearance": return "sections/AppearanceSection.qml"
    case "bar": return "sections/BarSection.qml"
    case "windows": return "sections/WindowsSection.qml"
    case "keyboard": return "sections/KeyboardSection.qml"
    case "bindings": return "sections/BindingsSection.qml"
    case "pointer": return "sections/PointerSection.qml"
    case "displays": return "sections/DisplaysSection.qml"
    case "idle": return "sections/IdleSection.qml"
    case "plugins": return "sections/PluginsSection.qml"
    case "compose": return "sections/ComposeSection.qml"
    case "datetime": return "sections/DateTimeSection.qml"
    case "network": return "sections/NetworkSection.qml"
    case "bluetooth": return "sections/BluetoothSection.qml"
    case "layout": return "sections/LayoutSection.qml"
    case "effects": return "sections/EffectsSection.qml"
    case "groups": return "sections/GroupsSection.qml"
    case "power": return "sections/PowerSection.qml"
    case "audio": return "sections/AudioSection.qml"
    case "apps.defaults": return "sections/DefaultsSection.qml"
    case "apps.tmux": return "sections/TmuxSection.qml"
    case "apps.nvim": return "sections/NvimSection.qml"
    // Named rather than left to the default: the search index reads these
    // cases to learn which file holds which page, and a page reachable only
    // through the default is a page it cannot see.
    case "apps.herdr": return "sections/HerdrSection.qml"
    default: return "sections/HerdrSection.qml"
    }
  }

  // A layer-shell surface rather than an ordinary window: a toplevel is the
  // tiler's to place, so it landed beside whatever was open and only floated
  // for someone who had written a Hyprland rule for it by hand. On the overlay
  // layer the settings open above the current windows on any machine, with
  // nothing to install and nothing to configure — the same way the Omarchy
  // menu and the bar panels do it.
  PanelWindow {
    id: window
    visible: false
    // A layer surface goes to whichever screen it is given, and given none it
    // goes to the first one — so on two monitors the settings could open on
    // the one you are not looking at. Chosen when it opens rather than bound:
    // a window that hops to another screen while you are reading it is worse
    // than one that stays where it was opened.
    screen: root.openedOn !== null ? root.openedOn : null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omasettings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Dimming what is behind says the settings are in front of it, and gives
    // the click-outside-to-close target somewhere to live.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.45)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.hide()
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      // Nine tenths of the screen it is on, whatever screen that is.
      width: Math.round(window.width * 0.9)
      height: Math.round(window.height * 0.9)
      color: root.background
      radius: Style.cornerRadius
      border.width: 1
      border.color: root.hairline

      // The card is not the scrim: a click that lands on it stays on it.
      MouseArea { anchors.fill: parent }

    // Asked, because this is the one thing here that cannot be undone by
    // clicking again.
    ConfirmDialog {
      id: resetAllDialog
      anchors.fill: parent
      z: 100
      message: root.changedSettings.length === 1
        ? "Reset the one setting changed from this window?"
        : "Reset all " + root.changedSettings.length + " settings changed from this window?"
      confirmText: "Reset all"
      cancelText: "Cancel"
      background: root.background
      foreground: root.foreground
      fontFamily: root.fontFamily
      onConfirmed: {
        opened = false
        root.run(["reset", "--all"])
      }
      onCanceled: opened = false
    }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true

      // Focus given back to the scope itself lands on whichever child held it
      // last — the very field being left — so it is given to a sink that
      // wants nothing, and the navigation keys are handled above it.
      Item { id: keySink; focus: true }

      // The vocabulary every Omarchy panel uses, plus Alt for the sidebar and
      // Home/End for the ends of a long page. Keys.BeforeItem is what lets
      // Up/Down drive the cursor rather than being eaten by the Flickable —
      // except when a row has taken the keyboard for itself.
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        var alt = (event.modifiers & Qt.AltModifier) !== 0
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0

        // A row holding the keyboard gets every key, Escape included: closing
        // an open dropdown is what Escape means while one is open.
        // The dialog has no keys of its own, so it borrows the window's while
        // it is up, and nothing else gets a look in.
        if (resetAllDialog.opened) {
          if (event.key === Qt.Key_Escape) { resetAllDialog.opened = false; event.accepted = true }
          else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                   || event.text === "h" || event.text === "l"
                   || event.key === Qt.Key_Tab) {
            resetAllDialog.selectedIndex = resetAllDialog.selectedIndex === 1 ? 0 : 1
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                     || event.key === Qt.Key_Space) {
            if (resetAllDialog.selectedIndex === 1) resetAllDialog.confirmed()
            else resetAllDialog.opened = false
            event.accepted = true
          }
          return
        }

        if (root.navBlocked || root.searchFocused) return

        // Undoing everything is a big enough thing to want a key of its own,
        // and a modifier keeps it clear of the Backspace that resets one.
        if (event.key === Qt.Key_Backspace && ctrl) {
          if (root.changedSettings.length > 0) resetAllDialog.opened = true
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }


        // The two things every search box answers to.
        if (event.text === "/" || (ctrl && event.key === Qt.Key_F)) {
          searchField.forceActiveFocus()
          searchField.selectAll()
          event.accepted = true
          return
        }

        if (event.key === Qt.Key_Down || event.text === "j") {
          alt ? root.navSidebar(1) : root.navMove(1)
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Up || event.text === "k") {
          alt ? root.navSidebar(-1) : root.navMove(-1)
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Right || event.text === "l") {
          root.navStep(1); event.accepted = true; return
        }
        if (event.key === Qt.Key_Left || event.text === "h") {
          root.navStep(-1); event.accepted = true; return
        }
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.navActivate(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
          root.navReset(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Home) { root.navJump(-1); event.accepted = true; return }
        if (event.key === Qt.Key_End) { root.navJump(1); event.accepted = true; return }
        // Tab moves between the two lists rather than through every control,
        // which is what the sidebar and a page of settings actually are.
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          if (root.navInSidebar) { root.navInSidebar = false; root.navSync() }
          else root.navSidebar(0)
          event.accepted = true; return
        }
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        // ---------------- sidebar ------------------------------------------
        Rectangle {
          Layout.fillHeight: true
          Layout.preferredWidth: Style.space(220)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.panelPadding
            spacing: Style.space(4)

            Text {
              text: "OmaSettings"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              Layout.bottomMargin: Style.space(10)
            }

            // Above the menu, because what it filters is the menu as much as
            // the page: pages with nothing to show leave the list entirely.
            TextField {
              id: searchField
              Layout.fillWidth: true
              Layout.bottomMargin: Style.space(10)
              placeholderText: "Search settings"
              foreground: root.foreground
              accent: root.accent
              font.family: root.fontFamily
              onTextChanged: root.searchQuery = text
              // Escape gives the keyboard back to the list rather than closing
              // the window out from under a search.
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  if (text !== "") text = ""
                  root.navTakeFocus()
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                           || event.key === Qt.Key_Down) {
                  root.navTakeFocus()
                  root.navMove(1)
                  event.accepted = true
                }
              }
            }

            // The menu is as long as the settings are; on a tall list it ran
            // past the foot of the window, taking the reset button and the
            // update notice with it. Only the menu scrolls — the title, the
            // search box and the corner stay put.
            Flickable {
              id: sidebarScroll
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              contentWidth: width
              contentHeight: sidebarMenu.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick

              ColumnLayout {
                id: sidebarMenu
                width: sidebarScroll.width
                spacing: Style.space(4)

                Repeater {
                model: root.sidebarRows
                delegate: Rectangle {
                  required property var modelData
                  required property int index

                  readonly property bool current: modelData.selectable && modelData.id === root.pageId
                  // Where the keyboard is, which is not always the open page:
                  // Alt can walk onto a parent without opening anything.
                  readonly property bool cursored: root.navInSidebar && index === root.sidebarIndex

                  Layout.fillWidth: true
                  implicitHeight: Style.spacing.controlHeight + Style.space(4)
                  radius: Style.cornerRadius
                  border.width: cursored ? Style.normalBorderWidth : 0
                  border.color: root.accent
                  color: current
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                    : (cursored
                       ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10)
                       : (navMouse.containsMouse
                          ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                          : "transparent"))

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10) + (modelData.indented ? Style.space(18) : 0)
                    spacing: Style.space(10)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: !modelData.indented
                      text: modelData.icon
                      color: current ? root.accent : root.muted
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      width: Style.space(18)
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.title
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: current
                    }

                    // How much of what you typed is in there.
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: root.searching && modelData.matches > 0
                      text: modelData.matches
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Chevron only on parents, pointing the way the branch will
                  // move when clicked.
                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.expandable
                    text: modelData.expanded ? "\uf077" : "\uf078"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.expandable) root.toggleSection(modelData.id)
                      else root.pageId = modelData.id
                    }
                  }
                }
              }
              }
            }

            // What this window has changed, and the way to undo the lot. Only
            // when there is something to undo — a button that mostly does
            // nothing teaches you to ignore it.
            Column {
              visible: root.changedSettings.length > 0
              spacing: Style.space(2)

              Text {
                text: root.changedSettings.length === 1
                  ? "1 setting changed" : root.changedSettings.length + " settings changed"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // A button, not a link: it is an action on the whole window
              // rather than a place to go, and it should look like the other
              // things that do something.
              Button {
                text: "Reset all settings"
                bordered: true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: resetAllDialog.opened = true
              }
            }

            // The corner says something only when there is something to say:
            // while a write is in flight, before the first state lands, or
            // when this window is itself behind its remote. "Ready" was none
            // of those — it reported that nothing was happening.
            Text {
              visible: root.busy || !root.loaded
              text: root.busy ? "Applying…" : "Loading…"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Column {
              visible: !root.busy && root.loaded && root.selfBehind > 0
              spacing: Style.space(2)

              Text {
                text: "\uf0aa  Update available"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                id: updateLink
                text: root.selfBehind === 1 ? "1 commit behind · update"
                  : root.selfBehind + " commits behind · update"
                color: updateMouse.containsMouse ? root.accent : root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.underline: updateMouse.containsMouse

                MouseArea {
                  id: updateMouse
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.selfId !== "") root.run(["plugin", "update", root.selfId])
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillHeight: true
          Layout.preferredWidth: Style.spacing.hairline
          color: root.hairline
        }

        // ---------------- body ---------------------------------------------
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(56)

            // The page names itself once, here. Where a page has a control
            // that governs everything below it — the Bluetooth adapter, the
            // Wi-Fi radio — that control belongs beside the name rather than
            // repeated as the first row of the body.
            Column {
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.panelPadding
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: root.pageFor(root.pageId).title
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }

              Text {
                text: root.pageHeaderNote !== "" ? root.pageHeaderNote : (root.pageFor(root.pageId).source || "")
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Loader {
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.panelPadding
              anchors.verticalCenter: parent.verticalCenter
              sourceComponent: bodyLoader.item && bodyLoader.item.headerControl
                ? bodyLoader.item.headerControl : null
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.spacing.hairline
            color: root.hairline
          }

          Flickable {
            id: bodyScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Style.spacing.panelPadding
            clip: true
            contentWidth: width
            contentHeight: bodyLoader.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Loader {
              id: bodyLoader
              width: bodyScroll.width
              // setSource passes `app` in as an initial property, so a page's
              // bindings never evaluate against a null window.
              Component.onCompleted: setSource(root.sectionSource(root.pageId), { app: root })
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.margins: Style.spacing.panelPadding
            Layout.topMargin: 0
            visible: root.lastError !== ""
            text: root.lastError
            color: Color.urgent
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      // ---------------- legend ---------------------------------------------
      // Across the foot of the window, under both columns. It follows the
      // cursor rather than listing everything: the keys that always apply,
      // and whatever the row under the cursor answers to.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.spacing.controlHeight
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)

        Rectangle {
          anchors.top: parent.top
          width: parent.width
          height: Style.spacing.hairline
          color: root.hairline
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.panelPadding
          anchors.verticalCenter: parent.verticalCenter
          // Wide enough between entries that each key and what it does read as
          // one thing, rather than the whole bar reading as one long line.
          spacing: Style.space(28)

          Repeater {
            model: root.navLegend

            // Plain text, not keycaps: the legend is there to be glanced at,
            // and a row of boxes along the foot pulls the eye off the settings
            // it is meant to be helping with. The key is a shade brighter than
            // what it does, which is enough to tell them apart.
            delegate: Row {
              required property var modelData
              spacing: Style.space(5)

              Text {
                text: modelData.key
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.75)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                text: modelData.label
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
      }
    }
    }
  }

  // ---------------- sections ----------------------------------------------


  // The bar's centre section is anchored on a widget id; offer the ids the
  // user actually has in their bar rather than a hardcoded list.
  function barWidgetIds() {
    var ids = []
    if (!plugins) return ids
    for (var i = 0; i < plugins.length; i++) {
      var kinds = plugins[i].kinds || []
      if (kinds.indexOf("bar-widget") !== -1) ids.push(plugins[i].id)
    }
    return ids
  }

  // ---------------- shared row components ----------------------------------


}
