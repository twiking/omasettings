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
    title: "Gaps and borders"

    Ui.NumberRow {
      label: "Inner gaps"
      suffix: "px"
      value: app.hyprValue("gaps-in", 0)
      from: 0
      to: 40
      onCommitted: function(next) { app.setHypr("gaps-in", next) }
      changed: app.isChanged("gaps-in")
      onResetRequested: app.resetSetting("gaps-in")
    }

    Ui.NumberRow {
      label: "Outer gaps"
      suffix: "px"
      value: app.hyprValue("gaps-out", 0)
      from: 0
      to: 60
      onCommitted: function(next) { app.setHypr("gaps-out", next) }
      changed: app.isChanged("gaps-out")
      onResetRequested: app.resetSetting("gaps-out")
    }

    Ui.NumberRow {
      label: "Border width"
      suffix: "px"
      value: app.hyprValue("border-size", 0)
      from: 0
      to: 10
      onCommitted: function(next) { app.setHypr("border-size", next) }
      changed: app.isChanged("border-size")
      onResetRequested: app.resetSetting("border-size")
    }

    Ui.NumberRow {
      label: "Floating gaps"
      description: "Gap around floating windows. 0 follows the inner gap."
      suffix: "px"
      value: app.hyprValue("float-gaps", 0)
      from: 0
      to: 40
      onCommitted: function(next) { app.setHypr("float-gaps", next) }
      changed: app.isChanged("float-gaps")
      onResetRequested: app.resetSetting("float-gaps")
    }

    Ui.NumberRow {
      label: "Workspace gaps"
      description: "Extra space between workspaces while they slide past."
      suffix: "px"
      value: app.hyprValue("gaps-workspaces", 0)
      from: 0
      to: 100
      onCommitted: function(next) { app.setHypr("gaps-workspaces", next) }
      changed: app.isChanged("gaps-workspaces")
      onResetRequested: app.resetSetting("gaps-workspaces")
    }

    Ui.SwitchRow {
      label: "Border inside window"
      description: "Counts the border as part of the window rather than drawing it outside."
      checked: app.hyprValue("border-part-of-window", true) === true
      onRequested: function(next) { app.setHypr("border-part-of-window", next ? "true" : "false") }
      changed: app.isChanged("border-part-of-window")
      onResetRequested: app.resetSetting("border-part-of-window")
    }

    Ui.NumberRow {
      label: "Corner rounding"
      suffix: "px"
      value: app.hyprValue("rounding", 0)
      from: 0
      to: 30
      onCommitted: function(next) { app.setHypr("rounding", next) }
      changed: app.isChanged("rounding")
      onResetRequested: app.resetSetting("rounding")
    }

    Ui.FactorRow {
      label: "Roundness curve"
      description: "2.0 is a circle; higher gets you a squircle."
      minimum: 1
      maximum: 10
      value: app.hyprValue("rounding-power", 2)
      onCommitted: function(next) { app.setHypr("rounding-power", next) }
      changed: app.isChanged("rounding-power")
      onResetRequested: app.resetSetting("rounding-power")
    }
  }

  Ui.SettingGroup {
    title: "Snapping"

    Ui.SwitchRow {
      label: "Snapping"
      description: "Snap floating windows to each other and to screen edges."
      checked: app.hyprValue("snap", false) === true
      onRequested: function(next) { app.setHypr("snap", next ? "true" : "false") }
      changed: app.isChanged("snap")
      onResetRequested: app.resetSetting("snap")
    }

    Ui.NumberRow {
      label: "Snap distance"
      description: "How close a floating window gets before it snaps to another."
      suffix: "px"
      enabled: app.hyprValue("snap", false) === true
      value: app.hyprValue("snap-window-gap", 10)
      from: 0
      to: 50
      onCommitted: function(next) { app.setHypr("snap-window-gap", next) }
      changed: app.isChanged("snap-window-gap")
      onResetRequested: app.resetSetting("snap-window-gap")
    }

    Ui.NumberRow {
      label: "Snap to edges"
      description: "How close a floating window gets before it snaps to a screen edge."
      suffix: "px"
      enabled: app.hyprValue("snap", false) === true
      value: app.hyprValue("snap-monitor-gap", 10)
      from: 0
      to: 50
      onCommitted: function(next) { app.setHypr("snap-monitor-gap", next) }
      changed: app.isChanged("snap-monitor-gap")
      onResetRequested: app.resetSetting("snap-monitor-gap")
    }
  }

  Ui.SettingGroup {
    title: "Focus and depth"

    Ui.SwitchRow {
      label: "Full opacity"
      description: "Omarchy fades every window to 98.5%, which multiplies with the settings below. This clears it, so 100% is 100%."
      checked: app.hyprValue("opaque-windows", false) === true
      onRequested: function(next) { app.setHypr("opaque-windows", next ? "true" : "false") }
      changed: app.isChanged("opaque-windows")
      onResetRequested: app.resetSetting("opaque-windows")
    }

    Ui.PercentRow {
      label: "Active window opacity"
      value: app.hyprValue("active-opacity", 1)
      onCommitted: function(next) { app.setHypr("active-opacity", next) }
      changed: app.isChanged("active-opacity")
      onResetRequested: app.resetSetting("active-opacity")
    }

    Ui.PercentRow {
      label: "Inactive window opacity"
      value: app.hyprValue("inactive-opacity", 1)
      onCommitted: function(next) { app.setHypr("inactive-opacity", next) }
      changed: app.isChanged("inactive-opacity")
      onResetRequested: app.resetSetting("inactive-opacity")
    }

    Ui.PercentRow {
      label: "Fullscreen opacity"
      description: "Opacity while a window is fullscreen."
      value: app.hyprValue("fullscreen-opacity", 1)
      onCommitted: function(next) { app.setHypr("fullscreen-opacity", next) }
      changed: app.isChanged("fullscreen-opacity")
      onResetRequested: app.resetSetting("fullscreen-opacity")
    }

    Ui.SwitchRow {
      label: "Dim inactive windows"
      checked: app.hyprValue("dim-inactive", false) === true
      onRequested: function(next) { app.setHypr("dim-inactive", next ? "true" : "false") }
      changed: app.isChanged("dim-inactive")
      onResetRequested: app.resetSetting("dim-inactive")
    }

    Ui.PercentRow {
      label: "Dim strength"
      enabled: app.hyprValue("dim-inactive", false) === true
      value: app.hyprValue("dim-strength", 0.5)
      onCommitted: function(next) { app.setHypr("dim-strength", next) }
      changed: app.isChanged("dim-strength")
      onResetRequested: app.resetSetting("dim-strength")
    }

    Ui.PercentRow {
      label: "Special workspace dim"
      description: "Dimming applied behind a special workspace."
      value: app.hyprValue("dim-special", 0.2)
      onCommitted: function(next) { app.setHypr("dim-special", next) }
      changed: app.isChanged("dim-special")
      onResetRequested: app.resetSetting("dim-special")
    }

    Ui.PercentRow {
      label: "Dim around"
      description: "Dimming behind windows using the dimaround window rule."
      value: app.hyprValue("dim-around", 0.4)
      onCommitted: function(next) { app.setHypr("dim-around", next) }
      changed: app.isChanged("dim-around")
      onResetRequested: app.resetSetting("dim-around")
    }

    Ui.SwitchRow {
      label: "Dim behind modals"
      description: "Darkens a window while one of its dialogs is open."
      checked: app.hyprValue("dim-modal", true) === true
      onRequested: function(next) { app.setHypr("dim-modal", next ? "true" : "false") }
      changed: app.isChanged("dim-modal")
      onResetRequested: app.resetSetting("dim-modal")
    }
  }

  Ui.SettingGroup {
    title: "Animations"

    Ui.SwitchRow {
      label: "Animations"
      checked: app.hyprValue("animations", true) === true
      onRequested: function(next) { app.setHypr("animations", next ? "true" : "false") }
      changed: app.isChanged("animations")
      onResetRequested: app.resetSetting("animations")
    }

    Ui.FactorRow {
      label: "Speed"
      description: "A multiplier over the animation set Omarchy ships. Higher is faster."
      enabled: app.hyprValue("animations", true) === true
      minimum: 0.25
      maximum: 3
      value: app.hyprValue("animation-speed", 1)
      onCommitted: function(next) { app.setHypr("animation-speed", next) }
      changed: app.isChanged("animation-speed")
      onResetRequested: app.resetSetting("animation-speed")
    }

    Ui.SwitchRow {
      label: "Wrap workspaces"
      description: "Slides the short way when moving between the first and last workspace."
      enabled: app.hyprValue("animations", true) === true
      checked: app.hyprValue("animations-wraparound", false) === true
      onRequested: function(next) { app.setHypr("animations-wraparound", next ? "true" : "false") }
      changed: app.isChanged("animations-wraparound")
      onResetRequested: app.resetSetting("animations-wraparound")
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
