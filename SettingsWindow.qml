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
    { id: "pointer", title: "Mouse & Touchpad", icon: "\uf245", source: "~/.config/hypr/input.lua" },
    { id: "displays", title: "Displays", icon: "\uf108", source: "~/.config/hypr/monitors.lua" },
    { id: "idle", title: "Idle & Lock", icon: "\uf023", source: "~/.config/omarchy/shell.json" },
    { id: "plugins", title: "Plugins", icon: "\uf1e6", source: "~/.config/omarchy/shell.json" },
    { id: "compose", title: "Compose Keys", icon: "\uf031", source: "~/.XCompose" },
    { id: "agents", title: "Agents", icon: "\udb81\udea9", children: [
      { id: "agents.default", title: "Default Agents", source: "~/.config/omarchy/defaults/agent" },
      { id: "agents.herdr", title: "Herdr", source: "" }
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
    case "pointer": return pointerSection
    case "displays": return displaysSection
    case "idle": return idleSection
    case "plugins": return pluginsSection
    case "compose": return composeSection
    case "agents.default": return defaultAgentsSection
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
        note: "Applied with omarchy theme set / omarchy font set."

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
    }
  }

  Component {
    id: keyboardSection
    SectionBody {
      SettingGroup {
        title: "Layout"
        note: "Comma-separated layouts switch with the key combination set in options."

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
          description: "Hyprland's -1 to 1 range, shown as a percentage of full speed."
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
        note: "Applied live and written to the generated Hyprland config."

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
        note: "Bar widgets also need a place in the bar; use omarchy bar put for that."

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
        note: "Compose key first, then the keys to press. Type <Multi_key> for the compose key itself."

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
    id: defaultAgentsSection
    SectionBody {
      SettingGroup {
        title: "Default coding agent"
        note: "The same entries as the Omarchy menu's Setup → Defaults → Agent, and the same actions: picking an agent that is not installed yet opens a terminal to set it up."

        Repeater {
          model: root.agentsState.items !== undefined ? root.agentsState.items : []
          delegate: AgentRow {
            required property var modelData
            width: parent.width
            label: modelData.label
            glyph: modelData.icon
            glyphFont: modelData.iconFont === "omarchy" ? "omarchy" : root.fontFamily
            current: modelData.checked === true
            onChosen: root.run(["agents", "run", modelData.id])
          }
        }
      }
    }
  }

  Component {
    id: herdrSection
    SectionBody {
      SettingGroup {
        title: "Herdr"
        note: "Nothing here yet."
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

  // A pick-one row: the whole row is the target, and the current choice is
  // marked the way the menu marks it rather than with a control that implies
  // it can be switched off.
  component AgentRow: Item {
    id: agentRow
    property string label: ""
    property string glyph: ""
    property string glyphFont: ""
    property bool current: false
    signal chosen()

    width: parent ? parent.width : 0
    implicitHeight: Style.spacing.controlHeight

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: agentRow.current
        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
        : (agentMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(12)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: agentRow.glyph
        color: agentRow.current ? root.accent : root.muted
        font.family: agentRow.glyphFont !== "" ? agentRow.glyphFont : root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(20)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: agentRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      visible: agentRow.current
      text: "\uf00c"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: agentMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: agentRow.chosen()
    }
  }
}
