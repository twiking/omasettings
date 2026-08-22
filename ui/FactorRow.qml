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

  property real pending: value
  property bool stepping: false
  readonly property real effective: stepping ? pending : value
  readonly property real shown: factorSlider.dragging ? factorSlider.liveValue : effective

  onValueChanged: if (stepping && Math.abs(value - pending) < 0.001) stepping = false

  onNavStep: function(delta) {
    var base = factorRow.effective
    var next = Math.max(factorRow.minimum, Math.min(factorRow.maximum, base + delta * 0.05))
    next = Math.round(next * 20) / 20
    if (Math.abs(next - base) < 0.001) return
    factorRow.pending = next
    factorRow.stepping = true
    factorRow.committed(next.toFixed(2))
  }

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
      value: Math.max(factorRow.minimum, Math.min(factorRow.maximum, factorRow.effective))
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
