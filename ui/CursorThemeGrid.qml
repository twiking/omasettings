import QtQuick
import qs.Commons
import "." as Local

// Every cursor theme as a card of its four shapes (arrow, hand, text, busy),
// because a pointer is picked by how it looks, not by its folder name. Knows
// nothing about which setting it edits: a click or Space reports the theme.
Flow {
  id: grid

  property var themes: []
  property string current: ""
  signal picked(string themeId)

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  Repeater {
    model: grid.themes

    Rectangle {
      id: card
      required property var modelData
      readonly property bool inUse: grid.current === modelData.id

      width: Style.space(196)
      height: Style.space(104)
      radius: Style.cornerRadius
      color: mouse.containsMouse || nav.current ? Local.Palette.hover : "transparent"
      border.width: inUse ? 2 : 1
      border.color: inUse ? Local.Palette.accent : Local.Palette.hairline

      Local.NavCursor {
        id: nav
        anchors.fill: parent
        searchText: card.modelData.name
        navKeys: [{ key: "Space", label: "Use" }]
        onNavActivate: grid.picked(card.modelData.id)
      }

      visible: !nav.searchHidden

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.space(14)
        spacing: Style.space(10)

        Repeater {
          model: ["default", "pointer", "text", "wait"]

          Image {
            required property var modelData
            width: Style.space(30)
            height: Style.space(30)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: card.modelData.previews && card.modelData.previews[modelData]
              ? "file://" + card.modelData.previews[modelData] : ""
          }
        }
      }

      Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(10)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: card.modelData.name
        color: card.inUse ? Local.Palette.foreground : Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: card.inUse
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: grid.picked(card.modelData.id)
      }
    }
  }
}
