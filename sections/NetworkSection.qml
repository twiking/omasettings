import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  Ui.SettingGroup {

    Ui.SwitchRow {
      label: "Wi-Fi"
      description: app.wifi.connected ? "Connected to " + app.wifi.connected : "Not connected"
      checked: app.wifi.enabled === true
      onRequested: function(next) { app.run(["wifi", "radio", next ? "on" : "off"]) }
    }

    Ui.ReadingRow {
      label: "IP address"
      visible: app.wifi.connected !== ""
      value: app.wifiConnection.ip
        ? String(app.wifiConnection.ip) + (app.wifiConnection.prefix ? "/" + app.wifiConnection.prefix : "")
        : "—"
    }

    Ui.ReadingRow {
      label: "Gateway"
      visible: app.wifi.connected !== ""
      value: app.wifiConnection.gateway ? String(app.wifiConnection.gateway) : "—"
    }

    Ui.PickerRow {
      label: "Band"
      visible: app.wifi.connected !== "" && app.bandOptions().length > 1
      description: app.wifiBand.selected === "auto" && app.wifiBand.current
        ? "Currently on " + app.wifiBand.current + " GHz"
        : "Pinned; the radio will not move off it."
      value: app.wifiBand.selected !== undefined ? String(app.wifiBand.selected) : "auto"
      options: app.bandOptions()
      onPicked: function(next) { app.run(["wifi", "band", next]) }
    }

  }

  Ui.SettingGroup {
    title: "Networks"
    visible: app.wifi.enabled === true

    Item {
      width: parent.width
      implicitHeight: rescanButton.implicitHeight

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: app.wifiNetworks.length === 1 ? "1 network in range"
                                             : app.wifiNetworks.length + " networks in range"
        color: app.muted
        font.family: app.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        id: rescanButton
        anchors.right: parent.right
        text: "Scan again"
        bordered: true
        foreground: app.foreground
        accent: app.accent
        fontFamily: app.fontFamily
        fontSize: Style.font.caption
        onClicked: app.run(["wifi", "rescan"])
      }
    }

    Repeater {
      model: app.wifi.enabled === true ? app.wifiNetworks : []
      delegate: Ui.WifiRow {
        required property var modelData
        width: parent.width
        ssid: modelData.ssid
        signalStrength: Number(modelData.signal)
        secured: modelData.secured === true
        saved: modelData.saved === true
        active: modelData.active === true
        prompting: app.wifiPrompting === modelData.ssid
        onPromptToggled: app.wifiPrompting = (app.wifiPrompting === modelData.ssid ? "" : modelData.ssid)
        onConnectRequested: function(password) { app.connectWifi(modelData.ssid, password) }
        onDisconnectRequested: app.run(["wifi", "disconnect"])
        onForgetRequested: app.run(["wifi", "forget", modelData.ssid])
      }
    }
  }

  Ui.SettingGroup {
    title: "DNS"
    note: "Which servers resolve names on every connection."

    Ui.PickerRow {
      label: "Resolver"
      value: app.group("dns").current
      options: app.groupOptions("dns")
      onPicked: function(next) { app.run(["menu", "run", "setup.network.dns." + next]) }
    }
  }

  Ui.SettingGroup {
    title: "Sharing"

    Ui.ActionRow {
      label: "Wi-Fi QR code"
      description: "Show a code others can scan to join this network."
      buttonText: "Show…"
      onTriggered: app.run(["menu", "run", "setup.network.qr"])
    }
  }
}
