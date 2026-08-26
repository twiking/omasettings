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

  // What was asked for is what the row shows until the state answers. A write
  // takes a refresh to come back, and reading `value` in the meantime is
  // reading the number from before the write — which is why a dragged slider
  // sprang back to where it started and then jumped to where it was put.
  property real pending: value
  property bool stepping: false
  // The value the state held when the write went out. An answer that is
  // neither that nor what was asked for is the system disagreeing — Hyprland
  // snaps a scale it cannot do exactly — and the row stops guessing rather
  // than showing a number the screen is not using.
  property real basis: value
  readonly property real effective: stepping ? pending : value
  readonly property real shown: factorSlider.dragging ? factorSlider.liveValue : effective

  onValueChanged: {
    if (!stepping) return
    if (Math.abs(value - pending) < 0.001 || Math.abs(value - basis) > 0.001) stepping = false
  }

  navKeys: [{ key: "\u2190\u2192", label: "Adjust" }]

  // One door for the keys and the slider: an optimistic value the drag did not
  // take part in is the bug this exists to fix.
  function commit(next) {
    var wanted = Math.max(factorRow.minimum, Math.min(factorRow.maximum, Math.round(next * 20) / 20))
    if (Math.abs(wanted - factorRow.effective) < 0.001) return
    factorRow.pending = wanted
    factorRow.basis = factorRow.value
    factorRow.stepping = true
    factorRow.committed(wanted.toFixed(2))
  }

  onNavStep: function(delta) {
    factorRow.commit(factorRow.effective + delta * 0.05)
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
      onReleased: function(v) { factorRow.commit(v) }
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
