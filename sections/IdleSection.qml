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

    Ui.MinutesRow {
      label: "Screensaver after"
      seconds: app.idleState.screensaver !== undefined ? Number(app.idleState.screensaver) : 150
      onCommitted: function(mins) { app.set("idle-screensaver", mins * 60) }
      changed: app.isChanged("idle-screensaver")
      onResetRequested: app.resetSetting("idle-screensaver")
    }

    Ui.MinutesRow {
      label: "Lock after"
      seconds: app.idleState.lock !== undefined ? Number(app.idleState.lock) : 300
      onCommitted: function(mins) { app.set("idle-lock", mins * 60) }
      changed: app.isChanged("idle-lock")
      onResetRequested: app.resetSetting("idle-lock")
    }
  }

  Ui.SettingGroup {
    title: "Lock screen"

    Ui.ActionRow {
      label: "Unlock animation"
      description: "Shown while the machine starts up and while it unlocks."
      buttonText: "Choose…"
      onTriggered: app.run(["menu", "run", "style.unlock"])
    }
  }
}
