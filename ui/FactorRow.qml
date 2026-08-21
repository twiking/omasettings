import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A multiplier such as a display scale or scroll speed, in steps of 0.05.
SettingRow {
  id: factorRow
  property real value: 1
  property real minimum: 0.1
  property real maximum: 3
  signal committed(string next)

  readonly property real shown: factorSlider.dragging ? factorSlider.liveValue : value

  Row {
    width: parent.width
    spacing: Style.space(10)

    PanelSlider {
      id: factorSlider
      width: parent.width - factorReadout.width - Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      minimum: factorRow.minimum
      maximum: factorRow.maximum
      step: 0.05
      value: Math.max(factorRow.minimum, Math.min(factorRow.maximum, factorRow.value))
      enabled: factorRow.enabled
      onReleased: function(v) {
        var next = (Math.round(v * 20) / 20).toFixed(2)
        if (Number(next) !== factorRow.value) factorRow.committed(next)
      }
    }

    Text {
      id: factorReadout
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(76)
      horizontalAlignment: Text.AlignRight
      text: "×" + factorRow.shown.toFixed(2)
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
