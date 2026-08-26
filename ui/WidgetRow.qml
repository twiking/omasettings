import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A widget that is not in the bar: what to do with it first, then which one it
// is. The button leads rather than sitting out at the right edge, because on a
// wide screen a column of buttons an arm's length from the names they belong to
// is a column of buttons you aim at.
Item {
  id: widgetRow

  property string label: ""
  property string detail: ""
  property string buttonText: ""

  signal triggered()

  // Not a SettingRow: this is one of a list of things rather than one setting,
  // so the cursor is carried in rather than inherited.
  Local.NavCursor {
    id: nav
    anchors.fill: parent
    searchText: widgetRow.label + " " + widgetRow.detail
    navKeys: [{ key: "↵", label: widgetRow.buttonText }]
    onNavActivate: widgetRow.triggered()
  }

  visible: !nav.searchHidden
  width: parent ? parent.width : 0
  implicitHeight: Style.spacing.controlHeight

  Button {
    id: actionButton
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: widgetRow.buttonText
    bordered: true
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    fontFamily: Local.Palette.fontFamily
    fontSize: Style.font.caption
    onClicked: widgetRow.triggered()
  }

  Text {
    id: nameText
    anchors.left: actionButton.right
    anchors.leftMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    text: widgetRow.label
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
  }

  // Beside the name rather than across the page: what it is called and what it
  // is called in the config are one answer.
  Text {
    anchors.left: nameText.right
    anchors.leftMargin: Style.space(12)
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    text: widgetRow.detail
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
  }
}
