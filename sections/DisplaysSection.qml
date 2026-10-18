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

      // The identity a setting is written against: the display's own
      // description where it has one, so what is set here stays with the screen
      // rather than with the socket it happened to be in. `label` is what to
      // call it, since the identity itself reads as machinery.
      readonly property string name: String(modelData.name)
      readonly property string label: String(modelData.label || modelData.name)
      readonly property bool connected: modelData.connected !== false
      readonly property var settings: modelData.settings || ({})
      readonly property var configured: modelData.configured || ({})
      readonly property var modes: modelData.modes || []

      width: parent.width
      title: label + (connected ? "" : "  (not connected)")
      note: !connected
        ? "Kept for the next time this display is plugged in."
        : Object.keys(configured).length > 0 && Object.keys(settings).length === 0
          ? "Set in your own Hyprland config."
          : ""

      // The title says which screen this is. The connector is the part you
      // cannot tell from that, and the part that changes between docks — so it
      // is shown, and nothing is written against it.
      Ui.ReadingRow {
        label: "Connector"
        visible: connected && String(modelData.output || "") !== ""
        value: String(modelData.output || "")
      }

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
        minimum: 0.5
        maximum: 3
        value: Number(modelData.scale)
        onCommitted: function(next) { app.set("monitor:" + name + ":scale", next) }
        changed: app.isChanged("monitor:" + name + ":scale")
        onResetRequested: app.resetSetting("monitor:" + name + ":scale")
      }

      // Four square turns, side by side rather than in a dropdown — the same
      // reasoning as the resolution list, in reverse: there are only ever four
      // of these, so opening a menu to find them would be the wasted click.
      Ui.ChoiceRow {
        label: "Rotation"
        visible: connected
        options: [
          { value: "0", label: "Normal" },
          { value: "1", label: "90°" },
          { value: "2", label: "180°" },
          { value: "3", label: "270°" }
        ]
        value: String(modelData.transform !== undefined ? modelData.transform : 0)
        onPicked: function(next) { app.set("monitor:" + name + ":transform", next) }
        changed: app.isChanged("monitor:" + name + ":transform")
        onResetRequested: app.resetSetting("monitor:" + name + ":transform")
      }

      // Easy approach alligning all monitors relative to another
      Ui.PickerRow {
        label: "Position"
        visible: connected && alignOptions().length > 0
        description: "Placed against another connected display, edge to edge."
        value: String(modelData.position || "auto")
        options: alignOptions()
        onPicked: function(next) { app.set("monitor:" + name + ":position", next) }
        changed: app.isChanged("monitor:" + name + ":position")
        onResetRequested: app.resetSetting("monitor:" + name + ":position")
      }

      // A display's footprint on the desktop: its native pixels, turned
      // sideways by a 90/270 rotation, then shrunk by its scale — the same
      // arithmetic Hyprland itself does to lay it out, done here so Align can
      // place a screen against an edge it hasn't rendered yet.
      function logicalFootprint(m) {
        var w = Number(m.width) || 0, h = Number(m.height) || 0
        var scale = Number(m.scale) || 1
        var turned = (Number(m.transform) % 2) === 1
        return {
          w: Math.round((turned ? h : w) / scale),
          h: Math.round((turned ? w : h) / scale)
        }
      }

      function alignOptions() {
        var mine = logicalFootprint(modelData)
        var out = []
        for (var i = 0; i < displays.length; i++) {
          var other = displays[i]
          // A disabled display still reports x: 0, y: 0 — it just isn't
          // showing anything there, so aligning against it would overlap
          // whatever else is on screen.
          if (!other || other.name === name || other.connected === false || other.disabled === true) continue
          if (other.x === undefined || other.x === null || other.y === undefined || other.y === null) continue
          var ox = Number(other.x), oy = Number(other.y)
          var theirs = logicalFootprint(other)
          var label = String(other.label || other.name)
          out.push({ value: (ox - mine.w) + "x" + oy, label: "Left of " + label })
          out.push({ value: (ox + theirs.w) + "x" + oy, label: "Right of " + label })
          out.push({ value: ox + "x" + (oy - mine.h), label: "Above " + label })
          out.push({ value: ox + "x" + (oy + theirs.h), label: "Below " + label })
        }
        // Nothing to align against yet — an "Automatic" option would sit
        // alone with no other display to place against, so the whole row
        // stays hidden until there is a real choice to make.
        if (out.length === 0) return out
        // Handing placement back to Hyprland is a choice too, and the one
        // Reset should be able to land on — so it goes in the list rather
        // than living only behind Backspace.
        out = [{ value: "auto", label: "Automatic" }].concat(out)
        // The position in force may not be one Align would offer — it could
        // be centred, or hand-written to an odd number — and a picker showing
        // none of its options selected reads as unset when it is anything but.
        var picked = String(modelData.position || "")
        if (picked !== "" && picked !== "auto" && !out.some(function(o) { return o.value === picked })) {
          var xy = picked.split("x")
          out = [{ value: picked, label: xy.length === 2 ? xy[0] + ", " + xy[1] : picked }].concat(out)
        }
        return out
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

  // Setting up a display that is not plugged in: nothing can list it, so it is
  // typed. Its model is the thing to type — that is what still names this
  // screen at the next desk, where the connector only says which socket was
  // free. A connector name is taken too, and becomes the model's identity the
  // first time the display is actually seen.
  Ui.SettingGroup {
    title: "Another display"
    visible: !searchEmpty

    Ui.TextRow {
      label: "Set up a display that is not connected"
      // No real model as the example: a placeholder naming an actual monitor
      // reads as a value this window detected rather than as an illustration.
      description: "Its model, as hyprctl monitors all prints it under description, or a connector name like DP-3. What you set is kept for when it arrives."
      placeholder: "Model, or a connector like DP-3"
      value: ""
      buttonText: "Add Display"
      clearOnCommit: true
      onCommitted: function(next) { app.set("monitor-remember", next) }
    }
  }
}
