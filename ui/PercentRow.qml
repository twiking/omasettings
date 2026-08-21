import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A 0–1 value shown as a percentage.
SettingRow {
  id: percentRow
  property real value: 1
  signal committed(real next)

  readonly property real shown: percentSlider.dragging ? percentSlider.liveValue : value

  Row {
    width: parent.width
    spacing: Style.space(10)

    PanelSlider {
      id: percentSlider
      width: parent.width - percentReadout.width - Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      minimum: 0
      maximum: 1
      step: 0.05
      value: Math.max(0, Math.min(1, percentRow.value))
      enabled: percentRow.enabled
      onReleased: function(v) {
        var next = Math.round(v * 100) / 100
        if (next !== percentRow.value) percentRow.committed(next)
      }
    }

    Text {
      id: percentReadout
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(76)
      horizontalAlignment: Text.AlignRight
      text: Math.round(percentRow.shown * 100) + "%"
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
