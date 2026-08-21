import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

  function show() { window.visible = true; refresh() }
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

  readonly property var audio: state.audio !== undefined ? state.audio : ({})

  // Input devices. Each page lists its own, one group per device, so the
  // Keyboard and Mouse pages never have to say which device a control means.
  readonly property var devices: state.devices !== undefined ? state.devices : ({})

  function setDevice(name, key, value, kind) {
    run(["devices", "set", name, key, String(value), kind])
  }

  function clearDevice(name) { run(["devices", "clear", name]) }

  readonly property var power: state.power !== undefined ? state.power : ({})

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
    if (password !== undefined && password !== "") run(["wifi", "connect", ssid, password])
    else run(["wifi", "connect", ssid])
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
  onPageIdChanged: bodyLoader.setSource(sectionSource(pageId), { app: root })

  // A page may say something truer about itself than its file path — what the
  // adapter is connected to, say. When it does, that is what the header shows.
  readonly property string pageHeaderNote: bodyLoader.item && bodyLoader.item.headerNote !== undefined
    ? String(bodyLoader.item.headerNote) : ""

  readonly property var sections: [
    { id: "appearance", title: "Appearance", icon: "\uf1fc", source: "~/.config/omarchy/shell.toml" },
    { id: "bar", title: "Bar", icon: "\uf0ca", source: "~/.config/omarchy/shell.json" },
    { id: "windows", title: "Windows", icon: "\uf2d0", source: "~/.config/hypr/looknfeel.lua" },
    { id: "keyboard", title: "Keyboard", icon: "\uf11c", source: "~/.config/hypr/input.lua" },
    { id: "bindings", title: "Keybindings", icon: "\uf11c", source: "~/.config/hypr/bindings.lua" },
    { id: "pointer", title: "Mouse & Touchpad", icon: "\uf245", source: "~/.config/hypr/input.lua" },
    { id: "displays", title: "Displays", icon: "\uf108", source: "~/.config/hypr/monitors.lua" },
    { id: "idle", title: "Idle & Lock", icon: "\uf023", source: "~/.config/omarchy/shell.json" },
    { id: "plugins", title: "Plugins", icon: "\uf1e6", source: "~/.config/omarchy/shell.json" },
    { id: "compose", title: "Compose Keys", icon: "\uf031", source: "~/.XCompose" },
    { id: "datetime", title: "Date & Time", icon: "\uf017", source: "/etc/localtime" },
    { id: "network", title: "Network", icon: "\uf1eb", source: "/etc/systemd/resolved.conf.d" },
    { id: "bluetooth", title: "Bluetooth", icon: "\uf294", source: "bluetoothctl" },
    { id: "power", title: "Power", icon: "\uf0e7", source: "powerprofilesctl" },
    { id: "audio", title: "Audio", icon: "\uf028", source: "pactl" },

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
      rows.push({
        id: section.id,
        title: section.title,
        icon: section.icon || "",
        selectable: children.length === 0,
        expandable: children.length > 0,
        expanded: open,
        indented: false
      })
      if (!open) continue
      for (var c = 0; c < children.length; c++) {
        rows.push({
          id: children[c].id,
          title: children[c].title,
          icon: "",
          selectable: true,
          expandable: false,
          expanded: false,
          indented: true
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
    case "power": return "sections/PowerSection.qml"
    case "audio": return "sections/AudioSection.qml"
    case "apps.defaults": return "sections/DefaultsSection.qml"
    case "apps.tmux": return "sections/TmuxSection.qml"
    case "apps.nvim": return "sections/NvimSection.qml"
    default: return "sections/HerdrSection.qml"
    }
  }

  FloatingWindow {
    id: window
    title: "OmaSettings"
    color: root.background
    implicitWidth: Style.space(940)
    implicitHeight: Style.space(680)
    minimumSize: Qt.size(Style.space(720), Style.space(520))

    FocusScope {
      anchors.fill: parent
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
      }

      RowLayout {
        anchors.fill: parent
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

            Repeater {
              model: root.sidebarRows
              delegate: Rectangle {
                required property var modelData

                readonly property bool current: modelData.selectable && modelData.id === root.pageId

                Layout.fillWidth: true
                implicitHeight: Style.spacing.controlHeight + Style.space(4)
                radius: Style.cornerRadius
                color: current
                  ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                  : (navMouse.containsMouse
                     ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                     : "transparent")

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

            Item { Layout.fillHeight: true }

            Text {
              text: root.busy ? "Applying…" : (root.loaded ? "Ready" : "Loading…")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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
