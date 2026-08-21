import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  Ui.SettingGroup {
    title: "Layout"
    note: "Add several layouts separated by commas, then set a shortcut to switch under Options."

    Ui.TextRow {
      label: "Layouts"
      placeholder: "us,se"
      value: String(app.hyprValue("kb-layout", ""))
      onCommitted: function(next) { app.setHypr("kb-layout", next) }
    }

    Ui.TextRow {
      label: "Variant"
      placeholder: "intl"
      value: String(app.hyprValue("kb-variant", ""))
      onCommitted: function(next) { app.setHypr("kb-variant", next) }
    }

    Ui.TextRow {
      label: "Options"
      placeholder: "compose:caps,grp:alts_toggle"
      value: String(app.hyprValue("kb-options", ""))
      onCommitted: function(next) { app.setHypr("kb-options", next) }
    }
  }

  Ui.SettingGroup {
    title: "Repeat"

    Ui.NumberRow {
      label: "Repeat rate"
      suffix: "keys/s"
      value: app.hyprValue("repeat-rate", 25)
      from: 1
      to: 100
      onCommitted: function(next) { app.setHypr("repeat-rate", next) }
    }

    Ui.NumberRow {
      label: "Repeat delay"
      suffix: "ms"
      value: app.hyprValue("repeat-delay", 600)
      from: 100
      to: 1000
      step: 50
      onCommitted: function(next) { app.setHypr("repeat-delay", next) }
    }

    Ui.SwitchRow {
      label: "Num lock on at login"
      checked: app.hyprValue("numlock", false) === true
      onRequested: function(next) { app.setHypr("numlock", next ? "true" : "false") }
    }
  }

  // One group per keyboard, for the ones that should not follow the settings
  // above — an external board on a different layout, say.

  // A device is only worth a group of its own once it departs from the
  // settings above. The rest are one dropdown away, so a page with five
  // devices and no overrides stays a page about keyboards, not a list of
  // hardware.
  property var opened: []

  function isCustomised(device) {
    return Object.keys(device.settings || ({})).length > 0
      || Object.keys(device.configured || ({})).length > 0
      || opened.indexOf(String(device.name)) !== -1
  }

  readonly property var allDevices: app.devices.keyboards !== undefined ? app.devices.keyboards : []
  readonly property var customised: allDevices.filter(isCustomised)
  readonly property var untouched: allDevices.filter(function(device) { return !isCustomised(device) })

  function openDevice(name) {
    var next = opened.slice()
    next.push(String(name))
    opened = next
  }

  // Closing a group that was only opened to look at it: nothing was written,
  // so nothing has to be removed.
  function closeDevice(name) {
    opened = opened.filter(function(entry) { return entry !== String(name) })
  }

  Repeater {
    model: customised

    delegate: Ui.SettingGroup {
      required property var modelData

      readonly property string name: String(modelData.name)
      readonly property var settings: modelData.settings || ({})
      readonly property var configured: modelData.configured || ({})
      readonly property bool ours: Object.keys(settings).length > 0

      // Not called `value`: inside a row, that name resolves to the row's own
      // value property rather than to this.
      function inForce(key, fallback) {
        if (settings[key] !== undefined && settings[key] !== null) return settings[key]
        if (configured[key] !== undefined && configured[key] !== null) return configured[key]
        return fallback
      }

      width: parent.width
      // Named as a device so the heading cannot be mistaken for another
      // group of settings.
      title: "Device: " + name + (modelData.connected === false ? "  (not connected)" : "")
      note: Object.keys(configured).length > 0 && !ours
        ? "Set in your own Hyprland config."
        : ""

      Ui.TextRow {
        label: "Layouts"
        placeholder: String(app.hyprValue("kb-layout", ""))
        value: String(inForce("kb_layout", app.hyprValue("kb-layout", "")))
        onCommitted: function(next) { app.setDevice(name, "kb_layout", next, "keyboard") }
      }

      Ui.TextRow {
        label: "Variant"
        value: String(inForce("kb_variant", app.hyprValue("kb-variant", "")))
        onCommitted: function(next) { app.setDevice(name, "kb_variant", next, "keyboard") }
      }

      Ui.TextRow {
        label: "Options"
        value: String(inForce("kb_options", app.hyprValue("kb-options", "")))
        onCommitted: function(next) { app.setDevice(name, "kb_options", next, "keyboard") }
      }

      Ui.NumberRow {
        label: "Repeat rate"
        suffix: "keys/s"
        from: 1
        to: 100
        value: Number(inForce("repeat_rate", app.hyprValue("repeat-rate", 25)))
        onCommitted: function(next) { app.setDevice(name, "repeat_rate", next, "keyboard") }
      }

      Ui.NumberRow {
        label: "Repeat delay"
        suffix: "ms"
        from: 100
        to: 1000
        step: 50
        value: Number(inForce("repeat_delay", app.hyprValue("repeat-delay", 600)))
        onCommitted: function(next) { app.setDevice(name, "repeat_delay", next, "keyboard") }
      }

      // No label: what the button removes is the group it sits in, and how
      // that is undone in a config file is not the reader's problem.
      Ui.ActionRow {
        readonly property bool theirs: Object.keys(configured).length > 0

        buttonText: "Remove Device"
        onTriggered: {
          if (theirs) app.removeDevice(name)
          else if (ours) app.clearDevice(name)
          else closeDevice(name)
        }
      }
    }
  }

  Ui.SettingGroup {
    visible: untouched.length > 0

    Ui.PickerRow {
      label: "Settings for one keyboard"
      description: "Give a single keyboard its own settings, apart from the ones above."
      value: ""
      options: [{ value: "", label: "Pick a keyboard…" }].concat(untouched.map(function(device) {
        return {
          value: String(device.name),
          label: String(device.name) + (device.connected === false ? " (not connected)" : "")
        }
      }))
      onPicked: function(next) { if (next !== "") openDevice(next) }
    }
  }
}
