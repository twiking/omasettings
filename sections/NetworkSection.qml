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
      checked: app.wifi.enabled === true
      onRequested: function(next) { app.run(["wifi", "radio", next ? "on" : "off"]) }
    }

  }

  Ui.SettingGroup {
    visible: app.wifi.enabled === true

    // Networks come and go while you are looking at them, so the page keeps
    // its own list current rather than making you ask. It runs only while
    // this page is the one on screen and the window is open.
    Timer {
      interval: 5000
      running: app.shown
      repeat: true
      triggeredOnStart: true
      onTriggered: app.pollWifi()
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
    title: "Connection"
    visible: app.wifi.connected !== ""

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
    Ui.ChoiceRow {
      label: "DNS provider"
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
