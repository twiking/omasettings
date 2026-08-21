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
    title: "Installed plugins"
    note: "A bar widget also needs a slot in the bar before it shows up there."

    Repeater {
      model: app.plugins
      delegate: Ui.SwitchRow {
        required property var modelData
        width: parent.width
        label: modelData.name
        description: modelData.id + (modelData.firstParty ? " · built in" : "")
        checked: modelData.enabled === true
        onRequested: function(next) { app.run(["plugin", next ? "enable" : "disable", modelData.id]) }
      }
    }
  }
}
