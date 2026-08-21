import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  readonly property string device: app.keyboardDevice
  readonly property bool perDevice: device !== ""

  // Which keyboard the settings below apply to. Hyprland lets one device
  // depart from the global input settings; picking it here is what switches
  // these controls from writing `input` to writing `hl.device`.
  Ui.SettingGroup {
    visible: (app.devices.keyboards !== undefined ? app.devices.keyboards.length : 0) > 1

    Ui.PickerRow {
      label: "These settings apply to"
      value: device
      options: app.deviceOptions(app.devices.keyboards, "Every keyboard")
      onPicked: function(next) { app.keyboardDevice = next }
    }
  }

  Ui.SettingGroup {
    title: "Layout"
    note: "Add several layouts separated by commas, then set a shortcut to switch under Options."

    Ui.TextRow {
      label: "Layouts"
      placeholder: "us,se"
      value: String(perDevice ? app.deviceSetting(app.devices.keyboards, device, "kb_layout", app.hyprValue("kb-layout", ""))
                              : app.hyprValue("kb-layout", ""))
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "kb_layout", next, "keyboard")
        else app.setHypr("kb-layout", next)
      }
    }

    Ui.TextRow {
      label: "Variant"
      placeholder: "intl"
      value: String(perDevice ? app.deviceSetting(app.devices.keyboards, device, "kb_variant", app.hyprValue("kb-variant", ""))
                              : app.hyprValue("kb-variant", ""))
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "kb_variant", next, "keyboard")
        else app.setHypr("kb-variant", next)
      }
    }

    Ui.TextRow {
      label: "Options"
      placeholder: "compose:caps,grp:alts_toggle"
      value: String(perDevice ? app.deviceSetting(app.devices.keyboards, device, "kb_options", app.hyprValue("kb-options", ""))
                              : app.hyprValue("kb-options", ""))
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "kb_options", next, "keyboard")
        else app.setHypr("kb-options", next)
      }
    }
  }

  Ui.SettingGroup {
    title: "Repeat"

    Ui.NumberRow {
      label: "Repeat rate"
      suffix: "keys/s"
      value: Number(perDevice ? app.deviceSetting(app.devices.keyboards, device, "repeat_rate", app.hyprValue("repeat-rate", 25))
                              : app.hyprValue("repeat-rate", 25))
      from: 1
      to: 100
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "repeat_rate", next, "keyboard")
        else app.setHypr("repeat-rate", next)
      }
    }

    Ui.NumberRow {
      label: "Repeat delay"
      suffix: "ms"
      value: Number(perDevice ? app.deviceSetting(app.devices.keyboards, device, "repeat_delay", app.hyprValue("repeat-delay", 600))
                              : app.hyprValue("repeat-delay", 600))
      from: 100
      to: 1000
      step: 50
      onCommitted: function(next) {
        if (perDevice) app.setDevice(device, "repeat_delay", next, "keyboard")
        else app.setHypr("repeat-delay", next)
      }
    }

    Ui.SwitchRow {
      label: "Num lock on at login"
      checked: (perDevice ? app.deviceSetting(app.devices.keyboards, device, "numlock_by_default", app.hyprValue("numlock", false))
                          : app.hyprValue("numlock", false)) === true
      onRequested: function(next) {
        if (perDevice) app.setDevice(device, "numlock_by_default", next ? "true" : "false", "keyboard")
        else app.setHypr("numlock", next ? "true" : "false")
      }
    }
  }
}
