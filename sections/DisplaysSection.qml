import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  // A display you own is not always plugged in, and Hyprland matches its
  // monitor rules again every time it is: a display can be set up here before
  // the cable is in, and keeps what it was given.
  readonly property var displays: app.monitors !== undefined ? app.monitors : []

  // Every display gets its own group, titled with its name, so what a control
  // writes is never in doubt. A display carries its resolution and its scale;
  // both mean nothing without saying which screen they are about.
  Repeater {
    model: displays

    delegate: Ui.SettingGroup {
      required property var modelData

      readonly property string name: String(modelData.name)
      readonly property bool connected: modelData.connected !== false
      readonly property var settings: modelData.settings || ({})
      readonly property var configured: modelData.configured || ({})
      readonly property var modes: modelData.modes || []

      width: parent.width
      title: name + (connected ? "" : "  (not connected)")
      note: !connected
        ? "Kept for the next time this display is plugged in."
        : Object.keys(configured).length > 0 && Object.keys(settings).length === 0
          ? "Set in your own Hyprland config."
          : String(modelData.description || "")

      Ui.PickerRow {
        label: "Resolution"
        // A display that is not here reports no modes, so what it was given is
        // the only option there is to show.
        description: connected ? "" : "Applied when the display comes back."
        value: String(modelData.mode)
        options: {
          var listed = modes.map(function(mode) { return { value: mode, label: readable(mode) } })
          var picked = String(modelData.mode)
          if (picked !== "preferred" && !modes.some(function(mode) { return mode === picked }))
            listed = [{ value: picked, label: readable(picked) }].concat(listed)
          return [{ value: "preferred", label: "Preferred (what the display asks for)" }].concat(listed)
        }
        onPicked: function(next) { app.set("monitor:" + name + ":mode", next) }
        changed: app.isChanged("monitor:" + name + ":mode")
        onResetRequested: app.resetSetting("monitor:" + name + ":mode")
      }

      Ui.FactorRow {
        label: "Scale"
        description: "How large everything on this display is drawn."
        minimum: 0.5
        maximum: 3
        value: Number(modelData.scale)
        onCommitted: function(next) { app.set("monitor:" + name + ":scale", next) }
        changed: app.isChanged("monitor:" + name + ":scale")
        onResetRequested: app.resetSetting("monitor:" + name + ":scale")
      }

      // Only once there is something to forget: for a display sitting in front
      // of you with nothing set, there is nothing this would undo.
      Ui.ActionRow {
        visible: Object.keys(settings).length > 0 || !connected
        buttonText: "Forget Display"
        onTriggered: app.set("monitor-forget", name)
      }

      // "3840x2160@60.00" is how Hyprland says it; nobody reads it that way.
      function readable(mode) {
        if (mode === "preferred" || mode === "") return "Preferred"
        var parts = String(mode).split("@")
        var size = parts[0].split("x")
        return size[0] + "×" + size[1]
          + (parts.length > 1 ? "  ·  " + Math.round(Number(parts[1])) + " Hz" : "")
      }
    }
  }

  // Setting up a display that is not plugged in: nothing can list it, so its
  // name is typed. Hyprland calls them after the socket they arrive on, which
  // is what `hyprctl monitors all` prints and what goes here.
  Ui.SettingGroup {
    title: "Another display"
    visible: !searchEmpty

    Ui.TextRow {
      label: "Set up a display that is not connected"
      description: "Its connector name, like DP-3 or HDMI-A-1. What you set is kept for when it arrives."
      placeholder: "DP-3"
      value: ""
      buttonText: "Add Display"
      clearOnCommit: true
      onCommitted: function(next) { app.set("monitor-remember", next) }
    }
  }
}
