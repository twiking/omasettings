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
      label: "Floating gaps"
      description: "Gap around floating windows. 0 follows the inner gap."
      suffix: "px"
      value: app.hyprValue("float-gaps", 0)
      from: 0
      to: 40
      onCommitted: function(next) { app.setHypr("float-gaps", next) }
    }

    Ui.NumberRow {
      label: "Workspace gaps"
      description: "Extra space between workspaces while they slide past."
      suffix: "px"
      value: app.hyprValue("gaps-workspaces", 0)
      from: 0
      to: 100
      onCommitted: function(next) { app.setHypr("gaps-workspaces", next) }
    }

    Ui.SwitchRow {
      label: "Border inside window"
      description: "Counts the border as part of the window rather than drawing it outside."
      checked: app.hyprValue("border-part-of-window", true) === true
      onRequested: function(next) { app.setHypr("border-part-of-window", next ? "true" : "false") }
    }

    Ui.NumberRow {
      label: "Corner rounding"
      suffix: "px"
      value: app.hyprValue("rounding", 0)
      from: 0
      to: 30
      onCommitted: function(next) { app.setHypr("rounding", next) }
    }

    Ui.FactorRow {
      label: "Roundness curve"
      description: "2.0 is a circle; higher gets you a squircle."
      minimum: 1
      maximum: 10
      value: app.hyprValue("rounding-power", 2)
      onCommitted: function(next) { app.setHypr("rounding-power", next) }
    }
  }

  Ui.SettingGroup {
    title: "Snapping"

    Ui.SwitchRow {
      label: "Snapping"
      description: "Snap floating windows to each other and to screen edges."
      checked: app.hyprValue("snap", false) === true
      onRequested: function(next) { app.setHypr("snap", next ? "true" : "false") }
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

    Ui.PercentRow {
      label: "Fullscreen opacity"
      description: "Opacity while a window is fullscreen."
      value: app.hyprValue("fullscreen-opacity", 1)
      onCommitted: function(next) { app.setHypr("fullscreen-opacity", next) }
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

    Ui.PercentRow {
      label: "Special workspace dim"
      description: "Dimming applied behind a special workspace."
      value: app.hyprValue("dim-special", 0.2)
      onCommitted: function(next) { app.setHypr("dim-special", next) }
    }

    Ui.PercentRow {
      label: "Dim around"
      description: "Dimming behind windows using the dimaround window rule."
      value: app.hyprValue("dim-around", 0.4)
      onCommitted: function(next) { app.setHypr("dim-around", next) }
    }

    Ui.SwitchRow {
      label: "Dim behind modals"
      description: "Darkens a window while one of its dialogs is open."
      checked: app.hyprValue("dim-modal", true) === true
      onRequested: function(next) { app.setHypr("dim-modal", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Animations"

    Ui.SwitchRow {
      label: "Animations"
      checked: app.hyprValue("animations", true) === true
      onRequested: function(next) { app.setHypr("animations", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Wrap workspaces"
      description: "Slides the short way when moving between the first and last workspace."
      enabled: app.hyprValue("animations", true) === true
      checked: app.hyprValue("animations-wraparound", false) === true
      onRequested: function(next) { app.setHypr("animations-wraparound", next ? "true" : "false") }
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
