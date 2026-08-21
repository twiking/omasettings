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
    title: "Clock"

    Ui.ActionRow {
      label: "Timezone"
      description: app.datetime.timezone ? String(app.datetime.timezone) : "Unknown"
      buttonText: "Change…"
      onTriggered: app.run(["menu", "run", "update.timezone"])
    }

    Ui.ActionRow {
      label: "System time"
      description: (app.datetime.now ? String(app.datetime.now) : "")
        + (app.datetime.ntp === true
           ? (app.datetime.synchronized === true ? " · synchronized" : " · syncing")
           : " · automatic sync off")
      buttonText: "Resync…"
      onTriggered: app.run(["menu", "run", "update.time"])
    }
  }
}
