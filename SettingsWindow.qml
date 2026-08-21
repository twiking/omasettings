import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

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
  readonly property color foreground: Color.popups.text
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

  readonly property var wifi: state.wifi !== undefined ? state.wifi : ({})
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

  function sectionComponent(id) {
    switch (id) {
    case "appearance": return appearanceSection
    case "bar": return barSection
    case "windows": return windowsSection
    case "keyboard": return keyboardSection
    case "bindings": return bindingsSection
    case "pointer": return pointerSection
    case "displays": return displaysSection
    case "idle": return idleSection
    case "plugins": return pluginsSection
    case "compose": return composeSection
    case "datetime": return datetimeSection
    case "network": return networkSection
    case "apps.defaults": return defaultsSection
    case "apps.tmux": return tmuxSection
    case "apps.nvim": return nvimSection
    default: return herdrSection
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

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.panelPadding
              anchors.verticalCenter: parent.verticalCenter
              text: root.pageFor(root.pageId).title
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.panelPadding
              anchors.verticalCenter: parent.verticalCenter
              text: root.pageFor(root.pageId).source || ""
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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
              sourceComponent: root.sectionComponent(root.pageId)
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

  Component {
    id: appearanceSection
    SectionBody {
      SettingGroup {
        title: "Theme and font"

        PickerRow {
          label: "Theme"
          value: root.state.theme !== undefined ? String(root.state.theme) : ""
          options: root.state.themes
          searchable: true
          onPicked: function(next) { root.set("theme", next) }
        }

        PickerRow {
          label: "Font"
          value: root.state.font !== undefined ? String(root.state.font) : ""
          options: root.state.fonts
          searchable: true
          onPicked: function(next) { root.set("font", next) }
        }

        NumberRow {
          label: "Text size"
          description: "Scales the shell, GTK apps, and terminals together."
          suffix: "px"
          value: root.state.textScale !== undefined ? Number(root.state.textScale) : 12
          from: 9
          to: 20
          onCommitted: function(next) { root.set("text-scale", next) }
        }
      }

      SettingGroup {
        title: "Screen tint"

        SwitchRow {
          label: "Night light"
          description: "Warms the screen to 4000K."
          checked: root.state.nightlight === true
          onRequested: function(next) { root.set("nightlight", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Wallpaper and boot"

        ActionRow {
          label: "Background"
          description: "Pick from the wallpapers that come with your theme."
          buttonText: "Choose…"
          onTriggered: root.run(["menu", "run", "style.background"])
        }

        ActionRow {
          label: "Boot and unlock screen"
          description: "The animation shown while the machine starts and unlocks."
          buttonText: "Choose…"
          onTriggered: root.run(["menu", "run", "style.unlock"])
        }
      }

      SettingGroup {
        title: "Branding"
        note: "What the screensaver and the about screen show."

        BrandingRow {
          label: "Screensaver"
          entryPrefix: "style.screensaver"
        }

        BrandingRow {
          label: "About screen"
          entryPrefix: "style.about"
        }
      }
    }
  }

  Component {
    id: barSection
    SectionBody {
      SettingGroup {
        title: "Placement"

        PickerRow {
          label: "Position"
          value: root.barState.position !== undefined ? String(root.barState.position) : "top"
          options: ["top", "bottom", "left", "right"]
          onPicked: function(next) { root.set("bar-position", next) }
        }

        SwitchRow {
          label: "Transparent"
          description: "Drops the bar's own background so the wallpaper shows through."
          checked: root.barState.transparent === true
          onRequested: function(next) { root.set("bar-transparent", next ? "true" : "false") }
        }

        PickerRow {
          label: "Centered widget"
          description: "The widget the centre section is anchored on."
          value: root.barState.centerAnchor !== undefined ? String(root.barState.centerAnchor) : ""
          options: root.barWidgetIds()
          searchable: true
          onPicked: function(next) { root.set("bar-center-anchor", next) }
        }
      }
    }
  }

  Component {
    id: windowsSection
    SectionBody {
      SettingGroup {
        title: "Layout"

        NumberRow {
          label: "Inner gaps"
          suffix: "px"
          value: root.hyprValue("gaps-in", 0)
          from: 0
          to: 40
          onCommitted: function(next) { root.setHypr("gaps-in", next) }
        }

        NumberRow {
          label: "Outer gaps"
          suffix: "px"
          value: root.hyprValue("gaps-out", 0)
          from: 0
          to: 60
          onCommitted: function(next) { root.setHypr("gaps-out", next) }
        }

        NumberRow {
          label: "Border width"
          suffix: "px"
          value: root.hyprValue("border-size", 0)
          from: 0
          to: 10
          onCommitted: function(next) { root.setHypr("border-size", next) }
        }

        NumberRow {
          label: "Corner rounding"
          suffix: "px"
          value: root.hyprValue("rounding", 0)
          from: 0
          to: 24
          onCommitted: function(next) { root.setHypr("rounding", next) }
        }
      }

      SettingGroup {
        title: "Focus and depth"

        PercentRow {
          label: "Active window opacity"
          value: root.hyprValue("active-opacity", 1)
          onCommitted: function(next) { root.setHypr("active-opacity", next) }
        }

        PercentRow {
          label: "Inactive window opacity"
          value: root.hyprValue("inactive-opacity", 1)
          onCommitted: function(next) { root.setHypr("inactive-opacity", next) }
        }

        SwitchRow {
          label: "Dim inactive windows"
          checked: root.hyprValue("dim-inactive", false) === true
          onRequested: function(next) { root.setHypr("dim-inactive", next ? "true" : "false") }
        }

        PercentRow {
          label: "Dim strength"
          enabled: root.hyprValue("dim-inactive", false) === true
          value: root.hyprValue("dim-strength", 0.5)
          onCommitted: function(next) { root.setHypr("dim-strength", next) }
        }
      }

      SettingGroup {
        title: "Effects"

        SwitchRow {
          label: "Animations"
          checked: root.hyprValue("animations", true) === true
          onRequested: function(next) { root.setHypr("animations", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Blur"
          description: "Blurs whatever is behind translucent windows and layers."
          checked: root.hyprValue("blur", false) === true
          onRequested: function(next) { root.setHypr("blur", next ? "true" : "false") }
        }

        NumberRow {
          label: "Blur size"
          enabled: root.hyprValue("blur", false) === true
          value: root.hyprValue("blur-size", 8)
          from: 1
          to: 20
          onCommitted: function(next) { root.setHypr("blur-size", next) }
        }

        NumberRow {
          label: "Blur passes"
          enabled: root.hyprValue("blur", false) === true
          value: root.hyprValue("blur-passes", 1)
          from: 1
          to: 5
          onCommitted: function(next) { root.setHypr("blur-passes", next) }
        }
      }

      SettingGroup {
        title: "Beyond these settings"

        ActionRow {
          label: "Window rules and animations"
          description: "Open looknfeel.lua for anything this page does not cover."
          buttonText: "Edit…"
          onTriggered: root.run(["menu", "run", "style.hyprland"])
        }
      }
    }
  }

  Component {
    id: keyboardSection
    SectionBody {
      SettingGroup {
        title: "Layout"
        note: "Add several layouts separated by commas, then set a shortcut to switch under Options."

        TextRow {
          label: "Layouts"
          placeholder: "us,se"
          value: String(root.hyprValue("kb-layout", ""))
          onCommitted: function(next) { root.setHypr("kb-layout", next) }
        }

        TextRow {
          label: "Variant"
          placeholder: "intl"
          value: String(root.hyprValue("kb-variant", ""))
          onCommitted: function(next) { root.setHypr("kb-variant", next) }
        }

        TextRow {
          label: "Options"
          placeholder: "compose:caps,grp:alts_toggle"
          value: String(root.hyprValue("kb-options", ""))
          onCommitted: function(next) { root.setHypr("kb-options", next) }
        }
      }

      SettingGroup {
        title: "Repeat"

        NumberRow {
          label: "Repeat rate"
          suffix: "keys/s"
          value: root.hyprValue("repeat-rate", 25)
          from: 1
          to: 100
          onCommitted: function(next) { root.setHypr("repeat-rate", next) }
        }

        NumberRow {
          label: "Repeat delay"
          suffix: "ms"
          value: root.hyprValue("repeat-delay", 600)
          from: 100
          to: 1000
          step: 50
          onCommitted: function(next) { root.setHypr("repeat-delay", next) }
        }

        SwitchRow {
          label: "Num lock on at login"
          checked: root.hyprValue("numlock", false) === true
          onRequested: function(next) { root.setHypr("numlock", next ? "true" : "false") }
        }
      }
    }
  }

  Component {
    id: pointerSection
    SectionBody {
      SettingGroup {
        title: "Pointer"

        PercentRow {
          label: "Sensitivity"
          description: "How far the pointer travels for the same hand movement."
          value: (Number(root.hyprValue("sensitivity", 0)) + 1) / 2
          onCommitted: function(next) { root.setHypr("sensitivity", (next * 2 - 1).toFixed(2)) }
        }

        PickerRow {
          label: "Acceleration"
          value: String(root.hyprValue("accel-profile", ""))
          options: [
            { value: "", label: "Default (adaptive)" },
            { value: "flat", label: "Flat — no acceleration" },
            { value: "adaptive", label: "Adaptive" }
          ]
          onPicked: function(next) { root.setHypr("accel-profile", next) }
        }

        PickerRow {
          label: "Focus follows mouse"
          value: String(root.hyprValue("follow-mouse", 1))
          options: [
            { value: "0", label: "Off — click to focus" },
            { value: "1", label: "On" },
            { value: "2", label: "On, but keyboard stays" },
            { value: "3", label: "On, without raising" }
          ]
          onPicked: function(next) { root.setHypr("follow-mouse", next) }
        }
      }

      SettingGroup {
        title: "Touchpad"

        SwitchRow {
          label: "Natural scrolling"
          checked: root.hyprValue("natural-scroll", false) === true
          onRequested: function(next) { root.setHypr("natural-scroll", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Tap to click"
          checked: root.hyprValue("tap-to-click", true) === true
          onRequested: function(next) { root.setHypr("tap-to-click", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Two-finger right click"
          description: "Off uses the lower-right corner instead."
          checked: root.hyprValue("clickfinger", false) === true
          onRequested: function(next) { root.setHypr("clickfinger", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Disable while typing"
          checked: root.hyprValue("disable-while-typing", true) === true
          onRequested: function(next) { root.setHypr("disable-while-typing", next ? "true" : "false") }
        }

        FactorRow {
          label: "Scroll speed"
          value: Number(root.hyprValue("scroll-factor", 1))
          onCommitted: function(next) { root.setHypr("scroll-factor", next) }
        }
      }
    }
  }

  Component {
    id: displaysSection
    SectionBody {
      SettingGroup {
        title: "Scale"

        Repeater {
          model: root.monitors
          delegate: FactorRow {
            required property var modelData
            width: parent.width
            label: modelData.name
            description: modelData.width + "×" + modelData.height + " @ " + modelData.refreshRate + "Hz"
            minimum: 0.5
            maximum: 3
            value: Number(modelData.scale)
            onCommitted: function(next) { root.set("monitor-scale", modelData.name + "=" + next) }
          }
        }
      }
    }
  }

  Component {
    id: idleSection
    SectionBody {
      SettingGroup {
        title: "Timeouts"
        note: "Counted from when you stop using the machine."

        MinutesRow {
          label: "Screensaver after"
          seconds: root.idleState.screensaver !== undefined ? Number(root.idleState.screensaver) : 150
          onCommitted: function(mins) { root.set("idle-screensaver", mins * 60) }
        }

        MinutesRow {
          label: "Lock after"
          seconds: root.idleState.lock !== undefined ? Number(root.idleState.lock) : 300
          onCommitted: function(mins) { root.set("idle-lock", mins * 60) }
        }
      }
    }
  }

  Component {
    id: pluginsSection
    SectionBody {
      SettingGroup {
        title: "Installed plugins"
        note: "A bar widget also needs a slot in the bar before it shows up there."

        Repeater {
          model: root.plugins
          delegate: SwitchRow {
            required property var modelData
            width: parent.width
            label: modelData.name
            description: modelData.id + (modelData.firstParty ? " · built in" : "")
            checked: modelData.enabled === true
            onRequested: function(next) { root.run(["plugin", next ? "enable" : "disable", modelData.id]) }
          }
        }
      }
    }
  }

  Component {
    id: composeSection
    SectionBody {
      SettingGroup {
        title: "Add a sequence"
        note: "The compose key first, then the keys to press after it. Write the compose key as <Multi_key>."

        Row {
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: keysField
            width: (parent.width - addButton.width - Style.space(16)) * 0.45
            placeholderText: "<Multi_key> <s> <e>"
            foreground: root.foreground
            accent: root.accent
          }

          TextField {
            id: textField
            width: (parent.width - addButton.width - Style.space(16)) * 0.55
            placeholderText: "text it types"
            foreground: root.foreground
            accent: root.accent
          }

          Button {
            id: addButton
            text: "Add"
            bordered: true
            foreground: root.foreground
            accent: root.accent
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
              if (keysField.text.trim() === "" || textField.text === "") return
              root.run(["compose", "add", keysField.text.trim(), textField.text])
              keysField.text = ""
              textField.text = ""
            }
          }
        }
      }

      SettingGroup {
        title: "Your sequences"
        note: root.composeEntries.length === 0 ? "Nothing defined yet." : ""

        Repeater {
          model: root.composeEntries
          delegate: Item {
            required property var modelData
            width: parent.width
            implicitHeight: Style.spacing.controlHeight

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * 0.45
              elide: Text.ElideRight
              text: modelData.keys
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: parent.width * 0.47
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * 0.4
              elide: Text.ElideRight
              text: modelData.text
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            PanelActionButton {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uf00d"
              tooltipText: "Remove"
              foreground: root.foreground
              onClicked: root.run(["compose", "remove", modelData.keys])
            }
          }
        }
      }
    }
  }

  Component {
    id: bindingsSection
    SectionBody {
      SettingGroup {
        title: "Add a binding"
        note: "Keys as Hyprland spells them: SUPER, SHIFT, CTRL, ALT, and a key. Binding a combination that is already taken replaces it."

        Row {
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: keysField
            width: (parent.width - addBindingButton.width - Style.space(24)) * 0.3
            placeholderText: "SUPER + SHIFT + R"
            foreground: root.foreground
            accent: root.accent
          }

          TextField {
            id: bindingDescriptionField
            width: (parent.width - addBindingButton.width - Style.space(24)) * 0.25
            placeholderText: "what it does"
            foreground: root.foreground
            accent: root.accent
          }

          TextField {
            id: commandField
            width: (parent.width - addBindingButton.width - Style.space(24)) * 0.45
            placeholderText: "command to run"
            foreground: root.foreground
            accent: root.accent
          }

          Button {
            id: addBindingButton
            text: "Add"
            bordered: true
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
              if (keysField.text.trim() === "" || commandField.text.trim() === "") return
              root.run(["keys", "add", keysField.text.trim(),
                        bindingDescriptionField.text.trim(), commandField.text.trim()])
              keysField.text = ""
              bindingDescriptionField.text = ""
              commandField.text = ""
            }
          }
        }
      }

      SettingGroup {
        title: "Every binding"

        TextField {
          width: parent.width
          placeholderText: "Search keys or actions…"
          text: root.bindingFilter
          foreground: root.foreground
          accent: root.accent
          onTextChanged: root.bindingFilter = text
        }

        Text {
          width: parent.width
          text: root.visibleBindings.length + " of " + (root.bindings.items !== undefined ? root.bindings.items.length : 0)
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.visibleBindings
          delegate: BindingRow {
            required property var modelData
            width: parent.width
            keys: modelData.keys
            description: modelData.description
            command: modelData.command
            source: modelData.source
          }
        }
      }
    }
  }

  Component {
    id: networkSection
    SectionBody {
      SettingGroup {
        title: "Wi-Fi"

        SwitchRow {
          label: "Wi-Fi"
          description: root.wifi.connected ? "Connected to " + root.wifi.connected : "Not connected"
          checked: root.wifi.enabled === true
          onRequested: function(next) { root.run(["wifi", "radio", next ? "on" : "off"]) }
        }

        ReadingRow {
          label: "IP address"
          visible: root.wifi.connected !== ""
          value: root.wifiConnection.ip
            ? String(root.wifiConnection.ip) + (root.wifiConnection.prefix ? "/" + root.wifiConnection.prefix : "")
            : "—"
        }

        ReadingRow {
          label: "Gateway"
          visible: root.wifi.connected !== ""
          value: root.wifiConnection.gateway ? String(root.wifiConnection.gateway) : "—"
        }

        PickerRow {
          label: "Band"
          visible: root.wifi.connected !== "" && root.bandOptions().length > 1
          description: root.wifiBand.selected === "auto" && root.wifiBand.current
            ? "Currently on " + root.wifiBand.current + " GHz"
            : "Pinned; the radio will not move off it."
          value: root.wifiBand.selected !== undefined ? String(root.wifiBand.selected) : "auto"
          options: root.bandOptions()
          onPicked: function(next) { root.run(["wifi", "band", next]) }
        }

        Item {
          width: parent.width
          implicitHeight: rescanButton.implicitHeight
          visible: root.wifi.enabled === true

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.wifiNetworks.length === 1 ? "1 network in range"
                                                 : root.wifiNetworks.length + " networks in range"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Button {
            id: rescanButton
            anchors.right: parent.right
            text: "Scan again"
            bordered: true
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: root.run(["wifi", "rescan"])
          }
        }

        Repeater {
          model: root.wifi.enabled === true ? root.wifiNetworks : []
          delegate: WifiRow {
            required property var modelData
            width: parent.width
            ssid: modelData.ssid
            signalStrength: Number(modelData.signal)
            secured: modelData.secured === true
            saved: modelData.saved === true
            active: modelData.active === true
          }
        }
      }

      SettingGroup {
        title: "DNS"
        note: "Which servers resolve names on every connection."

        PickerRow {
          label: "Resolver"
          value: root.group("dns").current
          options: root.groupOptions("dns")
          onPicked: function(next) { root.run(["menu", "run", "setup.network.dns." + next]) }
        }
      }

      SettingGroup {
        title: "Sharing"

        ActionRow {
          label: "Wi-Fi QR code"
          description: "Show a code others can scan to join this network."
          buttonText: "Show…"
          onTriggered: root.run(["menu", "run", "setup.network.qr"])
        }
      }
    }
  }

  Component {
    id: defaultsSection
    SectionBody {
      SettingGroup {
        title: "Applications"
        note: "An app you have not installed yet is set up the first time you pick it."

        PickerRow {
          label: "Browser"
          value: root.group("browser").current
          options: root.groupOptions("browser")
          onPicked: function(next) { root.run(["menu", "run", "setup.default.browser." + next]) }
        }

        PickerRow {
          label: "Terminal"
          value: root.group("terminal").current
          options: root.groupOptions("terminal")
          onPicked: function(next) { root.run(["menu", "run", "setup.default.terminal." + next]) }
        }

        PickerRow {
          label: "Editor"
          value: root.group("editor").current
          options: root.groupOptions("editor")
          onPicked: function(next) { root.run(["menu", "run", "setup.default.editor." + next]) }
        }

        PickerRow {
          label: "Coding agent"
          value: root.agentsState.current !== undefined ? String(root.agentsState.current) : ""
          options: root.agentOptions()
          onPicked: function(next) { root.run(["agents", "run", next]) }
        }
      }
    }
  }

  Component {
    id: datetimeSection
    SectionBody {
      SettingGroup {
        title: "Clock"

        ActionRow {
          label: "Timezone"
          description: root.datetime.timezone ? String(root.datetime.timezone) : "Unknown"
          buttonText: "Change…"
          onTriggered: root.run(["menu", "run", "update.timezone"])
        }

        ActionRow {
          label: "System time"
          description: (root.datetime.now ? String(root.datetime.now) : "")
            + (root.datetime.ntp === true
               ? (root.datetime.synchronized === true ? " · synchronized" : " · syncing")
               : " · automatic sync off")
          buttonText: "Resync…"
          onTriggered: root.run(["menu", "run", "update.time"])
        }
      }
    }
  }

  Component {
    id: tmuxSection
    SectionBody {
      SettingGroup {
        title: "Keys"

        TextRow {
          label: "Prefix"
          description: "tmux spelling: C-Space, C-b, M-a."
          placeholder: "C-b"
          value: String(root.tmuxValue("prefix", "C-b"))
          onCommitted: function(next) { root.setTmux("prefix", next) }
        }

        PickerRow {
          label: "Copy mode keys"
          value: String(root.tmuxValue("mode-keys", "emacs"))
          options: [
            { value: "vi", label: "Vi" },
            { value: "emacs", label: "Emacs" }
          ]
          onPicked: function(next) { root.setTmux("mode-keys", next) }
        }

        ActionRow {
          label: "Every shortcut"
          description: "The full list, as tmux has it."
          buttonText: "Show…"
          onTriggered: root.run(["menu", "run", "learn.tmux-keybindings"])
        }
      }

      SettingGroup {
        title: "Status bar"

        PickerRow {
          label: "Position"
          value: String(root.tmuxValue("status-position", "bottom"))
          options: [
            { value: "top", label: "Top" },
            { value: "bottom", label: "Bottom" }
          ]
          onPicked: function(next) { root.setTmux("status-position", next) }
        }
      }

      SettingGroup {
        title: "Windows and panes"

        NumberRow {
          label: "First window number"
          value: Number(root.tmuxValue("base-index", 0))
          from: 0
          to: 1
          onCommitted: function(next) { root.setTmux("base-index", next) }
        }

        NumberRow {
          label: "First pane number"
          value: Number(root.tmuxValue("pane-base-index", 0))
          from: 0
          to: 1
          onCommitted: function(next) { root.setTmux("pane-base-index", next) }
        }

        SwitchRow {
          label: "Renumber when one closes"
          checked: root.tmuxValue("renumber-windows", false) === true
          onRequested: function(next) { root.setTmux("renumber-windows", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Behaviour"

        SwitchRow {
          label: "Mouse"
          description: "Click to focus a pane, drag to resize, scroll to page back."
          checked: root.tmuxValue("mouse", false) === true
          onRequested: function(next) { root.setTmux("mouse", next ? "true" : "false") }
        }

        NumberRow {
          label: "Scrollback"
          suffix: "lines"
          value: Number(root.tmuxValue("history-limit", 2000))
          from: 1000
          to: 100000
          step: 1000
          onCommitted: function(next) { root.setTmux("history-limit", next) }
        }

        NumberRow {
          label: "Escape delay"
          suffix: "ms"
          description: "Low values keep Esc snappy in Vim; zero can break some terminals."
          value: Number(root.tmuxValue("escape-time", 500))
          from: 0
          to: 500
          step: 10
          onCommitted: function(next) { root.setTmux("escape-time", next) }
        }

        PickerRow {
          label: "Clipboard"
          description: "Whether tmux hands copied text to the outer terminal."
          value: String(root.tmuxValue("set-clipboard", "external"))
          options: [
            { value: "on", label: "On" },
            { value: "external", label: "External only" },
            { value: "off", label: "Off" }
          ]
          onPicked: function(next) { root.setTmux("set-clipboard", next) }
        }
      }

      SettingGroup {
        title: "Beyond these settings"

        ActionRow {
          label: "The rest of the config"
          description: "Open tmux.conf for bindings, styling, and plugins."
          buttonText: "Edit…"
          onTriggered: root.editConfig("$HOME/.config/tmux/tmux.conf")
        }
      }
    }
  }

  Component {
    id: nvimSection
    SectionBody {
      SettingGroup {
        title: "The gutter"

        SwitchRow {
          label: "Line numbers"
          checked: root.nvimValue("number", true) === true
          onRequested: function(next) { root.setNvim("number", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Relative line numbers"
          checked: root.nvimValue("relativenumber", true) === true
          onRequested: function(next) { root.setNvim("relativenumber", next ? "true" : "false") }
        }

        PickerRow {
          label: "Sign column"
          description: "Where git marks and diagnostics appear."
          value: String(root.nvimValue("signcolumn", "yes"))
          options: [
            { value: "yes", label: "Always" },
            { value: "auto", label: "Only when needed" },
            { value: "no", label: "Never" }
          ]
          onPicked: function(next) { root.setNvim("signcolumn", next) }
        }
      }

      SettingGroup {
        title: "The text"

        SwitchRow {
          label: "Wrap long lines"
          checked: root.nvimValue("wrap", false) === true
          onRequested: function(next) { root.setNvim("wrap", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Highlight the current line"
          checked: root.nvimValue("cursorline", true) === true
          onRequested: function(next) { root.setNvim("cursorline", next ? "true" : "false") }
        }

        TextRow {
          label: "Column guide"
          description: "A column number, or empty for none."
          placeholder: "100"
          value: String(root.nvimValue("colorcolumn", ""))
          onCommitted: function(next) { root.setNvim("colorcolumn", next) }
        }

        NumberRow {
          label: "Keep visible above and below"
          suffix: "lines"
          value: Number(root.nvimValue("scrolloff", 4))
          from: 0
          to: 20
          onCommitted: function(next) { root.setNvim("scrolloff", next) }
        }

        SwitchRow {
          label: "Spell checking"
          checked: root.nvimValue("spell", false) === true
          onRequested: function(next) { root.setNvim("spell", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Indentation"

        SwitchRow {
          label: "Spaces instead of tabs"
          checked: root.nvimValue("expandtab", true) === true
          onRequested: function(next) { root.setNvim("expandtab", next ? "true" : "false") }
        }

        NumberRow {
          label: "Indent width"
          suffix: "spaces"
          value: Number(root.nvimValue("shiftwidth", 2))
          from: 1
          to: 8
          onCommitted: function(next) { root.setNvim("shiftwidth", next) }
        }

        NumberRow {
          label: "Tab width"
          suffix: "spaces"
          value: Number(root.nvimValue("tabstop", 2))
          from: 1
          to: 8
          onCommitted: function(next) { root.setNvim("tabstop", next) }
        }
      }

      SettingGroup {
        title: "Beyond these settings"
        note: "Changes here apply the next time Neovim starts."

        ActionRow {
          label: "The rest of the config"
          description: "Open options.lua for anything this page does not cover."
          buttonText: "Edit…"
          onTriggered: root.editConfig("$HOME/.config/nvim/lua/config/options.lua")
        }
      }
    }
  }

  Component {
    id: herdrSection
    SectionBody {
      SettingGroup {
        title: "Appearance"

        PickerRow {
          label: "Theme"
          value: String(root.herdrValue("theme.name", "catppuccin"))
          options: [
            { value: "terminal", label: "Terminal palette" },
            { value: "catppuccin", label: "Catppuccin" },
            { value: "tokyo-night", label: "Tokyo Night" },
            { value: "dracula", label: "Dracula" },
            { value: "nord", label: "Nord" },
            { value: "gruvbox", label: "Gruvbox" },
            { value: "one-dark", label: "One Dark" },
            { value: "solarized", label: "Solarized" },
            { value: "kanagawa", label: "Kanagawa" },
            { value: "rose-pine", label: "Rosé Pine" },
            { value: "vesper", label: "Vesper" }
          ]
          onPicked: function(next) { root.setHerdr("theme.name", next) }
        }

        TextRow {
          label: "Accent"
          description: "A colour name, #rrggbb, or rgb(r,g,b)."
          placeholder: "cyan"
          value: String(root.herdrValue("ui.accent", "cyan"))
          onCommitted: function(next) { root.setHerdr("ui.accent", next) }
        }

        PickerRow {
          label: "Tab bar"
          value: String(root.herdrValue("ui.tab_bar_position", "top"))
          options: [
            { value: "top", label: "Top" },
            { value: "bottom", label: "Bottom" }
          ]
          onPicked: function(next) { root.setHerdr("ui.tab_bar_position", next) }
        }

        SwitchRow {
          label: "Hide the tab bar with one tab"
          checked: root.herdrValue("ui.hide_tab_bar_when_single_tab", false) === true
          onRequested: function(next) { root.setHerdr("ui.hide_tab_bar_when_single_tab", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Panes"

        SwitchRow {
          label: "Borders"
          checked: root.herdrValue("ui.pane_borders", true) === true
          onRequested: function(next) { root.setHerdr("ui.pane_borders", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Outer border"
          description: "Off gives tmux-style splitters with no frame around the edge."
          checked: root.herdrValue("ui.pane_outer_borders", true) === true
          onRequested: function(next) { root.setHerdr("ui.pane_outer_borders", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Gaps between panes"
          checked: root.herdrValue("ui.pane_gaps", true) === true
          onRequested: function(next) { root.setHerdr("ui.pane_gaps", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Scrollbars"
          checked: root.herdrValue("ui.pane_scrollbars", true) === true
          onRequested: function(next) { root.setHerdr("ui.pane_scrollbars", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Agent labels on borders"
          description: "Shown when a pane has no name of its own."
          checked: root.herdrValue("ui.show_agent_labels_on_pane_borders", false) === true
          onRequested: function(next) { root.setHerdr("ui.show_agent_labels_on_pane_borders", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Sidebar"

        NumberRow {
          label: "Width"
          suffix: "columns"
          value: Number(root.herdrValue("ui.sidebar_width", 26))
          from: 12
          to: 60
          onCommitted: function(next) { root.setHerdr("ui.sidebar_width", next) }
        }

        SwitchRow {
          label: "Start collapsed"
          description: "Takes effect the next time Herdr launches."
          checked: root.herdrValue("ui.sidebar_start_collapsed", false) === true
          onRequested: function(next) { root.setHerdr("ui.sidebar_start_collapsed", next ? "true" : "false") }
        }

        PickerRow {
          label: "When collapsed"
          value: String(root.herdrValue("ui.sidebar_collapsed_mode", "compact"))
          options: [
            { value: "compact", label: "Keep the status rail" },
            { value: "hidden", label: "Hide it completely" }
          ]
          onPicked: function(next) { root.setHerdr("ui.sidebar_collapsed_mode", next) }
        }
      }

      SettingGroup {
        title: "Behaviour"

        PickerRow {
          label: "New panes open in"
          value: String(root.herdrValue("terminal.new_cwd", "follow"))
          options: [
            { value: "follow", label: "The folder you were in" },
            { value: "home", label: "Your home folder" },
            { value: "current", label: "Herdr's own folder" }
          ]
          onPicked: function(next) { root.setHerdr("terminal.new_cwd", next) }
        }

        SwitchRow {
          label: "Capture the mouse"
          description: "Off lets the terminal handle clicks, so links stay clickable."
          checked: root.herdrValue("ui.mouse_capture", true) === true
          onRequested: function(next) { root.setHerdr("ui.mouse_capture", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Copy on selection"
          checked: root.herdrValue("ui.copy_on_select", true) === true
          onRequested: function(next) { root.setHerdr("ui.copy_on_select", next ? "true" : "false") }
        }

        NumberRow {
          label: "Scroll step"
          suffix: "lines"
          value: Number(root.herdrValue("ui.mouse_scroll_lines", 3))
          from: 1
          to: 10
          onCommitted: function(next) { root.setHerdr("ui.mouse_scroll_lines", next) }
        }

        SwitchRow {
          label: "Confirm before closing"
          checked: root.herdrValue("ui.confirm_close", true) === true
          onRequested: function(next) { root.setHerdr("ui.confirm_close", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Ask for a tab name"
          checked: root.herdrValue("ui.prompt_new_tab_name", true) === true
          onRequested: function(next) { root.setHerdr("ui.prompt_new_tab_name", next ? "true" : "false") }
        }

        SwitchRow {
          label: "Ask for a workspace name"
          checked: root.herdrValue("ui.prompt_new_workspace_name", false) === true
          onRequested: function(next) { root.setHerdr("ui.prompt_new_workspace_name", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Notifications"

        PickerRow {
          label: "Pop-ups"
          value: String(root.herdrValue("ui.toast.delivery", "off"))
          options: [
            { value: "off", label: "None" },
            { value: "herdr", label: "Inside Herdr" },
            { value: "terminal", label: "Through the terminal" },
            { value: "system", label: "Desktop notifications" }
          ]
          onPicked: function(next) { root.setHerdr("ui.toast.delivery", next) }
        }

        SwitchRow {
          label: "Sounds"
          description: "Played when an agent changes state in a background workspace."
          checked: root.herdrValue("ui.sound.enabled", true) === true
          onRequested: function(next) { root.setHerdr("ui.sound.enabled", next ? "true" : "false") }
        }
      }

      SettingGroup {
        title: "Keys"

        TextRow {
          label: "Prefix"
          description: "Every prefix+… shortcut starts with this."
          placeholder: "ctrl+b"
          value: String(root.herdrValue("keys.prefix", "ctrl+b"))
          onCommitted: function(next) { root.setHerdr("keys.prefix", next) }
        }

        ActionRow {
          label: "Every shortcut"
          description: "The full list, as Herdr has it."
          buttonText: "Show…"
          onTriggered: root.run(["menu", "run", "learn.herdr-keybindings"])
        }

        ActionRow {
          label: "The rest of the config"
          description: "Open config.toml for the settings this page does not cover."
          buttonText: "Edit…"
          onTriggered: root.editConfig("$HOME/.config/herdr/config.toml")
        }
      }

      SettingGroup {
        title: "Window title"

        TextRow {
          label: "Title"
          description: "Tokens: {hostname}, {workspace}, {tab}, {pane}, {terminal_title}."
          placeholder: "{hostname}: {workspace}"
          value: String(root.herdrValue("ui.window_title", ""))
          onCommitted: function(next) { root.setHerdr("ui.window_title", next) }
        }
      }
    }
  }

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

  component SectionBody: Column {
    spacing: Style.space(24)
    width: parent ? parent.width : 0
  }

  component SettingGroup: Column {
    id: group
    property string title: ""
    property string note: ""
    default property alias content: groupContent.data

    width: parent ? parent.width : 0
    spacing: Style.space(10)

    Text {
      text: group.title
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }

    Text {
      visible: group.note !== ""
      width: group.width
      text: group.note
      wrapMode: Text.WordWrap
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Column {
      id: groupContent
      width: group.width
      spacing: Style.space(12)
    }
  }

  // Label on the left, control on the right — the shape every row shares.
  component SettingRow: Item {
    id: settingRow
    property string label: ""
    property string description: ""
    default property alias control: controlHolder.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelColumn.implicitHeight, controlHolder.implicitHeight)
    opacity: enabled ? 1 : 0.45

    Column {
      id: labelColumn
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.5
      spacing: Style.space(2)

      Text {
        text: settingRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        visible: settingRow.description !== ""
        width: parent.width
        text: settingRow.description
        wrapMode: Text.WordWrap
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Item {
      id: controlHolder
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.46
      implicitHeight: childrenRect.height
    }
  }

  component SwitchRow: SettingRow {
    id: switchRow
    property bool checked: false
    signal requested(bool next)

    ToggleSwitch {
      anchors.right: parent.right
      checked: switchRow.checked
      foreground: root.foreground
      accent: root.accent
      interactive: switchRow.enabled
      onToggled: switchRow.requested(!switchRow.checked)
    }
  }

  component PickerRow: SettingRow {
    id: pickerRow
    property var options: []
    property string value: ""
    property bool searchable: false
    signal picked(string next)

    // Options arrive either as bare strings or as {value,label} objects.
    readonly property var normalized: {
      var out = []
      var list = pickerRow.options || []
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (entry && typeof entry === "object") out.push(entry)
        else out.push({ value: String(entry), label: String(entry) })
      }
      return out
    }

    Loader {
      width: parent.width
      sourceComponent: pickerRow.searchable ? searchableComponent : plainComponent
    }

    Component {
      id: plainComponent
      Dropdown {
        width: parent ? parent.width : 0
        showLabel: false
        fontFamily: root.fontFamily
        value: pickerRow.value
        options: pickerRow.normalized
        onChanged: function(next) { pickerRow.picked(next) }
      }
    }

    Component {
      id: searchableComponent
      SearchableDropdown {
        width: parent ? parent.width : 0
        showLabel: false
        fontFamily: root.fontFamily
        placeholderText: "Search…"
        value: pickerRow.value
        options: pickerRow.normalized
        onChanged: function(next) { pickerRow.picked(next) }
      }
    }
  }

  component TextRow: SettingRow {
    id: textRow
    property string value: ""
    property string placeholder: ""
    signal committed(string next)

    TextField {
      width: parent.width
      text: textRow.value
      placeholderText: textRow.placeholder
      foreground: root.foreground
      accent: root.accent
      // Committing on Enter or focus loss keeps a half-typed layout string
      // from being applied one character at a time.
      onEditingFinished: if (text !== textRow.value) textRow.committed(text)
    }
  }

  // A whole number on a slider, written only when the drag ends.
  component NumberRow: SettingRow {
    id: numberRow
    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    property string suffix: ""
    signal committed(int next)

    readonly property int shown: numberSlider.dragging ? Math.round(numberSlider.liveValue) : value

    Row {
      width: parent.width
      spacing: Style.space(10)

      PanelSlider {
        id: numberSlider
        width: parent.width - readout.width - Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        integer: true
        step: numberRow.step
        minimum: numberRow.from
        maximum: numberRow.to
        value: numberRow.value
        enabled: numberRow.enabled
        onReleased: function(v) {
          var next = Math.round(v)
          if (next !== numberRow.value) numberRow.committed(next)
        }
      }

      Text {
        id: readout
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: numberRow.shown + (numberRow.suffix !== "" ? " " + numberRow.suffix : "")
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // A 0–1 value shown as a percentage.
  component PercentRow: SettingRow {
    id: percentRow
    property real value: 1
    signal committed(real next)

    readonly property real shown: percentSlider.dragging ? percentSlider.liveValue : value

    Row {
      width: parent.width
      spacing: Style.space(10)

      PanelSlider {
        id: percentSlider
        width: parent.width - percentReadout.width - Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        minimum: 0
        maximum: 1
        step: 0.05
        value: Math.max(0, Math.min(1, percentRow.value))
        enabled: percentRow.enabled
        onReleased: function(v) {
          var next = Math.round(v * 100) / 100
          if (next !== percentRow.value) percentRow.committed(next)
        }
      }

      Text {
        id: percentReadout
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: Math.round(percentRow.shown * 100) + "%"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // A multiplier such as a display scale or scroll speed, in steps of 0.05.
  component FactorRow: SettingRow {
    id: factorRow
    property real value: 1
    property real minimum: 0.1
    property real maximum: 3
    signal committed(string next)

    readonly property real shown: factorSlider.dragging ? factorSlider.liveValue : value

    Row {
      width: parent.width
      spacing: Style.space(10)

      PanelSlider {
        id: factorSlider
        width: parent.width - factorReadout.width - Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        minimum: factorRow.minimum
        maximum: factorRow.maximum
        step: 0.05
        value: Math.max(factorRow.minimum, Math.min(factorRow.maximum, factorRow.value))
        enabled: factorRow.enabled
        onReleased: function(v) {
          var next = (Math.round(v * 20) / 20).toFixed(2)
          if (Number(next) !== factorRow.value) factorRow.committed(next)
        }
      }

      Text {
        id: factorReadout
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: "×" + factorRow.shown.toFixed(2)
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // A duration stored in seconds but edited in whole minutes.
  component MinutesRow: SettingRow {
    id: minutesRow
    property int seconds: 0
    signal committed(int mins)

    readonly property int currentMinutes: Math.max(1, Math.round(seconds / 60))
    readonly property int shownMinutes: minutesSlider.dragging ? Math.round(minutesSlider.liveValue) : currentMinutes

    Row {
      width: parent.width
      spacing: Style.space(10)

      PanelSlider {
        id: minutesSlider
        width: parent.width - minutesReadout.width - Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        integer: true
        step: 1
        minimum: 1
        maximum: 60
        value: minutesRow.currentMinutes
        onReleased: function(v) {
          var next = Math.max(1, Math.round(v))
          if (next !== minutesRow.currentMinutes) minutesRow.committed(next)
        }
      }

      Text {
        id: minutesReadout
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(76)
        horizontalAlignment: Text.AlignRight
        text: minutesRow.shownMinutes + (minutesRow.shownMinutes === 1 ? " min" : " mins")
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // A row whose setting lives behind someone else's flow: the state is shown,
  // and the button hands off to the command that owns it.
  component ActionRow: SettingRow {
    id: actionRow
    property string buttonText: ""
    signal triggered()

    Button {
      anchors.right: parent.right
      text: actionRow.buttonText
      bordered: true
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      onClicked: actionRow.triggered()
    }
  }

  // Three ways to set one piece of branding, the way the menu offers them:
  // type it, point at an image, or put the shipped one back.
  component BrandingRow: SettingRow {
    id: brandingRow
    property string entryPrefix: ""

    Row {
      anchors.right: parent.right
      spacing: Style.space(8)

      Button {
        text: "Text…"
        bordered: true
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onClicked: root.run(["menu", "run", brandingRow.entryPrefix + ".text"])
      }

      Button {
        text: "Image…"
        bordered: true
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onClicked: root.run(["menu", "run", brandingRow.entryPrefix + ".image"])
      }

      Button {
        text: "Reset"
        bordered: true
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onClicked: root.run(["menu", "run", brandingRow.entryPrefix + ".default"])
      }
    }
  }

  // One binding: what you press, what it does, and the one action that makes
  // sense for where it came from — yours can be removed, Omarchy's can be
  // turned off, and a turned-off one can come back.
  component BindingRow: Item {
    id: bindingRow
    property string keys: ""
    property string description: ""
    property string command: ""
    property string source: "omarchy"

    readonly property bool mine: source === "yours"
    readonly property bool off: source === "disabled"

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Style.spacing.controlHeight, keysText.implicitHeight + Style.space(6))
    opacity: off ? 0.5 : 1

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: bindingMouse.containsMouse
        ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
        : "transparent"
    }

    MouseArea {
      id: bindingMouse
      anchors.fill: parent
      hoverEnabled: true
    }

    Text {
      id: keysText
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.3
      elide: Text.ElideRight
      text: bindingRow.keys
      color: bindingRow.mine ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: parent.width * 0.32
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.32
      elide: Text.ElideRight
      text: bindingRow.description
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: parent.width * 0.65
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * 0.22
      elide: Text.ElideRight
      visible: bindingRow.command !== ""
      text: bindingRow.command
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Button {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      visible: bindingMouse.containsMouse || bindingRow.off
      text: bindingRow.mine ? "Remove" : (bindingRow.off ? "Restore" : "Turn off")
      bordered: true
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      onClicked: {
        if (bindingRow.mine || bindingRow.off) root.run(["keys", "remove", bindingRow.keys])
        else root.run(["keys", "disable", bindingRow.keys])
      }
    }
  }

  // One network: name, how strong it is, whether it wants a password, and
  // what clicking it will do. A network that needs a password asks for it
  // in place rather than in a dialog on top of the list.
  component WifiRow: Column {
    id: wifiRow
    property string ssid: ""
    property int signalStrength: 0
    property bool secured: false
    property bool saved: false
    property bool active: false

    readonly property bool prompting: root.wifiPrompting === wifiRow.ssid
    // A saved network has its password already; only a new secured one needs asking.
    readonly property bool needsPassword: wifiRow.secured && !wifiRow.saved

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Style.spacing.controlHeight

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: wifiRow.active
          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
          : (wifiMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")
      }

      MouseArea {
        id: wifiMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (wifiRow.active) return
          if (wifiRow.needsPassword) root.wifiPrompting = wifiRow.prompting ? "" : wifiRow.ssid
          else root.connectWifi(wifiRow.ssid)
        }
      }

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        // Four rungs of signal, drawn rather than set in a glyph: icon fonts
        // vary in what they carry, and a missing glyph would leave every
        // network looking equally strong.
        Row {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(20)
          spacing: Style.space(2)

          Repeater {
            model: 4
            delegate: Rectangle {
              required property int index
              readonly property int rungs: wifiRow.signalStrength >= 70 ? 4
                                         : wifiRow.signalStrength >= 45 ? 3
                                         : wifiRow.signalStrength >= 20 ? 2 : 1
              width: Style.space(3)
              height: Style.space(4) + index * Style.space(3)
              anchors.bottom: parent.bottom
              radius: 1
              color: wifiRow.active ? root.accent : root.foreground
              opacity: index < rungs ? 1 : 0.25
            }
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: wifiRow.ssid
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: wifiRow.active
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: wifiRow.secured
          text: "\uf023"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: wifiRow.saved && !wifiRow.active
          text: "saved"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: wifiRow.signalStrength + "%"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          anchors.verticalCenter: parent.verticalCenter
          visible: wifiRow.active
          text: "Disconnect"
          bordered: true
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: root.run(["wifi", "disconnect"])
        }

        Button {
          anchors.verticalCenter: parent.verticalCenter
          visible: wifiRow.saved && !wifiRow.active && wifiMouse.containsMouse
          text: "Forget"
          bordered: true
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: root.run(["wifi", "forget", wifiRow.ssid])
        }
      }
    }

    Row {
      width: parent.width
      visible: wifiRow.prompting
      spacing: Style.space(8)

      TextField {
        id: passwordField
        width: parent.width - connectButton.width - Style.space(8)
        placeholderText: "Password for " + wifiRow.ssid
        password: true
        foreground: root.foreground
        accent: root.accent
        onAccepted: if (text !== "") root.connectWifi(wifiRow.ssid, text)
      }

      Button {
        id: connectButton
        anchors.verticalCenter: parent.verticalCenter
        text: "Connect"
        bordered: true
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onClicked: if (passwordField.text !== "") root.connectWifi(wifiRow.ssid, passwordField.text)
      }
    }
  }

  // A value the page reports but does not set.
  component ReadingRow: SettingRow {
    id: readingRow
    property string value: ""

    Text {
      anchors.right: parent.right
      text: readingRow.value
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
