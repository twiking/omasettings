# OmaSettings

An Omarchy shell plugin: one window for the settings that otherwise live
scattered across `~/.config/omarchy/shell.json`, the Hyprland config in
`~/.config/hypr`, and `~/.XCompose`.

<p align="center"><img src="preview.png" alt="The OmaSettings window" width="640"></p>

## Sections

| Section | What it covers | Where it lands |
|---|---|---|
| Appearance | Theme, font, text size, night light | `omarchy theme set` / `omarchy font set` / `omarchy display text size` |
| Bar | Position, transparency, centred widget | `~/.config/omarchy/shell.json` |
| Windows | Gaps, border, rounding, window opacity, dim, animations, blur | Hyprland |
| Keyboard | Layouts, variant, XKB options, repeat rate and delay, num lock | Hyprland |
| Mouse & Touchpad | Sensitivity, acceleration, focus-follows-mouse, natural scroll, tap to click, two-finger right click, disable-while-typing, scroll speed | Hyprland |
| Displays | Per-monitor scale | Hyprland |
| Idle & Lock | Screensaver and lock timeouts | `~/.config/omarchy/shell.json` |
| Plugins | Enable and disable installed shell plugins | `omarchy plugin enable/disable` |
| Compose Keys | Your `<Multi_key>` sequences: list, add, remove | `~/.XCompose` |

## How it writes

Two rules shape the whole plugin.

**Your config files are never rewritten.** Parsing and rewriting hand-written
Lua or conf is how a settings app eats someone's setup. Instead every Hyprland
change is applied live with `hyprctl keyword` and recorded in OmaSettings' own
store (`~/.config/omarchy/omasettings.json`), which is rendered into a
generated `~/.config/hypr/omasettings.lua` (or `omasettings.conf` on pre-Lua
setups). A single `require("hypr.omasettings")` line is appended to your
`hyprland.lua` the first time something is saved, and it is loaded last, so
your own files keep saying exactly what you wrote. Delete a line from the
generated file to hand that setting back to your config.

Everything else goes through the `omarchy` command that already owns the
setting — themes, fonts, text size, the bar, plugin enablement — rather than
being written behind its back.

**Anything hand-written is backed up before the first touch.** The first time
OmaSettings writes to a file you could have edited yourself — `hyprland.lua`,
`shell.json`, `.XCompose` — it copies it to `<file>.omasettings.bak`. Only the
first time: later writes never overwrite that pristine copy. Files OmaSettings
generates in full are not backed up, because there is no version of them worth
keeping.

Values are read back from the live system (`hyprctl getoption`, `omarchy
theme current`, …), not from the store, so settings changed elsewhere show up
correctly the next time the window opens.

## Install

```bash
omarchy plugin add https://github.com/twiking/omasettings --enable
```

Or from a local checkout:

```bash
ln -s ~/Dev/omasettings ~/.config/omarchy/plugins/io.github.twiking.omasettings
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.twiking.omasettings right
```

Remove it with `omarchy plugin remove io.github.twiking.omasettings`.

## Using it

- **Left click** the gear in the bar to open and close the window;
  **right click** opens the Omarchy menu.
- **Escape** closes the window.
- From anywhere: `omarchy-shell omasettings toggle` (also `show` / `hide`) —
  handy on a keybinding:

  ```lua
  -- ~/.config/hypr/bindings.lua
  o.bind("SUPER + COMMA", "Settings", "omarchy-shell omasettings toggle")
  ```

Sliders write when you let go, not while you drag, so a drag across the track
is one change rather than one per pixel. Text fields commit on Enter or when
they lose focus.

## Layout

```
manifest.json       Plugin manifest
Panel.qml           Bar gear; loads the window on first use
SettingsWindow.qml  The settings window: sidebar, sections, shared row types
bin/omasettings     Everything that touches the system
```

`bin/omasettings` is a normal script and is usable on its own:

```bash
bin/omasettings state | jq .
bin/omasettings set theme "Tokyo Night"
bin/omasettings set gaps-in 8
bin/omasettings set idle-lock 600
bin/omasettings plugin disable io.github.twiking.omatop
bin/omasettings compose add '<Multi_key> <s> <e>' 'hello'
bin/omasettings compose remove '<Multi_key> <s> <e>'
```

It needs `jq`, `hyprctl`, and the `omarchy` command line, all of which Omarchy
ships. Environment overrides (`OMASETTINGS_STORE`, `OMASETTINGS_HYPR_DIR`,
`OMASETTINGS_XCOMPOSE`, `OMARCHY_SHELL_JSON`) point it at a sandbox for
testing.

## License

MIT — see [LICENSE](LICENSE).
