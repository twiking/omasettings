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

  // Three states, three lists. They answer different questions — what am I
  // using, what do I own, what else is here — so they are not one list with
  // a sort order you have to infer.
  function devicesWhere(test) {
    var out = []
    for (var i = 0; i < devices.length; i++)
      if (test(devices[i])) out.push(devices[i])
    return out
  }

  readonly property var connectedDevices: devicesWhere(function(d) { return d.connected === true })
  readonly property var pairedDevices: devicesWhere(function(d) { return d.paired === true && d.connected !== true })
  readonly property var nearbyDevices: devicesWhere(function(d) { return d.paired !== true })

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

  }

  Ui.SettingGroup {
    title: "Connected"
    visible: bluetooth.powered === true && connectedDevices.length > 0

    Repeater {
      model: connectedDevices
      delegate: DeviceDelegate {}
    }
  }

  Ui.SettingGroup {
    title: "Paired"
    note: "Yours, but not connected right now."
    visible: bluetooth.powered === true && pairedDevices.length > 0

    Repeater {
      model: pairedDevices
      delegate: DeviceDelegate {}
    }
  }

  Ui.SettingGroup {
    title: "Nearby"
    note: nearbyDevices.length === 0 ? "Nothing else in range. Scan to look again." : ""
    visible: bluetooth.powered === true

    Repeater {
      model: nearbyDevices
      delegate: DeviceDelegate {}
    }
  }

  // The three lists differ only in what they hold, so the row they hold is
  // written once.
  component DeviceDelegate: Ui.DeviceRow {
    required property var modelData

    width: parent ? parent.width : 0
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
