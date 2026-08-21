import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// OmaSettings — the settings a desktop gets fiddled with daily (theme, font,
// where the bar sits, night light, how long until the screen locks) gathered
// into one bar panel. Every control is a thin front end for the omarchy
// command that already owns that setting; nothing here writes state the CLI
// would not write itself.
Panel {
  id: root
  moduleName: "io.github.twiking.omasettings"
  ipcTarget: "omasettings"

  readonly property int maxIdleMinutes: Math.max(5, Math.min(240, setting("maxIdleMinutes", 60)))

  readonly property string helperPath: String(Qt.resolvedUrl("bin/omasettings")).replace(/^file:\/\//, "")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // One JSON blob from the helper, so the panel never has to know which
  // command answers which question.
  property var state: ({})
  property bool loaded: false
  // Set while a change is in flight: the helper's `state` read only reflects
  // it once the underlying command has finished, and until then the control
  // should keep showing what the user just picked rather than snapping back.
  property string pendingKey: ""

  readonly property string currentTheme: state.theme !== undefined ? String(state.theme) : ""
  readonly property string currentFont: state.font !== undefined ? String(state.font) : ""
  readonly property string barPosition: state.barPosition !== undefined ? String(state.barPosition) : "top"
  readonly property bool barTransparent: state.barTransparent === true
  readonly property bool nightlight: state.nightlight === true
  readonly property int idleScreensaver: state.idleScreensaver !== undefined ? Number(state.idleScreensaver) : 150
  readonly property int idleLock: state.idleLock !== undefined ? Number(state.idleLock) : 300

  function refresh() {
    if (!stateProc.running) {
      stateProc.command = ["bash", root.helperPath, "state"]
      stateProc.running = true
    }
  }

  function apply(key, value) {
    root.pendingKey = key
    applyProc.command = ["bash", root.helperPath, "set", key, String(value)]
    applyProc.running = true
  }

  function optionsFrom(list) {
    var out = []
    if (!list) return out
    for (var i = 0; i < list.length; i++) out.push({ value: String(list[i]), label: String(list[i]) })
    return out
  }

  function minutes(seconds) { return Math.max(1, Math.round(Number(seconds) / 60)) }

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
          // A partial or failed read leaves the last good state on screen.
        }
      }
    }
  }

  Process {
    id: applyProc
    onRunningChanged: if (!running) {
      root.pendingKey = ""
      // Theme and font changes ripple through other processes; re-reading a
      // beat later picks up the settled values rather than the mid-switch ones.
      settleTimer.restart()
    }
  }

  Timer {
    id: settleTimer
    interval: 400
    onTriggered: root.refresh()
  }

  // Panels are cheap to reopen but the state behind them is not free to poll,
  // so it is read on open rather than on a timer.
  onOpenedChanged: if (opened) refresh()

  Component.onCompleted: refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: root.currentTheme !== "" ? "Settings — " + root.currentTheme : "Settings"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While a dropdown owns the keyboard, the panel must not also act on it.
      blocked: themePicker.popupOpen || fontPicker.popupOpen || positionPicker.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Appearance ----------
        PanelSectionHeader {
          text: "APPEARANCE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        SearchableDropdown {
          id: themePicker
          width: parent.width
          label: "Theme"
          fontFamily: root.fontFamily
          placeholderText: "Search themes..."
          value: root.currentTheme
          options: root.optionsFrom(root.state.themes)
          onChanged: function(next) { root.apply("theme", next) }
        }

        SearchableDropdown {
          id: fontPicker
          width: parent.width
          label: "Font"
          fontFamily: root.fontFamily
          placeholderText: "Search fonts..."
          value: root.currentFont
          options: root.optionsFrom(root.state.fonts)
          onChanged: function(next) { root.apply("font", next) }
        }

        PanelSeparator { foreground: root.foreground }

        // ---------- Bar ----------
        PanelSectionHeader {
          text: "BAR"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Dropdown {
          id: positionPicker
          width: parent.width
          label: "Position"
          fontFamily: root.fontFamily
          value: root.barPosition
          options: [
            { value: "top", label: "Top" },
            { value: "bottom", label: "Bottom" },
            { value: "left", label: "Left" },
            { value: "right", label: "Right" }
          ]
          onChanged: function(next) { root.apply("bar-position", next) }
        }

        SwitchRow {
          label: "Transparent"
          checked: root.barTransparent
          onRequested: function(next) { root.apply("bar-transparent", next ? "true" : "false") }
        }

        PanelSeparator { foreground: root.foreground }

        // ---------- Screen ----------
        PanelSectionHeader {
          text: "SCREEN"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        SwitchRow {
          label: "Night light"
          checked: root.nightlight
          onRequested: function(next) { root.apply("nightlight", next ? "true" : "false") }
        }

        MinutesRow {
          label: "Screensaver after"
          seconds: root.idleScreensaver
          onCommitted: function(mins) { root.apply("idle-screensaver", mins * 60) }
        }

        MinutesRow {
          label: "Lock after"
          seconds: root.idleLock
          onCommitted: function(mins) { root.apply("idle-lock", mins * 60) }
        }
      }
    }
  }

  // A labelled switch: the label takes the row, the switch sits at its end.
  component SwitchRow: Item {
    id: switchRow

    property string label: ""
    property bool checked: false
    signal requested(bool next)

    width: column.width
    implicitHeight: Math.max(switchLabel.implicitHeight, toggle.implicitHeight)

    Text {
      id: switchLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: switchRow.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
    }

    ToggleSwitch {
      id: toggle
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: switchRow.checked
      foreground: root.foreground
      onToggled: switchRow.requested(!switchRow.checked)
    }
  }

  // A duration in whole minutes: dragging shows the value it will commit, and
  // only the release writes it, so a drag across the track is one setting
  // change rather than one per pixel.
  component MinutesRow: Column {
    id: minutesRow

    property string label: ""
    property int seconds: 0
    signal committed(int minutes)

    readonly property int currentMinutes: root.minutes(seconds)
    readonly property int shownMinutes: slider.dragging ? Math.round(slider.liveValue) : currentMinutes

    width: column.width
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: rowLabel.implicitHeight

      Text {
        id: rowLabel
        anchors.left: parent.left
        text: minutesRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        renderType: Text.NativeRendering
      }

      Text {
        anchors.right: parent.right
        anchors.baseline: rowLabel.baseline
        text: minutesRow.shownMinutes + (minutesRow.shownMinutes === 1 ? " min" : " mins")
        color: root.foreground
        opacity: 0.7
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        renderType: Text.NativeRendering
      }
    }

    PanelSlider {
      id: slider
      bar: root.bar
      width: parent.width
      integer: true
      step: 1
      minimum: 1
      maximum: root.maxIdleMinutes
      value: minutesRow.currentMinutes
      onReleased: function(v) {
        var next = Math.max(1, Math.round(v))
        if (next !== minutesRow.currentMinutes) minutesRow.committed(next)
      }
    }
  }
}
