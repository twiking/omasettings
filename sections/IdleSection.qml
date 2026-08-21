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
    title: "Timeouts"
    note: "Counted from when you stop using the machine."

    Ui.MinutesRow {
      label: "Screensaver after"
      seconds: app.idleState.screensaver !== undefined ? Number(app.idleState.screensaver) : 150
      onCommitted: function(mins) { app.set("idle-screensaver", mins * 60) }
    }

    Ui.MinutesRow {
      label: "Lock after"
      seconds: app.idleState.lock !== undefined ? Number(app.idleState.lock) : 300
      onCommitted: function(mins) { app.set("idle-lock", mins * 60) }
    }
  }
}
