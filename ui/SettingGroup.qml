import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

Column {
  id: group
  property string title: ""
  property string note: ""
  // Everything under a heading is stepped in from it, so which rows belong to
  // which heading is a matter of looking rather than of reading.
  property real indent: title !== "" ? Style.space(14) : 0
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
    x: group.indent
    width: group.width - group.indent
    text: group.note
    wrapMode: Text.WordWrap
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
  }

  Column {
    id: groupContent
    x: group.indent
    width: group.width - group.indent
    spacing: Style.space(12)
  }
}
