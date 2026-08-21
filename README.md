# OmaSettings

An Omarchy shell plugin: the settings you actually change day to day — theme,
font, where the bar sits, night light, and how long until the screensaver and
lock kick in — gathered behind one gear in the bar.

<p align="center"><img src="preview.png" alt="OmaSettings panel" width="320"></p>

Every control is a front end for the `omarchy` command that already owns that
setting, so nothing here writes state the CLI would not write itself.

| Control | What it runs |
|---|---|
| Theme | `omarchy-theme-set <name>` |
| Font | `omarchy font set <name>` |
| Bar position | `omarchy bar position <top\|bottom\|left\|right>` |
| Transparent bar | `omarchy bar transparent <true\|false>` |
| Night light | `omarchy-toggle-nightlight` (only when the state differs) |
| Screensaver after | `idle.screensaver` in `~/.config/omarchy/shell.json` |
| Lock after | `idle.lock` in `~/.config/omarchy/shell.json` |

The idle sliders work in whole minutes, so a value stored in seconds is shown
rounded and committed as `minutes × 60`. Only releasing the slider writes — a
drag across the track is one change, not one per pixel.

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

- **Left click** the gear opens the panel; **right click** re-reads the current
  state without opening it.
- The panel reads its state when it opens, not on a timer, so changes made
  elsewhere (the Omarchy menu, a keybinding, another machine's dotfiles) show
  up the next time it is opened.

## Settings

Configured per bar entry in `~/.config/omarchy/shell.json`:

| Key | Default | Meaning |
|---|---|---|
| `maxIdleMinutes` | `60` | Upper end of the screensaver and lock sliders |

## Layout

```
manifest.json     Plugin manifest (bar-widget kind, settings schema)
Panel.qml         Bar button + settings panel
bin/omasettings   State reader and mutator: `omasettings state`, `omasettings set <key> <value>`
```

`bin/omasettings` is a normal script and is usable on its own:

```bash
bin/omasettings state | jq .
bin/omasettings set theme "Tokyo Night"
bin/omasettings set idle-lock 600
```

It requires `jq` and the `omarchy` command line, both of which Omarchy ships.

## License

MIT — see [LICENSE](LICENSE).
