import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A 0–1 value shown as a percentage.
SettingRow {
  id: percentRow
  property real value: 1
  signal committed(real next)

  // One step of the slider per key press, the same step dragging snaps to, and
  // each press builds on the last rather than on the value last read back —
  // which is also what the row shows until the state answers, so a dragged
  // slider stays where it was put instead of springing back for a moment.
  property real pending: value
  property bool stepping: false
  // What the state held when the write went out: an answer that is neither
  // that nor what was asked for is the system disagreeing, and the row stops
  // guessing.
  property real basis: value
  readonly property real effective: stepping ? pending : value
  readonly property real shown: percentSlider.dragging ? percentSlider.liveValue : effective

  onValueChanged: {
    if (!stepping) return
    if (Math.abs(value - pending) < 0.001 || Math.abs(value - basis) > 0.001) stepping = false
  }

  navKeys: [{ key: "\u2190\u2192", label: "Adjust" }]

  function commit(next) {
    var wanted = Math.max(0, Math.min(1, Math.round(next * 100) / 100))
    if (Math.abs(wanted - percentRow.effective) < 0.001) return
    percentRow.pending = wanted
    percentRow.basis = percentRow.value
    percentRow.stepping = true
    percentRow.committed(wanted)
  }

  onNavStep: function(delta) {
    percentRow.commit(percentRow.effective + delta * 0.05)
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
      onReleased: function(v) { percentRow.commit(v) }
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
