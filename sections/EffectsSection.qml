import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// The three things Hyprland draws around and behind windows. Each has a master
// switch, and the settings under it stay visible but inert while it is off —
// they are what the switch turns on, so hiding them would hide the point.
Ui.SectionBody {
  property var app: null

  readonly property bool blurOn: app.hyprValue("blur", false) === true
  readonly property bool shadowOn: app.hyprValue("shadow", false) === true
  readonly property bool glowOn: app.hyprValue("glow", false) === true

  Ui.SettingGroup {
    title: "Blur"
    note: "Blurs whatever is behind translucent windows and layers. Costs GPU."

    Ui.SwitchRow {
      label: "Blur"
      checked: blurOn
      onRequested: function(next) { app.setHypr("blur", next ? "true" : "false") }
      changed: app.isChanged("blur")
      onResetRequested: app.resetSetting("blur")
    }

    Ui.NumberRow {
      label: "Size"
      description: "Blur radius."
      enabled: blurOn
      value: app.hyprValue("blur-size", 8)
      from: 1
      to: 20
      onCommitted: function(next) { app.setHypr("blur-size", next) }
      changed: app.isChanged("blur-size")
      onResetRequested: app.resetSetting("blur-size")
    }

    Ui.NumberRow {
      label: "Passes"
      description: "More passes is smoother and slower. 3 is a good ceiling."
      enabled: blurOn
      value: app.hyprValue("blur-passes", 1)
      from: 1
      to: 5
      onCommitted: function(next) { app.setHypr("blur-passes", next) }
      changed: app.isChanged("blur-passes")
      onResetRequested: app.resetSetting("blur-passes")
    }

    Ui.FactorRow {
      label: "Noise"
      description: "Grain mixed into the blur to hide banding."
      enabled: blurOn
      minimum: 0
      maximum: 0.2
      value: app.hyprValue("blur-noise", 0.02)
      onCommitted: function(next) { app.setHypr("blur-noise", next) }
      changed: app.isChanged("blur-noise")
      onResetRequested: app.resetSetting("blur-noise")
    }

    Ui.FactorRow {
      label: "Contrast"
      enabled: blurOn
      minimum: 0
      maximum: 2
      value: app.hyprValue("blur-contrast", 1)
      onCommitted: function(next) { app.setHypr("blur-contrast", next) }
      changed: app.isChanged("blur-contrast")
      onResetRequested: app.resetSetting("blur-contrast")
    }

    Ui.FactorRow {
      label: "Brightness"
      enabled: blurOn
      minimum: 0
      maximum: 2
      value: app.hyprValue("blur-brightness", 1)
      onCommitted: function(next) { app.setHypr("blur-brightness", next) }
      changed: app.isChanged("blur-brightness")
      onResetRequested: app.resetSetting("blur-brightness")
    }

    Ui.PercentRow {
      label: "Vibrancy"
      description: "Saturation boost for the blurred image."
      enabled: blurOn
      value: app.hyprValue("blur-vibrancy", 0.17)
      onCommitted: function(next) { app.setHypr("blur-vibrancy", next) }
      changed: app.isChanged("blur-vibrancy")
      onResetRequested: app.resetSetting("blur-vibrancy")
    }

    Ui.PercentRow {
      label: "Vibrancy darkness"
      description: "How much vibrancy applies to dark areas."
      enabled: blurOn
      value: app.hyprValue("blur-vibrancy-darkness", 0)
      onCommitted: function(next) { app.setHypr("blur-vibrancy-darkness", next) }
      changed: app.isChanged("blur-vibrancy-darkness")
      onResetRequested: app.resetSetting("blur-vibrancy-darkness")
    }

    Ui.SwitchRow {
      label: "X-ray"
      description: "Blurs the wallpaper instead of the windows underneath."
      enabled: blurOn
      checked: app.hyprValue("blur-xray", false) === true
      onRequested: function(next) { app.setHypr("blur-xray", next ? "true" : "false") }
      changed: app.isChanged("blur-xray")
      onResetRequested: app.resetSetting("blur-xray")
    }

    Ui.SwitchRow {
      label: "Special workspace"
      description: "Blurs behind special workspaces."
      enabled: blurOn
      checked: app.hyprValue("blur-special", false) === true
      onRequested: function(next) { app.setHypr("blur-special", next ? "true" : "false") }
      changed: app.isChanged("blur-special")
      onResetRequested: app.resetSetting("blur-special")
    }

    Ui.SwitchRow {
      label: "Popups"
      description: "Blurs behind menus and tooltips."
      enabled: blurOn
      checked: app.hyprValue("blur-popups", false) === true
      onRequested: function(next) { app.setHypr("blur-popups", next ? "true" : "false") }
      changed: app.isChanged("blur-popups")
      onResetRequested: app.resetSetting("blur-popups")
    }
  }

  Ui.SettingGroup {
    title: "Shadow"
    note: "Drop shadow cast by windows."

    Ui.SwitchRow {
      label: "Shadow"
      checked: shadowOn
      onRequested: function(next) { app.setHypr("shadow", next ? "true" : "false") }
      changed: app.isChanged("shadow")
      onResetRequested: app.resetSetting("shadow")
    }

    Ui.NumberRow {
      label: "Range"
      description: "How far the shadow reaches."
      suffix: "px"
      enabled: shadowOn
      value: app.hyprValue("shadow-range", 4)
      from: 0
      to: 50
      onCommitted: function(next) { app.setHypr("shadow-range", next) }
      changed: app.isChanged("shadow-range")
      onResetRequested: app.resetSetting("shadow-range")
    }

    Ui.NumberRow {
      label: "Falloff"
      description: "How sharply the shadow fades out."
      enabled: shadowOn
      value: app.hyprValue("shadow-render-power", 3)
      from: 1
      to: 4
      onCommitted: function(next) { app.setHypr("shadow-render-power", next) }
      changed: app.isChanged("shadow-render-power")
      onResetRequested: app.resetSetting("shadow-render-power")
    }

    Ui.PercentRow {
      label: "Scale"
      description: "Size of the shadow relative to the window."
      enabled: shadowOn
      value: app.hyprValue("shadow-scale", 1)
      onCommitted: function(next) { app.setHypr("shadow-scale", next) }
      changed: app.isChanged("shadow-scale")
      onResetRequested: app.resetSetting("shadow-scale")
    }

    Ui.SwitchRow {
      label: "Sharp"
      description: "Hard-edged shadow with no gradient."
      enabled: shadowOn
      checked: app.hyprValue("shadow-sharp", false) === true
      onRequested: function(next) { app.setHypr("shadow-sharp", next ? "true" : "false") }
      changed: app.isChanged("shadow-sharp")
      onResetRequested: app.resetSetting("shadow-sharp")
    }
  }

  Ui.SettingGroup {
    title: "Glow"
    note: "Halo around the focused window. Its colour is a separate Hyprland option this page leaves alone."

    Ui.SwitchRow {
      label: "Glow"
      checked: glowOn
      onRequested: function(next) { app.setHypr("glow", next ? "true" : "false") }
      changed: app.isChanged("glow")
      onResetRequested: app.resetSetting("glow")
    }

    Ui.NumberRow {
      label: "Range"
      description: "How far the glow reaches."
      suffix: "px"
      enabled: glowOn
      value: app.hyprValue("glow-range", 10)
      from: 0
      to: 50
      onCommitted: function(next) { app.setHypr("glow-range", next) }
      changed: app.isChanged("glow-range")
      onResetRequested: app.resetSetting("glow-range")
    }

    Ui.NumberRow {
      label: "Falloff"
      description: "How sharply the glow fades out."
      enabled: glowOn
      value: app.hyprValue("glow-render-power", 3)
      from: 1
      to: 4
      onCommitted: function(next) { app.setHypr("glow-render-power", next) }
      changed: app.isChanged("glow-render-power")
      onResetRequested: app.resetSetting("glow-render-power")
    }
  }
}
