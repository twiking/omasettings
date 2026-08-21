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
    title: "The gutter"

    Ui.SwitchRow {
      label: "Line numbers"
      checked: app.nvimValue("number", true) === true
      onRequested: function(next) { app.setNvim("number", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Relative line numbers"
      checked: app.nvimValue("relativenumber", true) === true
      onRequested: function(next) { app.setNvim("relativenumber", next ? "true" : "false") }
    }

    Ui.PickerRow {
      label: "Sign column"
      description: "Where git marks and diagnostics appear."
      value: String(app.nvimValue("signcolumn", "yes"))
      options: [
        { value: "yes", label: "Always" },
        { value: "auto", label: "Only when needed" },
        { value: "no", label: "Never" }
      ]
      onPicked: function(next) { app.setNvim("signcolumn", next) }
    }
  }

  Ui.SettingGroup {
    title: "The text"

    Ui.SwitchRow {
      label: "Wrap long lines"
      checked: app.nvimValue("wrap", false) === true
      onRequested: function(next) { app.setNvim("wrap", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Highlight the current line"
      checked: app.nvimValue("cursorline", true) === true
      onRequested: function(next) { app.setNvim("cursorline", next ? "true" : "false") }
    }

    Ui.TextRow {
      label: "Column guide"
      description: "A column number, or empty for none."
      placeholder: "100"
      value: String(app.nvimValue("colorcolumn", ""))
      onCommitted: function(next) { app.setNvim("colorcolumn", next) }
    }

    Ui.NumberRow {
      label: "Keep visible above and below"
      suffix: "lines"
      value: Number(app.nvimValue("scrolloff", 4))
      from: 0
      to: 20
      onCommitted: function(next) { app.setNvim("scrolloff", next) }
    }

    Ui.SwitchRow {
      label: "Spell checking"
      checked: app.nvimValue("spell", false) === true
      onRequested: function(next) { app.setNvim("spell", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Indentation"

    Ui.SwitchRow {
      label: "Spaces instead of tabs"
      checked: app.nvimValue("expandtab", true) === true
      onRequested: function(next) { app.setNvim("expandtab", next ? "true" : "false") }
    }

    Ui.NumberRow {
      label: "Indent width"
      suffix: "spaces"
      value: Number(app.nvimValue("shiftwidth", 2))
      from: 1
      to: 8
      onCommitted: function(next) { app.setNvim("shiftwidth", next) }
    }

    Ui.NumberRow {
      label: "Tab width"
      suffix: "spaces"
      value: Number(app.nvimValue("tabstop", 2))
      from: 1
      to: 8
      onCommitted: function(next) { app.setNvim("tabstop", next) }
    }
  }

  Ui.SettingGroup {
    title: "Beyond these settings"
    note: "Changes here apply the next time Neovim starts."

    Ui.ActionRow {
      label: "The rest of the config"
      description: "Open options.lua for anything this page does not cover."
      buttonText: "Edit…"
      onTriggered: app.editConfig("$HOME/.config/nvim/lua/config/options.lua")
    }
  }
}
