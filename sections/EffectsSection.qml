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
    }

    Ui.NumberRow {
      label: "Size"
      description: "Blur radius."
      enabled: blurOn
      value: app.hyprValue("blur-size", 8)
      from: 1
      to: 20
      onCommitted: function(next) { app.setHypr("blur-size", next) }
    }

    Ui.NumberRow {
      label: "Passes"
      description: "More passes is smoother and slower. 3 is a good ceiling."
      enabled: blurOn
      value: app.hyprValue("blur-passes", 1)
      from: 1
      to: 5
      onCommitted: function(next) { app.setHypr("blur-passes", next) }
    }

    Ui.FactorRow {
      label: "Noise"
      description: "Grain mixed into the blur to hide banding."
      enabled: blurOn
      minimum: 0
      maximum: 0.2
      value: app.hyprValue("blur-noise", 0.02)
      onCommitted: function(next) { app.setHypr("blur-noise", next) }
    }

    Ui.FactorRow {
      label: "Contrast"
      enabled: blurOn
      minimum: 0
      maximum: 2
      value: app.hyprValue("blur-contrast", 1)
      onCommitted: function(next) { app.setHypr("blur-contrast", next) }
    }

    Ui.FactorRow {
      label: "Brightness"
      enabled: blurOn
      minimum: 0
      maximum: 2
      value: app.hyprValue("blur-brightness", 1)
      onCommitted: function(next) { app.setHypr("blur-brightness", next) }
    }

    Ui.PercentRow {
      label: "Vibrancy"
      description: "Saturation boost for the blurred image."
      enabled: blurOn
      value: app.hyprValue("blur-vibrancy", 0.17)
      onCommitted: function(next) { app.setHypr("blur-vibrancy", next) }
    }

    Ui.PercentRow {
      label: "Vibrancy darkness"
      description: "How much vibrancy applies to dark areas."
      enabled: blurOn
      value: app.hyprValue("blur-vibrancy-darkness", 0)
      onCommitted: function(next) { app.setHypr("blur-vibrancy-darkness", next) }
    }

    Ui.SwitchRow {
      label: "X-ray"
      description: "Blurs the wallpaper instead of the windows underneath."
      enabled: blurOn
      checked: app.hyprValue("blur-xray", false) === true
      onRequested: function(next) { app.setHypr("blur-xray", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Special workspace"
      description: "Blurs behind special workspaces."
      enabled: blurOn
      checked: app.hyprValue("blur-special", false) === true
      onRequested: function(next) { app.setHypr("blur-special", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Popups"
      description: "Blurs behind menus and tooltips."
      enabled: blurOn
      checked: app.hyprValue("blur-popups", false) === true
      onRequested: function(next) { app.setHypr("blur-popups", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Shadow"
    note: "Drop shadow cast by windows."

    Ui.SwitchRow {
      label: "Shadow"
      checked: shadowOn
      onRequested: function(next) { app.setHypr("shadow", next ? "true" : "false") }
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
    }

    Ui.NumberRow {
      label: "Falloff"
      description: "How sharply the shadow fades out."
      enabled: shadowOn
      value: app.hyprValue("shadow-render-power", 3)
      from: 1
      to: 4
      onCommitted: function(next) { app.setHypr("shadow-render-power", next) }
    }

    Ui.PercentRow {
      label: "Scale"
      description: "Size of the shadow relative to the window."
      enabled: shadowOn
      value: app.hyprValue("shadow-scale", 1)
      onCommitted: function(next) { app.setHypr("shadow-scale", next) }
    }

    Ui.SwitchRow {
      label: "Sharp"
      description: "Hard-edged shadow with no gradient."
      enabled: shadowOn
      checked: app.hyprValue("shadow-sharp", false) === true
      onRequested: function(next) { app.setHypr("shadow-sharp", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Glow"
    note: "Halo around the focused window. Its colour is a separate Hyprland option this page leaves alone."

    Ui.SwitchRow {
      label: "Glow"
      checked: glowOn
      onRequested: function(next) { app.setHypr("glow", next ? "true" : "false") }
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
    }

    Ui.NumberRow {
      label: "Falloff"
      description: "How sharply the glow fades out."
      enabled: glowOn
      value: app.hyprValue("glow-render-power", 3)
      from: 1
      to: 4
      onCommitted: function(next) { app.setHypr("glow-render-power", next) }
    }
  }
}
