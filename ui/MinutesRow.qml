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
  readonly property int shownMinutes: minutesSlider.dragging ? Math.round(minutesSlider.liveValue) : currentMinutes

  // The slider runs 1..60 whole minutes, so a key press is a minute, and each
  // press builds on the last rather than on the value last read back.
  property int pending: currentMinutes
  property bool stepping: false
  readonly property int effective: stepping ? pending : currentMinutes

  onCurrentMinutesChanged: if (stepping && currentMinutes === pending) stepping = false

  onNavStep: function(delta) {
    var next = Math.max(1, Math.min(60, minutesRow.effective + delta))
    if (next === minutesRow.effective) return
    minutesRow.pending = next
    minutesRow.stepping = true
    minutesRow.committed(next)
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
      onReleased: function(v) {
        var next = Math.max(1, Math.round(v))
        if (next !== minutesRow.currentMinutes) minutesRow.committed(next)
      }
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
