import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The bar's way into OmaSettings: a gear that opens the settings window.
//
// Nothing but the button lives here. The window and the IPC route are the
// service's (Service.qml), which runs whenever the plugin is enabled, with or
// without a bar entry — so removing the gear from the bar costs you the gear
// and nothing else.
BarWidget {
  id: root
  moduleName: "io.github.twiking.omasettings"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null

  // Shape contract for shell.summon/hide/toggle routing: Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root, so the widget stands in
  // for the window it does not own.
  readonly property bool opened: service ? service.opened : false

  // A widget hosted by another third-party plugin inherits that host's scoped
  // shell facade. Omarchy intentionally refuses a cross-plugin serviceFor(),
  // but the service's public IPC target remains available. Keep the direct
  // path for a normally placed widget and fall back to IPC only when hosted.
  function invoke(method, argument) {
    if (service && typeof service[method] === "function") {
      if (argument === undefined) service[method]()
      else service[method](argument)
      return
    }

    var command = ["omarchy-shell", "omasettings", method]
    if (argument !== undefined) command.push(String(argument))
    Quickshell.execDetached(command)
  }

  function show() { invoke("show") }
  function showPage(page) { invoke("showPage", page) }
  function hide() { invoke("hide") }
  function open() { show() }
  function close() { hide() }
  function toggle() { invoke("toggle") }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf013"
    tooltipText: "Settings"
    active: root.opened
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.bar.run("omarchy-menu")
      else root.toggle()
    }
  }
}
