import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The bar's way into OmaSettings: a gear that opens the settings window.
//
// The window lives in SettingsWindow.qml and is loaded on first use rather
// than at startup — the shell process is long-running and a settings window
// nobody has opened yet should not cost it anything.
BarWidget {
  id: root
  moduleName: "io.github.twiking.omasettings"

  // The lifecycle a bar widget is expected to carry, in the names the rest of
  // Omarchy uses. open/close and show/hide are the same pair twice, because
  // both names are in circulation and neither is worth surprising anyone over.
  readonly property bool opened: windowLoader.item ? windowLoader.item.shown : false

  function show() { windowLoader.active = true; if (windowLoader.item) windowLoader.item.show() }
  function hide() { if (windowLoader.item) windowLoader.item.hide() }
  function open() { show() }
  function close() { hide() }
  function toggle() {
    if (opened) hide()
    else show()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "omasettings"
    function show(): void { root.show() }
    function hide(): void { root.hide() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Loader {
    id: windowLoader
    active: false
    asynchronous: true
    source: "SettingsWindow.qml"
    onLoaded: if (item) item.show()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf013"
    tooltipText: "Settings"
    active: windowLoader.item ? windowLoader.item.shown : false
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.bar.run("omarchy-menu")
      else root.toggle()
    }
  }
}
