import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One binding: what you press, what it does, and the one action that makes
// sense for where it came from — yours can be removed, Omarchy's can be
// turned off, and a turned-off one can come back.
Item {
  id: bindingRow
  property string keys: ""
  property string description: ""
  property string command: ""
  property string source: "omarchy"

  signal removeRequested()
  signal disableRequested()

  readonly property bool mine: source === "yours"
  readonly property bool off: source === "disabled"

  // A binding you wrote can go; one of Omarchy's can only be turned off, and
  // a turned-off one can come back. The key follows whichever it is, the same
  // way the button does.
  Local.NavCursor {
    anchors.fill: parent
    navKeys: bindingRow.mine ? [{ key: "Space", label: "Remove" }]
      : [{ key: "Space", label: bindingRow.off ? "Restore" : "Turn off" }]
    onNavActivate: {
      if (bindingRow.mine) bindingRow.removeRequested()
      else bindingRow.disableRequested()
    }
  }

  width: parent ? parent.width : 0
  implicitHeight: Math.max(Style.spacing.controlHeight, keysText.implicitHeight + Style.space(6))
  opacity: off ? 0.5 : 1

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: bindingMouse.containsMouse
      ? Qt.rgba(Local.Palette.foreground.r, Local.Palette.foreground.g, Local.Palette.foreground.b, 0.06)
      : "transparent"
  }

  MouseArea {
    id: bindingMouse
    anchors.fill: parent
    hoverEnabled: true
  }

  Text {
    id: keysText
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.3
    elide: Text.ElideRight
    text: bindingRow.keys
    color: bindingRow.mine ? Local.Palette.accent : Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: parent.width * 0.32
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.32
    elide: Text.ElideRight
    text: bindingRow.description
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: parent.width * 0.65
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.22
    elide: Text.ElideRight
    visible: bindingRow.command !== ""
    text: bindingRow.command
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
  }

  Button {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    visible: bindingMouse.containsMouse || bindingRow.off
    text: bindingRow.mine ? "Remove" : (bindingRow.off ? "Restore" : "Turn off")
    bordered: true
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    fontFamily: Local.Palette.fontFamily
    fontSize: Style.font.caption
    onClicked: {
      if (bindingRow.mine || bindingRow.off) bindingRow.removeRequested()
      else bindingRow.disableRequested()
    }
  }
}
