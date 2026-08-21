import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// Label on the left, control on the right — the shape every row shares.
Item {
  id: settingRow
  property string label: ""
  property string description: ""
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

    Text {
      text: settingRow.label
      color: Local.Palette.foreground
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.body
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
  }

  Item {
    id: controlHolder
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.46
    implicitHeight: childrenRect.height
  }
}
