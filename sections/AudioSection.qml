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

  // The same marks the bar's audio widget uses, chosen from what the device
  // says it is rather than from its name.
  function deviceGlyph(device, isInput) {
    var blob = (String(device.description) + " " + String(device.icon)).toLowerCase()
    if (blob.indexOf("headphone") !== -1 || blob.indexOf("headset") !== -1
      || blob.indexOf("earbud") !== -1 || blob.indexOf("airpod") !== -1) return "\uf025"
    if (isInput) return "\uf130"
    if (blob.indexOf("hdmi") !== -1 || blob.indexOf("displayport") !== -1) return "\uf108"
    if (blob.indexOf("bluetooth") !== -1) return "\uf294"
    return "\uf028"
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
        glyph: deviceGlyph(modelData, false)
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
        glyph: deviceGlyph(modelData, true)
        selected: modelData.default === true
        onPicked: app.run(["audio", "default", "input", modelData.name])
      }
    }
  }
}
