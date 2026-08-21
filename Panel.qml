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

  function show() { windowLoader.active = true; if (windowLoader.item) windowLoader.item.show() }
  function hide() { if (windowLoader.item) windowLoader.item.hide() }
  function toggle() {
    if (windowLoader.item && windowLoader.item.shown) hide()
    else show()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "omasettings"
    function show(): void { root.show() }
    function hide(): void { root.hide() }
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
