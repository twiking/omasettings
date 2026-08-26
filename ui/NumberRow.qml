import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A whole number on a slider, written only when the drag ends.
SettingRow {
  id: numberRow
  property int value: 0
  property int from: 0
  property int to: 100
  property int step: 1
  property string suffix: ""
  signal committed(int next)

  // Keys step from where the last key left off, and so does the slider: a
  // write takes a refresh to come back, so what was asked for is what the row
  // shows until it does. Reading `value` in that window reads the number from
  // before the write, which springs the handle back for a moment.
  property int pending: value
  property bool stepping: false
  // What the state held when the write went out: an answer that is neither
  // that nor what was asked for is the system disagreeing, and the row stops
  // guessing rather than showing something that was refused.
  property int basis: value
  readonly property int effective: stepping ? pending : value
  readonly property int shown: numberSlider.dragging ? Math.round(numberSlider.liveValue) : effective

  onValueChanged: {
    if (!stepping) return
    if (value === pending || value !== basis) stepping = false
  }

  navKeys: [{ key: "\u2190\u2192", label: "Adjust" }]

  function commit(next) {
    var wanted = Math.max(numberRow.from, Math.min(numberRow.to, Math.round(next)))
    if (wanted === numberRow.effective) return
    numberRow.pending = wanted
    numberRow.basis = numberRow.value
    numberRow.stepping = true
    numberRow.committed(wanted)
  }

  onNavStep: function(delta) {
    numberRow.commit(numberRow.effective + delta * numberRow.step)
  }

  Row {
    width: parent.width
    spacing: Style.space(10)

    PanelSlider {
      id: numberSlider
      width: parent.width - readout.width - Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      integer: true
      step: numberRow.step
      minimum: numberRow.from
      maximum: numberRow.to
      value: numberRow.effective
      enabled: numberRow.enabled
      onReleased: function(v) { numberRow.commit(v) }
    }

    Text {
      id: readout
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(76)
      horizontalAlignment: Text.AlignRight
      text: numberRow.shown + (numberRow.suffix !== "" ? " " + numberRow.suffix : "")
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
