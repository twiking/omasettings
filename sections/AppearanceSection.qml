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
    title: "Theme and font"

    Ui.PickerRow {
      label: "Theme"
      value: app.state.theme !== undefined ? String(app.state.theme) : ""
      options: app.state.themes
      searchable: true
      onPicked: function(next) { app.set("theme", next) }
    }

    Ui.PickerRow {
      label: "Font"
      value: app.state.font !== undefined ? String(app.state.font) : ""
      options: app.state.fonts
      searchable: true
      onPicked: function(next) { app.set("font", next) }
    }

    Ui.NumberRow {
      label: "Text size"
      description: "Scales the shell, GTK apps, and terminals together."
      suffix: "px"
      value: app.state.textScale !== undefined ? Number(app.state.textScale) : 12
      from: 9
      to: 20
      onCommitted: function(next) { app.set("text-scale", next) }
    }
  }

  Ui.SettingGroup {
    title: "Screen tint"

    Ui.SwitchRow {
      label: "Night light"
      description: "Warms the screen to 4000K."
      checked: app.state.nightlight === true
      onRequested: function(next) { app.set("nightlight", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Wallpaper and boot"

    Ui.ActionRow {
      label: "Background"
      description: "Pick from the wallpapers that come with your theme."
      buttonText: "Choose…"
      onTriggered: app.run(["menu", "run", "style.background"])
    }

    Ui.ActionRow {
      label: "Boot and unlock screen"
      description: "The animation shown while the machine starts and unlocks."
      buttonText: "Choose…"
      onTriggered: app.run(["menu", "run", "style.unlock"])
    }
  }

  Ui.SettingGroup {
    title: "Branding"
    note: "What the screensaver and the about screen show."

    Ui.BrandingRow {
      label: "Screensaver"
      onChose: function(variant) { app.run(["menu", "run", "style.screensaver." + variant]) }
    }

    Ui.BrandingRow {
      label: "About screen"
      onChose: function(variant) { app.run(["menu", "run", "style.about." + variant]) }
    }
  }
}
