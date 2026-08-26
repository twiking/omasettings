import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A duration stored in seconds but edited in whole minutes.
SettingRow {
  id: minutesRow
  property int seconds: 0
  signal committed(int mins)

  readonly property int currentMinutes: Math.max(1, Math.round(seconds / 60))
  readonly property int shownMinutes: minutesSlider.dragging ? Math.round(minutesSlider.liveValue) : effective

  // The slider runs 1..60 whole minutes, so a key press is a minute, and each
  // press builds on the last rather than on the value last read back — as does
  // a drag, which is what keeps the handle where it was put while the write
  // makes its way back through the state.
  property int pending: currentMinutes
  property bool stepping: false
  // What the state held when the write went out: an answer that is neither
  // that nor what was asked for is the system disagreeing, and the row stops
  // guessing.
  property int basis: currentMinutes
  readonly property int effective: stepping ? pending : currentMinutes

  onCurrentMinutesChanged: {
    if (!stepping) return
    if (currentMinutes === pending || currentMinutes !== basis) stepping = false
  }

  navKeys: [{ key: "\u2190\u2192", label: "Adjust" }]

  function commit(next) {
    var wanted = Math.max(1, Math.min(60, Math.round(next)))
    if (wanted === minutesRow.effective) return
    minutesRow.pending = wanted
    minutesRow.basis = minutesRow.currentMinutes
    minutesRow.stepping = true
    minutesRow.committed(wanted)
  }

  onNavStep: function(delta) {
    minutesRow.commit(minutesRow.effective + delta)
  }

  Row {
    width: parent.width
    spacing: Style.space(10)

    PanelSlider {
      id: minutesSlider
      width: parent.width - minutesReadout.width - Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      integer: true
      step: 1
      minimum: 1
      maximum: 60
      value: minutesRow.effective
      onReleased: function(v) { minutesRow.commit(v) }
    }

    Text {
      id: minutesReadout
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(76)
      horizontalAlignment: Text.AlignRight
      text: minutesRow.shownMinutes + (minutesRow.shownMinutes === 1 ? " min" : " mins")
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
