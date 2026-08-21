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
}
