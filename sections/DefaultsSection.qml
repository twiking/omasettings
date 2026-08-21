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
    title: "Applications"
    note: "An app you have not installed yet is set up the first time you pick it."

    Ui.PickerRow {
      label: "Browser"
      value: app.group("browser").current
      options: app.groupOptions("browser")
      onPicked: function(next) { app.run(["menu", "run", "setup.default.browser." + next]) }
    }

    Ui.PickerRow {
      label: "Terminal"
      value: app.group("terminal").current
      options: app.groupOptions("terminal")
      onPicked: function(next) { app.run(["menu", "run", "setup.default.terminal." + next]) }
    }

    Ui.PickerRow {
      label: "Editor"
      value: app.group("editor").current
      options: app.groupOptions("editor")
      onPicked: function(next) { app.run(["menu", "run", "setup.default.editor." + next]) }
    }

    Ui.PickerRow {
      label: "Coding agent"
      value: app.agentsState.current !== undefined ? String(app.agentsState.current) : ""
      options: app.agentOptions()
      onPicked: function(next) { app.run(["agents", "run", next]) }
    }
  }
}
