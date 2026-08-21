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
    title: "Scale"

    Repeater {
      model: app.monitors
      delegate: Ui.FactorRow {
        required property var modelData
        width: parent.width
        label: modelData.name
        description: modelData.width + "×" + modelData.height + " @ " + modelData.refreshRate + "Hz"
        minimum: 0.5
        maximum: 3
        value: Number(modelData.scale)
        onCommitted: function(next) { app.set("monitor-scale", modelData.name + "=" + next) }
      }
    }
  }
}
