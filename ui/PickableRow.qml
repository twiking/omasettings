import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One thing in a list you pick from: a name, an optional detail, and the
// selected one marked rather than described. The whole row is the target.
Item {
  id: pickableRow

  property string label: ""
  property string glyph: ""
  property string detail: ""
  property bool selected: false

  signal picked()

  // A list of things to choose between: the cursor picks one.
  Local.NavCursor {
    id: nav
    anchors.fill: parent
    searchText: pickableRow.label + " " + pickableRow.detail
    navKeys: [{ key: "Space", label: "Select" }]
    onNavActivate: pickableRow.picked()
  }

  visible: !nav.searchHidden
  width: parent ? parent.width : 0
  implicitHeight: Style.spacing.controlHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: pickableRow.selected
      ? Qt.rgba(Local.Palette.accent.r, Local.Palette.accent.g, Local.Palette.accent.b, 0.14)
      : (rowMouse.containsMouse ? Local.Palette.hover : "transparent")
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pickableRow.picked()
  }

  Text {
    id: glyphText
    anchors.left: parent.left
    anchors.leftMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    visible: pickableRow.glyph !== ""
    text: pickableRow.glyph
    color: pickableRow.selected ? Local.Palette.accent : Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
    width: visible ? Style.space(20) : 0
  }

  Text {
    anchors.left: glyphText.visible ? glyphText.right : parent.left
    anchors.leftMargin: Style.space(10)
    anchors.right: detailText.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    text: pickableRow.label
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
    font.bold: pickableRow.selected
  }

  Text {
    id: detailText
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    text: pickableRow.detail
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
  }
}
