import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A 0–1 value shown as a percentage.
SettingRow {
  id: percentRow
  property real value: 1
  signal committed(real next)

  // One step of the slider per key press, the same step dragging snaps to,
  // and each press builds on the last rather than on the value last read back.
  property real pending: value
  property bool stepping: false
  readonly property real effective: stepping ? pending : value
  readonly property real shown: percentSlider.dragging ? percentSlider.liveValue : effective

  onValueChanged: if (stepping && Math.abs(value - pending) < 0.001) stepping = false

  navKeys: [{ key: "\u2190\u2192", label: "Adjust" }]

  onNavStep: function(delta) {
    var base = percentRow.effective
    var next = Math.max(0, Math.min(1, Math.round((base + delta * 0.05) * 100) / 100))
    if (Math.abs(next - base) < 0.001) return
    percentRow.pending = next
    percentRow.stepping = true
    percentRow.committed(next)
  }

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
      value: Math.max(0, Math.min(1, percentRow.effective))
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
