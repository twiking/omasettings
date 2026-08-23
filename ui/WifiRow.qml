import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One network: name, how strong it is, whether it wants a password, and
// what clicking it will do. A network that needs a password asks for it
// in place rather than in a dialog on top of the list.
Column {
  id: wifiRow
  property string ssid: ""
  property int signalStrength: 0
  property bool secured: false
  property bool saved: false
  property bool active: false
  // Whether this row is the one currently asking for a passphrase.
  property bool prompting: false

  signal connectRequested(string password)
  signal promptToggled()
  signal disconnectRequested()
  signal forgetRequested()

  // A saved network has its password already; only a new secured one needs asking.
  readonly property bool needsPassword: wifiRow.secured && !wifiRow.saved

  // Connecting is the one thing worth a key here; a network that wants a
  // passphrase opens the prompt instead, and the prompt takes the keyboard.
  Local.NavCursor {
    id: nav
    anchors.fill: parent
    searchText: wifiRow.ssid
    navBlocking: wifiRow.prompting
    navKeys: wifiRow.active ? [{ key: "Space", label: "Disconnect" }]
      : (wifiRow.needsPassword ? [{ key: "Space", label: "Passphrase" }]
                               : [{ key: "Space", label: "Connect" }])
    onNavActivate: {
      if (wifiRow.active) wifiRow.disconnectRequested()
      else if (wifiRow.needsPassword) wifiRow.promptToggled()
      else wifiRow.connectRequested("")
    }
  }

  visible: !nav.searchHidden
  width: parent ? parent.width : 0
  spacing: Style.space(6)

  Item {
    width: parent.width
    implicitHeight: Style.spacing.controlHeight

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: wifiRow.active
        ? Qt.rgba(Local.Palette.accent.r, Local.Palette.accent.g, Local.Palette.accent.b, 0.14)
        : (wifiMouse.containsMouse ? Qt.rgba(Local.Palette.foreground.r, Local.Palette.foreground.g, Local.Palette.foreground.b, 0.08) : "transparent")
    }

    MouseArea {
      id: wifiMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (wifiRow.active) return
        if (wifiRow.needsPassword) wifiRow.promptToggled()
        else wifiRow.connectRequested("")
      }
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(10)

      // Four rungs of signal, drawn rather than set in a glyph: icon fonts
      // vary in what they carry, and a missing glyph would leave every
      // network looking equally strong.
      Row {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(20)
        spacing: Style.space(2)

        Repeater {
          model: 4
          delegate: Rectangle {
            required property int index
            readonly property int rungs: wifiRow.signalStrength >= 70 ? 4
                                       : wifiRow.signalStrength >= 45 ? 3
                                       : wifiRow.signalStrength >= 20 ? 2 : 1
            width: Style.space(3)
            height: Style.space(4) + index * Style.space(3)
            anchors.bottom: parent.bottom
            radius: 1
            color: wifiRow.active ? Local.Palette.accent : Local.Palette.foreground
            opacity: index < rungs ? 1 : 0.25
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: wifiRow.ssid
        color: Local.Palette.foreground
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.body
        font.bold: wifiRow.active
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: wifiRow.secured
        text: "\uf023"
        color: Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: wifiRow.saved && !wifiRow.active
        text: "saved"
        color: Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: wifiRow.signalStrength + "%"
        color: Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: wifiRow.active
        text: "Disconnect"
        bordered: true
        foreground: Local.Palette.foreground
        accent: Local.Palette.accent
        fontFamily: Local.Palette.fontFamily
        fontSize: Style.font.caption
        onClicked: wifiRow.disconnectRequested()
      }

      Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: wifiRow.saved && !wifiRow.active && wifiMouse.containsMouse
        text: "Forget"
        bordered: true
        foreground: Local.Palette.foreground
        accent: Local.Palette.accent
        fontFamily: Local.Palette.fontFamily
        fontSize: Style.font.caption
        onClicked: wifiRow.forgetRequested()
      }
    }
  }

  Row {
    width: parent.width
    visible: wifiRow.prompting
    spacing: Style.space(8)

    TextField {
      id: passwordField
      width: parent.width - connectButton.width - Style.space(8)
      placeholderText: "Password for " + wifiRow.ssid
      password: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      onAccepted: if (text !== "") wifiRow.connectRequested(text)
    }

    Button {
      id: connectButton
      anchors.verticalCenter: parent.verticalCenter
      text: "Connect"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      onClicked: if (passwordField.text !== "") wifiRow.connectRequested(passwordField.text)
    }
  }
}
