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
    title: "Layout"

    Ui.NumberRow {
      label: "Inner gaps"
      suffix: "px"
      value: app.hyprValue("gaps-in", 0)
      from: 0
      to: 40
      onCommitted: function(next) { app.setHypr("gaps-in", next) }
    }

    Ui.NumberRow {
      label: "Outer gaps"
      suffix: "px"
      value: app.hyprValue("gaps-out", 0)
      from: 0
      to: 60
      onCommitted: function(next) { app.setHypr("gaps-out", next) }
    }

    Ui.NumberRow {
      label: "Border width"
      suffix: "px"
      value: app.hyprValue("border-size", 0)
      from: 0
      to: 10
      onCommitted: function(next) { app.setHypr("border-size", next) }
    }

    Ui.NumberRow {
      label: "Corner rounding"
      suffix: "px"
      value: app.hyprValue("rounding", 0)
      from: 0
      to: 24
      onCommitted: function(next) { app.setHypr("rounding", next) }
    }
  }

  Ui.SettingGroup {
    title: "Focus and depth"

    Ui.PercentRow {
      label: "Active window opacity"
      value: app.hyprValue("active-opacity", 1)
      onCommitted: function(next) { app.setHypr("active-opacity", next) }
    }

    Ui.PercentRow {
      label: "Inactive window opacity"
      value: app.hyprValue("inactive-opacity", 1)
      onCommitted: function(next) { app.setHypr("inactive-opacity", next) }
    }

    Ui.SwitchRow {
      label: "Dim inactive windows"
      checked: app.hyprValue("dim-inactive", false) === true
      onRequested: function(next) { app.setHypr("dim-inactive", next ? "true" : "false") }
    }

    Ui.PercentRow {
      label: "Dim strength"
      enabled: app.hyprValue("dim-inactive", false) === true
      value: app.hyprValue("dim-strength", 0.5)
      onCommitted: function(next) { app.setHypr("dim-strength", next) }
    }
  }

  Ui.SettingGroup {
    title: "Effects"

    Ui.SwitchRow {
      label: "Animations"
      checked: app.hyprValue("animations", true) === true
      onRequested: function(next) { app.setHypr("animations", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Blur"
      description: "Blurs whatever is behind translucent windows and layers."
      checked: app.hyprValue("blur", false) === true
      onRequested: function(next) { app.setHypr("blur", next ? "true" : "false") }
    }

    Ui.NumberRow {
      label: "Blur size"
      enabled: app.hyprValue("blur", false) === true
      value: app.hyprValue("blur-size", 8)
      from: 1
      to: 20
      onCommitted: function(next) { app.setHypr("blur-size", next) }
    }

    Ui.NumberRow {
      label: "Blur passes"
      enabled: app.hyprValue("blur", false) === true
      value: app.hyprValue("blur-passes", 1)
      from: 1
      to: 5
      onCommitted: function(next) { app.setHypr("blur-passes", next) }
    }
  }

  Ui.SettingGroup {
    title: "Beyond these settings"

    Ui.ActionRow {
      label: "Window rules and animations"
      description: "Open looknfeel.lua for anything this page does not cover."
      buttonText: "Edit…"
      onTriggered: app.run(["menu", "run", "style.hyprland"])
    }
  }
}
