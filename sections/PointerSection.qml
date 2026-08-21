import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  readonly property string device: app.pointerDevice
  readonly property bool perDevice: device !== ""

  // Which pointer the settings below apply to: a trackball that needs its own
  // sensitivity should not drag the touchpad along with it.
  Ui.SettingGroup {
    visible: (app.devices.pointers !== undefined ? app.devices.pointers.length : 0) > 1

    Ui.PickerRow {
      label: "These settings apply to"
      value: device
      options: app.deviceOptions(app.devices.pointers, "Every pointer")
      onPicked: function(next) { app.pointerDevice = next }
    }
  }

  Ui.SettingGroup {
    title: "Pointer"

    Ui.PercentRow {
      label: "Sensitivity"
      description: "How far the pointer travels for the same hand movement."
      value: (Number(perDevice ? app.deviceSetting(app.devices.pointers, device, "sensitivity", app.hyprValue("sensitivity", 0))
                               : app.hyprValue("sensitivity", 0)) + 1) / 2
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "sensitivity", (next * 2 - 1).toFixed(2), "pointer")
        else app.setHypr("sensitivity", (next * 2 - 1).toFixed(2))
      }
    }

    Ui.PickerRow {
      label: "Acceleration"
      value: String(perDevice ? app.deviceSetting(app.devices.pointers, device, "accel_profile", app.hyprValue("accel-profile", ""))
                              : app.hyprValue("accel-profile", ""))
      options: [
        { value: "", label: "Default (adaptive)" },
        { value: "flat", label: "Flat — no acceleration" },
        { value: "adaptive", label: "Adaptive" }
      ]
      onPicked: function(next) {
        if (perDevice) app.setDevice(device, "accel_profile", next, "pointer")
        else app.setHypr("accel-profile", next)
      }
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
      checked: (perDevice ? app.deviceSetting(app.devices.pointers, device, "natural_scroll", app.hyprValue("natural-scroll", false))
                          : app.hyprValue("natural-scroll", false)) === true
      onRequested: function(next) {
        if (perDevice) app.setDevice(device, "natural_scroll", next ? "true" : "false", "pointer")
        else app.setHypr("natural-scroll", next ? "true" : "false")
      }
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
      value: Number(perDevice ? app.deviceSetting(app.devices.pointers, device, "scroll_factor", app.hyprValue("scroll-factor", 1))
                              : app.hyprValue("scroll-factor", 1))
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "scroll_factor", next, "pointer")
        else app.setHypr("scroll-factor", next)
      }
    }
  }
}
