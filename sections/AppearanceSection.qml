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
      changed: app.isChanged("theme")
      onResetRequested: app.resetSetting("theme")
    }

    Ui.PickerRow {
      label: "Font"
      value: app.state.font !== undefined ? String(app.state.font) : ""
      options: app.state.fonts
      searchable: true
      onPicked: function(next) { app.set("font", next) }
      changed: app.isChanged("font")
      onResetRequested: app.resetSetting("font")
    }

    Ui.NumberRow {
      label: "Text size"
      description: "Scales the shell, GTK apps, and terminals together."
      suffix: "px"
      value: app.state.textScale !== undefined ? Number(app.state.textScale) : 12
      from: 9
      to: 20
      onCommitted: function(next) { app.set("text-scale", next) }
      changed: app.isChanged("text-scale")
      onResetRequested: app.resetSetting("text-scale")
    }
  }

  Ui.SettingGroup {
    title: "Screen tint"

    Ui.SwitchRow {
      label: "Night light"
      description: "Warms the screen to 4000K."
      checked: app.state.nightlight === true
      onRequested: function(next) { app.set("nightlight", next ? "true" : "false") }
      changed: app.isChanged("nightlight")
      onResetRequested: app.resetSetting("nightlight")
    }
  }

  Ui.SettingGroup {
    title: "Wallpaper"

    Ui.ActionRow {
      label: "Background"
      description: "Pick from the wallpapers that come with your theme."
      buttonText: "Choose…"
      onTriggered: app.run(["menu", "run", "style.background"])
    }

  }

  Ui.SettingGroup {
    title: "Branding"

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
