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

  // Keys step from where the last key left off. A write takes a refresh to
  // come back, and two presses inside that window would otherwise compute the
  // same number twice and the second would be swallowed.
  property int pending: value
  property bool stepping: false
  readonly property int effective: stepping ? pending : value
  readonly property int shown: numberSlider.dragging ? Math.round(numberSlider.liveValue) : effective

  onValueChanged: if (stepping && value === pending) stepping = false

  onNavStep: function(delta) {
    var base = numberRow.effective
    var next = Math.max(numberRow.from, Math.min(numberRow.to, base + delta * numberRow.step))
    if (next === base) return
    numberRow.pending = next
    numberRow.stepping = true
    numberRow.committed(next)
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
      onReleased: function(v) {
        var next = Math.round(v)
        if (next !== numberRow.value) numberRow.committed(next)
      }
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
