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
    title: "Placement"

    Ui.PickerRow {
      label: "Position"
      value: app.barState.position !== undefined ? String(app.barState.position) : "top"
      options: ["top", "bottom", "left", "right"]
      onPicked: function(next) { app.set("bar-position", next) }
    }

    Ui.SwitchRow {
      label: "Transparent"
      description: "Drops the bar's own background so the wallpaper shows through."
      checked: app.barState.transparent === true
      onRequested: function(next) { app.set("bar-transparent", next ? "true" : "false") }
    }

    Ui.PickerRow {
      label: "Centered widget"
      description: "The widget the centre section is anchored on."
      value: app.barState.centerAnchor !== undefined ? String(app.barState.centerAnchor) : ""
      options: app.barWidgetIds()
      searchable: true
      onPicked: function(next) { app.set("bar-center-anchor", next) }
    }
  }
}
