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
    title: "Appearance"

    Ui.PickerRow {
      label: "Theme"
      value: String(app.herdrValue("theme.name", "catppuccin"))
      options: [
        { value: "terminal", label: "Terminal palette" },
        { value: "catppuccin", label: "Catppuccin" },
        { value: "tokyo-night", label: "Tokyo Night" },
        { value: "dracula", label: "Dracula" },
        { value: "nord", label: "Nord" },
        { value: "gruvbox", label: "Gruvbox" },
        { value: "one-dark", label: "One Dark" },
        { value: "solarized", label: "Solarized" },
        { value: "kanagawa", label: "Kanagawa" },
        { value: "rose-pine", label: "Rosé Pine" },
        { value: "vesper", label: "Vesper" }
      ]
      onPicked: function(next) { app.setHerdr("theme.name", next) }
    }

    Ui.TextRow {
      label: "Accent"
      description: "A colour name, #rrggbb, or rgb(r,g,b)."
      placeholder: "cyan"
      value: String(app.herdrValue("ui.accent", "cyan"))
      onCommitted: function(next) { app.setHerdr("ui.accent", next) }
    }

    Ui.PickerRow {
      label: "Tab bar"
      value: String(app.herdrValue("ui.tab_bar_position", "top"))
      options: [
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" }
      ]
      onPicked: function(next) { app.setHerdr("ui.tab_bar_position", next) }
    }

    Ui.SwitchRow {
      label: "Hide the tab bar with one tab"
      checked: app.herdrValue("ui.hide_tab_bar_when_single_tab", false) === true
      onRequested: function(next) { app.setHerdr("ui.hide_tab_bar_when_single_tab", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Panes"

    Ui.SwitchRow {
      label: "Borders"
      checked: app.herdrValue("ui.pane_borders", true) === true
      onRequested: function(next) { app.setHerdr("ui.pane_borders", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Outer border"
      description: "Off gives tmux-style splitters with no frame around the edge."
      checked: app.herdrValue("ui.pane_outer_borders", true) === true
      onRequested: function(next) { app.setHerdr("ui.pane_outer_borders", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Gaps between panes"
      checked: app.herdrValue("ui.pane_gaps", true) === true
      onRequested: function(next) { app.setHerdr("ui.pane_gaps", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Scrollbars"
      checked: app.herdrValue("ui.pane_scrollbars", true) === true
      onRequested: function(next) { app.setHerdr("ui.pane_scrollbars", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Agent labels on borders"
      description: "Shown when a pane has no name of its own."
      checked: app.herdrValue("ui.show_agent_labels_on_pane_borders", false) === true
      onRequested: function(next) { app.setHerdr("ui.show_agent_labels_on_pane_borders", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Sidebar"

    Ui.NumberRow {
      label: "Width"
      suffix: "columns"
      value: Number(app.herdrValue("ui.sidebar_width", 26))
      from: 12
      to: 60
      onCommitted: function(next) { app.setHerdr("ui.sidebar_width", next) }
    }

    Ui.SwitchRow {
      label: "Start collapsed"
      description: "Takes effect the next time Herdr launches."
      checked: app.herdrValue("ui.sidebar_start_collapsed", false) === true
      onRequested: function(next) { app.setHerdr("ui.sidebar_start_collapsed", next ? "true" : "false") }
    }

    Ui.PickerRow {
      label: "When collapsed"
      value: String(app.herdrValue("ui.sidebar_collapsed_mode", "compact"))
      options: [
        { value: "compact", label: "Keep the status rail" },
        { value: "hidden", label: "Hide it completely" }
      ]
      onPicked: function(next) { app.setHerdr("ui.sidebar_collapsed_mode", next) }
    }
  }

  Ui.SettingGroup {
    title: "Behaviour"

    Ui.PickerRow {
      label: "New panes open in"
      value: String(app.herdrValue("terminal.new_cwd", "follow"))
      options: [
        { value: "follow", label: "The folder you were in" },
        { value: "home", label: "Your home folder" },
        { value: "current", label: "Herdr's own folder" }
      ]
      onPicked: function(next) { app.setHerdr("terminal.new_cwd", next) }
    }

    Ui.SwitchRow {
      label: "Capture the mouse"
      description: "Off lets the terminal handle clicks, so links stay clickable."
      checked: app.herdrValue("ui.mouse_capture", true) === true
      onRequested: function(next) { app.setHerdr("ui.mouse_capture", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Copy on selection"
      checked: app.herdrValue("ui.copy_on_select", true) === true
      onRequested: function(next) { app.setHerdr("ui.copy_on_select", next ? "true" : "false") }
    }

    Ui.NumberRow {
      label: "Scroll step"
      suffix: "lines"
      value: Number(app.herdrValue("ui.mouse_scroll_lines", 3))
      from: 1
      to: 10
      onCommitted: function(next) { app.setHerdr("ui.mouse_scroll_lines", next) }
    }

    Ui.SwitchRow {
      label: "Confirm before closing"
      checked: app.herdrValue("ui.confirm_close", true) === true
      onRequested: function(next) { app.setHerdr("ui.confirm_close", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Ask for a tab name"
      checked: app.herdrValue("ui.prompt_new_tab_name", true) === true
      onRequested: function(next) { app.setHerdr("ui.prompt_new_tab_name", next ? "true" : "false") }
    }

    Ui.SwitchRow {
      label: "Ask for a workspace name"
      checked: app.herdrValue("ui.prompt_new_workspace_name", false) === true
      onRequested: function(next) { app.setHerdr("ui.prompt_new_workspace_name", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Notifications"

    Ui.PickerRow {
      label: "Pop-ups"
      value: String(app.herdrValue("ui.toast.delivery", "off"))
      options: [
        { value: "off", label: "None" },
        { value: "herdr", label: "Inside Herdr" },
        { value: "terminal", label: "Through the terminal" },
        { value: "system", label: "Desktop notifications" }
      ]
      onPicked: function(next) { app.setHerdr("ui.toast.delivery", next) }
    }

    Ui.SwitchRow {
      label: "Sounds"
      description: "Played when an agent changes state in a background workspace."
      checked: app.herdrValue("ui.sound.enabled", true) === true
      onRequested: function(next) { app.setHerdr("ui.sound.enabled", next ? "true" : "false") }
    }
  }

  Ui.SettingGroup {
    title: "Keys"

    Ui.TextRow {
      label: "Prefix"
      description: "Every prefix+… shortcut starts with this."
      placeholder: "ctrl+b"
      value: String(app.herdrValue("keys.prefix", "ctrl+b"))
      onCommitted: function(next) { app.setHerdr("keys.prefix", next) }
    }

    Ui.ActionRow {
      label: "Every shortcut"
      description: "The full list, as Herdr has it."
      buttonText: "Show…"
      onTriggered: app.run(["menu", "run", "learn.herdr-keybindings"])
    }

    Ui.ActionRow {
      label: "The rest of the config"
      description: "Open config.toml for the settings this page does not cover."
      buttonText: "Edit…"
      onTriggered: app.editConfig("$HOME/.config/herdr/config.toml")
    }
  }

  Ui.SettingGroup {
    title: "Window title"

    Ui.TextRow {
      label: "Title"
      description: "Tokens: {hostname}, {workspace}, {tab}, {pane}, {terminal_title}."
      placeholder: "{hostname}: {workspace}"
      value: String(app.herdrValue("ui.window_title", ""))
      onCommitted: function(next) { app.setHerdr("ui.window_title", next) }
    }
  }
}
