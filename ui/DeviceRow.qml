import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One Bluetooth device: what it is, how it is doing, and the actions that
// apply to it. A device you own can be connected or forgotten; one the
// adapter merely saw can only be paired.
Item {
  id: deviceRow

  property string address: ""
  property string name: ""
  property string kind: ""
  property bool paired: false
  property bool connected: false
  property int battery: -1

  signal connectRequested()
  signal disconnectRequested()
  signal pairRequested()
  signal forgetRequested()

  // The same thing clicking the row does, which depends on what the device is.
  Local.NavCursor {
    id: nav
    anchors.fill: parent
    searchText: deviceRow.title + " " + deviceRow.address + " " + deviceRow.kind
    navKeys: deviceRow.connected ? [{ key: "Space", label: "Disconnect" }]
      : (deviceRow.paired ? [{ key: "Space", label: "Connect" }]
                          : [{ key: "Space", label: "Pair" }])
    onNavActivate: {
      if (deviceRow.connected) deviceRow.disconnectRequested()
      else if (deviceRow.paired) deviceRow.connectRequested()
      else deviceRow.pairRequested()
    }
  }

  // Falling back to the address keeps a nameless device identifiable rather
  // than blank.
  readonly property string title: name !== "" ? name : address

  visible: !nav.searchHidden
  width: parent ? parent.width : 0
  implicitHeight: Style.spacing.controlHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: deviceRow.connected
      ? Qt.rgba(Local.Palette.accent.r, Local.Palette.accent.g, Local.Palette.accent.b, 0.14)
      : (deviceMouse.containsMouse ? Local.Palette.hover : "transparent")
  }

  MouseArea {
    id: deviceMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (deviceRow.connected) deviceRow.disconnectRequested()
      else if (deviceRow.paired) deviceRow.connectRequested()
      else deviceRow.pairRequested()
    }
  }

  Row {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(10)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      // BlueZ reports a freedesktop icon name; these are the kinds that
      // actually turn up, and anything else gets the generic mark.
      text: deviceRow.kind.indexOf("keyboard") !== -1 ? ""
          : deviceRow.kind.indexOf("mouse") !== -1 ? ""
          : deviceRow.kind.indexOf("headset") !== -1 || deviceRow.kind.indexOf("headphone") !== -1 ? ""
          : deviceRow.kind.indexOf("audio") !== -1 ? ""
          : deviceRow.kind.indexOf("phone") !== -1 ? ""
          : deviceRow.kind.indexOf("watch") !== -1 ? ""
          : ""
      color: deviceRow.connected ? Local.Palette.accent : Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.body
      width: Style.space(20)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: deviceRow.title
      color: Local.Palette.foreground
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.body
      font.bold: deviceRow.connected
    }

  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: deviceRow.battery >= 0
      text: deviceRow.battery + "%"
      // A device about to die is worth noticing before it dies.
      color: deviceRow.battery <= 20 ? Color.urgent : Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }

    Button {
      anchors.verticalCenter: parent.verticalCenter
      visible: deviceRow.connected || (deviceRow.paired && deviceMouse.containsMouse)
      text: deviceRow.connected ? "Disconnect" : "Connect"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      fontSize: Style.font.caption
      onClicked: deviceRow.connected ? deviceRow.disconnectRequested() : deviceRow.connectRequested()
    }

    Button {
      anchors.verticalCenter: parent.verticalCenter
      visible: deviceRow.paired && deviceMouse.containsMouse
      text: "Forget"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      fontSize: Style.font.caption
      onClicked: deviceRow.forgetRequested()
    }

    Button {
      anchors.verticalCenter: parent.verticalCenter
      visible: !deviceRow.paired && deviceMouse.containsMouse
      text: "Pair"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      fontSize: Style.font.caption
      onClicked: deviceRow.pairRequested()
    }
  }
}
