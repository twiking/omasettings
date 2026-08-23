# OmaSettings

**One window for every Omarchy setting, and one bar widget instead of six.**

<p align="center"><img src="preview.png" alt="The OmaSettings window" width="800"></p>

## Why I built it

Two reasons.

**I wanted to see what I could change.** Omarchy is configurable to a fault, but
finding a setting meant knowing which file it lived in — `shell.json`, one of
the Lua files under `~/.config/hypr`, `~/.XCompose`, an application's own
config — and then reading enough documentation to know what the value should
be. Nothing showed you the whole surface. This does: every setting on a page,
named, described, searchable, with its current value in front of you. Type
"blur" and the eleven settings under it appear, whatever file they belong to.

**I wanted my bar back.** Audio, network, bluetooth, power, displays — each had
a widget, and between them they ate the space I would rather give to something
that does work. All of them are pages here, so one gear replaces the lot and
the bar has room for widgets that earn it.

## Sections

| Section | What it covers | Where it lands |
|---|---|---|
| Appearance | Theme, font, text size, night light, background, boot screen, screensaver and about branding | `omarchy theme set` / `omarchy font set` / `omarchy display text size` / Omarchy menu Style |
| Bar | Position, transparency, centred widget | `~/.config/omarchy/shell.json` |
| Windows | Gaps, borders, snapping, corner rounding, window and fullscreen opacity, dimming, animations and their speed | Hyprland |
| Layout | The tiling engine, and the knobs belonging to whichever one is running: dwindle, master or scrolling | Hyprland |
| Effects | Blur in full, drop shadow, and the focus glow | Hyprland |
| Groups | The tab strip on grouped windows: height, titles, indicator, rounding, gradients | Hyprland |
| Keyboard | Layouts, variant, XKB options, repeat rate and delay, num lock | Hyprland |
| Keybindings | Every binding, searchable; add your own, turn Omarchy's off, put them back | `~/.config/hypr/bindings.lua` |
| Keyboard, Mouse & Touchpad | Also per device: one keyboard or pointer can depart from the global settings, via Hyprland's `hl.device` |  |
| Mouse & Touchpad | Sensitivity, acceleration, focus-follows-mouse, natural scroll, tap to click, two-finger right click, disable-while-typing, scroll speed | Hyprland |
| Displays | Per-monitor scale | Hyprland |
| Idle & Lock | Screensaver and lock timeouts, unlock animation | `~/.config/omarchy/shell.json` / Omarchy menu Style → Unlock |
| Plugins | Enable, disable, add, remove and update installed shell plugins, with a count of what is behind | `omarchy plugin ...` |
| Compose Keys | Your `<Multi_key>` sequences: list, add, remove | `~/.XCompose` |
| Date & Time | Timezone and system time resync | Omarchy menu Update → Timezone / Time |
| Network | Wi-Fi networks, address and gateway, band, DNS resolver, Wi-Fi QR code | NetworkManager / `omarchy-network-band` / Omarchy menu Setup → Network |
| Audio | Output and input device, volume and mute for each | `pactl` |
| Power | Charge, time remaining, draw, health, and the power profile per power source | `upower` / `omarchy-powerprofiles-set` |
| Bluetooth | Adapter power, paired and nearby devices, connect, pair, forget | `omarchy-bluetooth-power` / `omarchy-bluetooth-device` |
| Applications → Defaults | Browser, terminal, editor, coding agent | Omarchy menu Setup → Defaults |
| Applications → Herdr | Herdr's appearance, panes, sidebar, behaviour, notifications and prefix key | `~/.config/herdr/config.toml` |
| Applications → Tmux | Prefix, copy-mode keys, status bar, window and pane numbering, mouse, scrollback, clipboard | `~/.config/tmux/tmux.conf` |
| Applications → Neovim | Gutter, wrapping, column guide, scrolloff, spell, indentation | `~/.config/nvim/lua/config/options.lua` |

The Style, Setup and Update sections are read from the Omarchy menu's own definition
(`omarchy-menu.jsonc`, defaults plus your extensions) rather than a second
list that can drift, so its entries and actions are exactly the menu's
Setup → Defaults → Agent and Update → Timezone / Time: picking an agent that
is not installed opens a terminal to set it up, the current one is marked with
the menu's own `checked` test, and the timezone button opens the same picker
the menu opens. The current timezone and clock are shown next to the buttons
so you can see what you are changing.

## How it writes

Your config files are never parsed and rewritten — that is how a settings app
eats someone's setup. Instead:

- **Hyprland settings** are applied live with `hyprctl eval` and written to a
  file of its own, `~/.config/hypr/omasettings.lua`, loaded last from a single
  `require` line appended to your `hyprland.lua`. Your own files keep saying
  exactly what you wrote; delete a line from the generated one to hand that
  setting back.
- **Keybindings** live in a marked block in `bindings.lua`. Everything outside
  the markers is copied through untouched.
- **Everything else** — Herdr, tmux, Neovim — is edited one value at a time,
  in place, keeping the comment attached to the line it belongs to.

Before the first write to any file you could have written yourself, a copy is
kept beside it as `<file>.omasettings.bak`. Every write is checked in the
format's own terms — `herdr config check`, compiling the Lua, applying the
tmux option — and rolled back if it fails.

Anything the window changes can be put back, and it keeps a note of what each
setting was before it first touched it. See `CLAUDE.md` for how all of this
works inside.

## What it needs

Omarchy itself, and the tools its own commands already use. Nothing here needs
root, and nothing is installed on your behalf — a page whose tool is missing
says so rather than failing.

| Tool | Used for |
| --- | --- |
| `jq` | every read and write; the whole helper is JSON |
| `hyprctl` | reading and applying Hyprland settings |
| `xkbcli` | checking a keyboard layout compiles before writing it (skipped if absent) |
| `pactl` | audio devices, volume and mute |
| `nmcli` | Wi-Fi networks and connection details |
| `bluetoothctl` | paired and nearby devices |
| `upower`, `powerprofilesctl` | battery reading and the power profile |
| `timedatectl` | timezone and clock |
| `lua`, `luac` | reading and checking the Hyprland Lua it writes |
| `tmux`, `git` | the Tmux page; plugin update checks |

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
- **SUPER+SPACE**, then "OmaSettings" — it installs a launcher entry, so it is
  reachable as an application and not only from the bar.
- **Escape** closes the window.

### Changed settings

A setting you have changed is marked, and goes back with the `(reset)` beside
its name or with `Backspace`. Change it back yourself and the mark clears —
a switch flipped and flipped back is not a change.

The sidebar counts what you have changed and offers **Reset all settings**
(`Ctrl+Backspace`), which asks first.

### Search

The box above the menu filters every page at once: pages with nothing matching
leave the menu, the rest carry the number that matched, and the open page shows
only what matched.

It searches more than setting names — the heading above a setting, the page it
is on, and your own things, so "blur" finds all eleven settings under **Blur**,
"bluetooth" finds that whole page though no row carries the word, and a
Bluetooth device, a network or a keybinding can be found by name.

### Keyboard

The window is fully drivable from the keyboard, in the vocabulary every
Omarchy panel uses:

| Key | Does |
| --- | --- |
| `Up` / `Down`, or `k` / `j` | Move the cursor through the settings on the page |
| `Alt+Up` / `Alt+Down` | Move through the sidebar, opening each page as you land on it |
| `Left` / `Right`, or `h` / `l` | Step a slider, or pick the neighbouring option |
| `Space` or `Enter` | Flip a switch, open a list, press a button, start typing in a field |
| `Enter` while typing | Commit the field and hand the keyboard back |
| `Enter` on a sidebar heading | Open or close its submenu |
| `Backspace` | Hand the setting under the cursor back to the system, if you changed it |
| `Ctrl+Backspace` | Reset everything changed from this window, after asking |
| `Home` / `End` | First and last setting on the page |
| `Tab` | Swap between the sidebar and the page |
| `/` or `Ctrl+F` | Jump to the search box |
| `Escape` in the search box | Clear the search and hand the keyboard back |
| `Escape` | Close an open list, or the window |

The bar along the foot of the window says what the keys do where you are: the
ones that always apply, plus whatever the cursor is resting on — `Space` on a
switch, `\u2194` on a slider, `\u232b` on a setting you have changed.

The cursor is a band across the row it is on, and the page scrolls to keep it
in view. While a list is open it owns the keyboard, so its own `Up`/`Down`
walk the options and `Escape` closes the list rather than the window.
- From anywhere: `omarchy-shell omasettings toggle` (also `show` / `hide`) —
  handy on a keybinding:

  ```lua
  -- ~/.config/hypr/bindings.lua
  o.bind("SUPER + COMMA", "Settings", "omarchy-shell omasettings toggle")
  ```

Sliders write when you let go, not while you drag, so a drag across the track
is one change rather than one per pixel. Text fields commit on Enter or when
they lose focus.

**The launcher entry** is installed by the plugin, because Omarchy has no
install hook. Enabling writes `~/.local/share/applications/omasettings.desktop`
with the icon that ships beside it; disabling or removing deletes it again.
Only a file carrying `X-OmaSettings-Managed=true` is ever touched, so your own
entry at that path is left alone.

## License

MIT — see [LICENSE](LICENSE).
