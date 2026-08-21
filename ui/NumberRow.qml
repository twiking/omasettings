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

  readonly property int shown: numberSlider.dragging ? Math.round(numberSlider.liveValue) : value

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
      value: numberRow.value
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
