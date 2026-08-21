import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

Column {
  id: group
  property string title: ""
  property string note: ""
  default property alias content: groupContent.data

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  Text {
    visible: group.title !== ""
    text: group.title
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }

  Text {
    visible: group.note !== ""
    width: group.width
    text: group.note
    wrapMode: Text.WordWrap
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
  }

  Column {
    id: groupContent
    width: group.width
    spacing: Style.space(12)
  }
}
