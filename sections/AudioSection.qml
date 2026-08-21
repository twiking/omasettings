import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var audio: app.audio
  readonly property var outputs: audio.outputs !== undefined ? audio.outputs : []
  readonly property var inputs: audio.inputs !== undefined ? audio.inputs : []

  function selected(list) {
    for (var i = 0; i < list.length; i++)
      if (list[i].default === true) return list[i]
    return null
  }

  readonly property var currentOutput: selected(outputs)
  readonly property var currentInput: selected(inputs)

  Ui.SettingGroup {
    title: "Output"

    Ui.PercentRow {
      label: "Volume"
      value: currentOutput ? Number(currentOutput.volume) / 100 : 0
      onCommitted: function(next) { app.run(["audio", "volume", "output", String(Math.round(next * 100))]) }
    }

    Ui.SwitchRow {
      label: "Muted"
      checked: currentOutput ? currentOutput.muted === true : false
      onRequested: function(next) { app.run(["audio", "mute", "output", next ? "on" : "off"]) }
    }

    Repeater {
      model: outputs
      delegate: Ui.PickableRow {
        required property var modelData
        width: parent.width
        label: modelData.description
        detail: modelData.volume + "%"
        selected: modelData.default === true
        onPicked: app.run(["audio", "default", "output", modelData.name])
      }
    }
  }

  Ui.SettingGroup {
    title: "Input"

    Ui.PercentRow {
      label: "Volume"
      value: currentInput ? Number(currentInput.volume) / 100 : 0
      onCommitted: function(next) { app.run(["audio", "volume", "input", String(Math.round(next * 100))]) }
    }

    Ui.SwitchRow {
      label: "Muted"
      checked: currentInput ? currentInput.muted === true : false
      onRequested: function(next) { app.run(["audio", "mute", "input", next ? "on" : "off"]) }
    }

    Repeater {
      model: inputs
      delegate: Ui.PickableRow {
        required property var modelData
        width: parent.width
        label: modelData.description
        selected: modelData.default === true
        onPicked: app.run(["audio", "default", "input", modelData.name])
      }
    }
  }
}
