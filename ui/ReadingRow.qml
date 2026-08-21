import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A value the page reports but does not set.
SettingRow {
  id: readingRow
  property string value: ""

  Text {
    anchors.right: parent.right
    text: readingRow.value
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
  }
}
