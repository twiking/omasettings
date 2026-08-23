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
    title: "Keys"

    Ui.TextRow {
      label: "Prefix"
      description: "tmux spelling: C-Space, C-b, M-a."
      placeholder: "C-b"
      value: String(app.tmuxValue("prefix", "C-b"))
      onCommitted: function(next) { app.setTmux("prefix", next) }
      changed: app.isChanged("tmux:prefix")
      onResetRequested: app.resetSetting("tmux:prefix")
    }

    Ui.PickerRow {
      label: "Copy mode keys"
      value: String(app.tmuxValue("mode-keys", "emacs"))
      options: [
        { value: "vi", label: "Vi" },
        { value: "emacs", label: "Emacs" }
      ]
      onPicked: function(next) { app.setTmux("mode-keys", next) }
      changed: app.isChanged("tmux:mode-keys")
      onResetRequested: app.resetSetting("tmux:mode-keys")
    }

    Ui.ActionRow {
      label: "Every shortcut"
      description: "The full list, as tmux has it."
      buttonText: "Show…"
      onTriggered: app.run(["menu", "run", "learn.tmux-keybindings"])
    }
  }

  Ui.SettingGroup {
    title: "Status bar"

    Ui.PickerRow {
      label: "Position"
      value: String(app.tmuxValue("status-position", "bottom"))
      options: [
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" }
      ]
      onPicked: function(next) { app.setTmux("status-position", next) }
      changed: app.isChanged("tmux:status-position")
      onResetRequested: app.resetSetting("tmux:status-position")
    }
  }

  Ui.SettingGroup {
    title: "Windows and panes"

    Ui.NumberRow {
      label: "First window number"
      value: Number(app.tmuxValue("base-index", 0))
      from: 0
      to: 1
      onCommitted: function(next) { app.setTmux("base-index", next) }
      changed: app.isChanged("tmux:base-index")
      onResetRequested: app.resetSetting("tmux:base-index")
    }

    Ui.NumberRow {
      label: "First pane number"
      value: Number(app.tmuxValue("pane-base-index", 0))
      from: 0
      to: 1
      onCommitted: function(next) { app.setTmux("pane-base-index", next) }
      changed: app.isChanged("tmux:pane-base-index")
      onResetRequested: app.resetSetting("tmux:pane-base-index")
    }

    Ui.SwitchRow {
      label: "Renumber when one closes"
      checked: app.tmuxValue("renumber-windows", false) === true
      onRequested: function(next) { app.setTmux("renumber-windows", next ? "true" : "false") }
      changed: app.isChanged("tmux:renumber-windows")
      onResetRequested: app.resetSetting("tmux:renumber-windows")
    }
  }

  Ui.SettingGroup {
    title: "Behaviour"

    Ui.SwitchRow {
      label: "Mouse"
      description: "Click to focus a pane, drag to resize, scroll to page back."
      checked: app.tmuxValue("mouse", false) === true
      onRequested: function(next) { app.setTmux("mouse", next ? "true" : "false") }
      changed: app.isChanged("tmux:mouse")
      onResetRequested: app.resetSetting("tmux:mouse")
    }

    Ui.NumberRow {
      label: "Scrollback"
      suffix: "lines"
      value: Number(app.tmuxValue("history-limit", 2000))
      from: 1000
      to: 100000
      step: 1000
      onCommitted: function(next) { app.setTmux("history-limit", next) }
      changed: app.isChanged("tmux:history-limit")
      onResetRequested: app.resetSetting("tmux:history-limit")
    }

    Ui.NumberRow {
      label: "Escape delay"
      suffix: "ms"
      description: "Low values keep Esc snappy in Vim; zero can break some terminals."
      value: Number(app.tmuxValue("escape-time", 500))
      from: 0
      to: 500
      step: 10
      onCommitted: function(next) { app.setTmux("escape-time", next) }
      changed: app.isChanged("tmux:escape-time")
      onResetRequested: app.resetSetting("tmux:escape-time")
    }

    Ui.PickerRow {
      label: "Clipboard"
      description: "Whether tmux hands copied text to the outer terminal."
      value: String(app.tmuxValue("set-clipboard", "external"))
      options: [
        { value: "on", label: "On" },
        { value: "external", label: "External only" },
        { value: "off", label: "Off" }
      ]
      onPicked: function(next) { app.setTmux("set-clipboard", next) }
      changed: app.isChanged("tmux:set-clipboard")
      onResetRequested: app.resetSetting("tmux:set-clipboard")
    }
  }

  Ui.SettingGroup {
    title: "Beyond these settings"

    Ui.ActionRow {
      label: "The rest of the config"
      description: "Open tmux.conf for bindings, styling, and plugins."
      buttonText: "Edit…"
      onTriggered: app.editConfig("$HOME/.config/tmux/tmux.conf")
    }
  }
}
