import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// Label on the left, control on the right — the shape every row shares.
Item {
  id: settingRow
  property string label: ""
  property string description: ""
  // Set by pages whose settings this window owns: whether the value on screen
  // was chosen here, and how to hand it back. A row that says nothing shows
  // nothing, so rows backed by live system state stay unmarked.
  property bool changed: false
  signal resetRequested()
  default property alias control: controlHolder.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(labelColumn.implicitHeight, controlHolder.implicitHeight)
  opacity: enabled ? 1 : 0.45

  Column {
    id: labelColumn
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.5
    spacing: Style.space(2)

    // A setting this window has changed says so on its own title line: the
    // mark ahead of the name, the way out after it.
    Row {
      spacing: Style.space(6)

      Text {
        visible: settingRow.changed
        text: "\u25cf"
        color: Local.Palette.accent
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        text: settingRow.label
        color: Local.Palette.foreground
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        id: resetLink
        visible: settingRow.changed
        text: "(reset)"
        color: resetMouse.containsMouse ? Local.Palette.accent : Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
        font.underline: resetMouse.containsMouse

        MouseArea {
          id: resetMouse
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: settingRow.resetRequested()
        }
      }
    }

    Text {
      visible: settingRow.description !== ""
      width: parent.width
      text: settingRow.description
      wrapMode: Text.WordWrap
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }

    // Under the label rather than beside the control: it belongs to what the
    // setting is, not to what it is set to, and there is room here for the
    // way out to say what it does.
  }

  Item {
    id: controlHolder
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.46
    implicitHeight: childrenRect.height
  }
}
