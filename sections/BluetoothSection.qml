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

  // The adapter governs the whole page, so its switch sits beside the page
  // name and the summary replaces the file path under it.
  property Component headerControl: Component {
    ToggleSwitch {
      checked: bluetooth.powered === true
      foreground: Ui.Palette.foreground
      accent: Ui.Palette.accent
      onToggled: app.run(["bluetooth", "power", bluetooth.powered === true ? "off" : "on"])
    }
  }

  // The lists below say what is connected; the header only says whether the
  // adapter is on at all.
  readonly property string headerNote: {
    if (bluetooth.available === false) return "No adapter"
    return bluetooth.powered === true ? "" : "Off"
  }

  // Devices come and go while you are looking at them, and discovery is a
  // mode the adapter has to be held in, so the page holds it — but only
  // while it is the page on screen and the window is open.
  Timer {
    interval: 5000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollBluetooth()
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
    visible: bluetooth.powered === true && pairedDevices.length > 0

    Repeater {
      model: pairedDevices
      delegate: DeviceDelegate {}
    }
  }

  Ui.SettingGroup {
    title: "Nearby"
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
