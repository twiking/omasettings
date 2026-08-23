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

  // A group whose rows have all been filtered away goes with them, heading
  // and all, or the page fills with headings over nothing.
  property var nav: null
  Component.onCompleted: {
    var node = group.parent
    while (node) {
      if (node.searching !== undefined) { group.nav = node; break }
      if (node.app !== undefined && node.app !== null && node.app.searching !== undefined) {
        group.nav = node.app
        break
      }
      node = node.parent
    }
  }

  readonly property bool searchEmpty: {
    if (!group.nav || group.nav.searching !== true) return false
    var kids = groupContent.children
    for (var i = 0; i < kids.length; i++)
      if (kids[i].visible === true) return false
    return true
  }

  visible: !searchEmpty

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
