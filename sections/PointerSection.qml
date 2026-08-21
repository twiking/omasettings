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
    title: "Pointer"

    Ui.PercentRow {
      label: "Sensitivity"
      description: "How far the pointer travels for the same hand movement."
      value: (Number(app.hyprValue("sensitivity", 0)) + 1) / 2
      onCommitted: function(next) { app.setHypr("sensitivity", (next * 2 - 1).toFixed(2)) }
    }

    Ui.PickerRow {
      label: "Acceleration"
      value: String(app.hyprValue("accel-profile", ""))
      options: [
        { value: "", label: "Default (adaptive)" },
        { value: "flat", label: "Flat — no acceleration" },
        { value: "adaptive", label: "Adaptive" }
      ]
      onPicked: function(next) { app.setHypr("accel-profile", next) }
    }

    Ui.PickerRow {
      label: "Focus follows mouse"
      value: String(app.hyprValue("follow-mouse", 1))
      options: [
        { value: "0", label: "Off — click to focus" },
        { value: "1", label: "On" },
        { value: "2", label: "On, but keyboard stays" },
        { value: "3", label: "On, without raising" }
      ]
      onPicked: function(next) { app.setHypr("follow-mouse", next) }
    }
  }

  Ui.SettingGroup {
    title: "Touchpad"

    Ui.SwitchRow {
      label: "Natural scrolling"
      checked: app.hyprValue("natural-scroll", false) === true
      onRequested: function(next) { app.setHypr("natural-scroll", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Tap to click"
      checked: app.hyprValue("tap-to-click", true) === true
      onRequested: function(next) { app.setHypr("tap-to-click", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Two-finger right click"
      description: "Off uses the lower-right corner instead."
      checked: app.hyprValue("clickfinger", false) === true
      onRequested: function(next) { app.setHypr("clickfinger", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Disable while typing"
      checked: app.hyprValue("disable-while-typing", true) === true
      onRequested: function(next) { app.setHypr("disable-while-typing", next ? "true" : "false") }
    }

    Ui.FactorRow {
      label: "Scroll speed"
      value: Number(app.hyprValue("scroll-factor", 1))
      onCommitted: function(next) { app.setHypr("scroll-factor", next) }
    }
  }

  // Every pointer that can depart from the settings above gets its own group,
  // so what a control writes is never in doubt: the ones under a device name
  // write that device, the ones above write every device.
  //
  // A device shows the value in force for it — what was set here, else what
  // the user's own config gives it, else the global setting above.

  // A device is only worth a group of its own once it departs from the
  // settings above. The rest are one dropdown away, so a page with five
  // devices and no overrides stays a page about pointers, not a list of
  // hardware.
  property var opened: []

  function isCustomised(device) {
    return Object.keys(device.settings || ({})).length > 0
      || Object.keys(device.configured || ({})).length > 0
      || opened.indexOf(String(device.name)) !== -1
  }

  readonly property var allDevices: app.devices.pointers !== undefined ? app.devices.pointers : []
  readonly property var customised: allDevices.filter(isCustomised)
  readonly property var untouched: allDevices.filter(function(device) { return !isCustomised(device) })

  function openDevice(name) {
    var next = opened.slice()
    next.push(String(name))
    opened = next
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
      title: name + (modelData.connected === false ? "  (not connected)" : "")
      note: Object.keys(configured).length > 0 && !ours
        ? "Set in your own Hyprland config."
        : ""

      Ui.PercentRow {
        label: "Sensitivity"
        value: (Number(inForce("sensitivity", app.hyprValue("sensitivity", 0))) + 1) / 2
        onCommitted: function(next) { app.setDevice(name, "sensitivity", (next * 2 - 1).toFixed(2), "pointer") }
      }

      Ui.PickerRow {
        label: "Acceleration"
        value: String(inForce("accel_profile", app.hyprValue("accel-profile", "")))
        options: [
          { value: "", label: "Default (adaptive)" },
          { value: "flat", label: "Flat — no acceleration" },
          { value: "adaptive", label: "Adaptive" }
        ]
        onPicked: function(next) { app.setDevice(name, "accel_profile", next, "pointer") }
      }

      Ui.SwitchRow {
        label: "Natural scrolling"
        checked: inForce("natural_scroll", app.hyprValue("natural-scroll", false)) === true
        onRequested: function(next) { app.setDevice(name, "natural_scroll", next ? "true" : "false", "pointer") }
      }

      Ui.SwitchRow {
        label: "Left handed"
        checked: inForce("left_handed", false) === true
        onRequested: function(next) { app.setDevice(name, "left_handed", next ? "true" : "false", "pointer") }
      }

      Ui.FactorRow {
        label: "Scroll speed"
        minimum: 0.1
        maximum: 3
        value: Number(inForce("scroll_factor", app.hyprValue("scroll-factor", 1)))
        onCommitted: function(next) { app.setDevice(name, "scroll_factor", next, "pointer") }
      }

      Ui.ActionRow {
        label: "Follow the settings above"
        visible: ours
        buttonText: "Clear"
        onTriggered: app.clearDevice(name)
      }
    }
  }

  Ui.SettingGroup {
    visible: untouched.length > 0

    Ui.PickerRow {
      label: "Settings for one pointer"
      description: "Give a single pointer its own settings, apart from the ones above."
      value: ""
      options: [{ value: "", label: "Pick a pointer…" }].concat(untouched.map(function(device) {
        return {
          value: String(device.name),
          label: String(device.name) + (device.connected === false ? " (not connected)" : "")
        }
      }))
      onPicked: function(next) { if (next !== "") openDevice(next) }
    }
  }
}
