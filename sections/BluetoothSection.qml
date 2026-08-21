import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var bluetooth: app.bluetooth
  readonly property var devices: bluetooth.devices !== undefined ? bluetooth.devices : []

  Ui.SettingGroup {
    title: "Bluetooth"

    Ui.SwitchRow {
      label: "Bluetooth"
      description: app.bluetoothSummary
      checked: bluetooth.powered === true
      onRequested: function(next) { app.run(["bluetooth", "power", next ? "on" : "off"]) }
    }

    Item {
      width: parent.width
      implicitHeight: scanButton.implicitHeight
      visible: bluetooth.powered === true

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: devices.length === 1 ? "1 device" : devices.length + " devices"
        color: Ui.Palette.muted
        font.family: Ui.Palette.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        id: scanButton
        anchors.right: parent.right
        text: app.busy ? "Scanning…" : "Scan"
        enabled: !app.busy
        bordered: true
        foreground: Ui.Palette.foreground
        accent: Ui.Palette.accent
        fontFamily: Ui.Palette.fontFamily
        fontSize: Style.font.caption
        onClicked: app.run(["bluetooth", "scan"])
      }
    }

    Repeater {
      model: bluetooth.powered === true ? devices : []
      delegate: Ui.DeviceRow {
        required property var modelData
        width: parent.width
        address: modelData.address
        name: modelData.name
        kind: modelData.icon
        paired: modelData.paired === true
        connected: modelData.connected === true
        battery: modelData.battery !== null && modelData.battery !== undefined ? Number(modelData.battery) : -1
        onConnectRequested: app.run(["bluetooth", "connect", modelData.address])
        onDisconnectRequested: app.run(["bluetooth", "disconnect", modelData.address])
        onPairRequested: app.run(["bluetooth", "pair", modelData.address])
        onForgetRequested: app.run(["bluetooth", "forget", modelData.address])
      }
    }
  }
}
