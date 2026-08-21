# OmaSettings

An Omarchy shell plugin: one window for the settings that otherwise live
scattered across `~/.config/omarchy/shell.json`, the Hyprland config, the
per-application configs, and `~/.XCompose`.

It runs inside `omarchy-shell` — a single long-lived Quickshell (QML) process
that also draws the bar. There is no separate app: the bar widget loads the
window on first use.

## Layout, and what each part may know

```
manifest.json          Plugin manifest — id, kinds, entry point
Panel.qml              The bar gear; loads SettingsWindow.qml on first use
SettingsWindow.qml     Window chrome, sidebar, page routing, and the state
                       every page reads. Pages reach it as `app`.
ui/                    Presentational components + the Palette singleton
sections/              One file per page
bin/omasettings        Subcommand routing
lib/                   One module per thing being configured
```

Three rules keep the split honest:

- A `ui/` component knows how a control looks and reports what happened
  through a **signal**. It never knows which setting it is editing, and never
  reaches back into the window.
- A `sections/` page knows what its settings mean and calls `app` to read and
  write them. It never shells out.
- `lib/` shells out. It never knows what any of it looks like.

When a page needs something new, the value goes into `lib/state.sh`'s single
JSON document and a getter goes on the window; the page reads `app.something`.

## The one rule about other people's files

**Never parse and rewrite a hand-written config.** That is how a settings app
eats someone's setup. Every file falls into one of three patterns:

1. **Generated wholly by us** — `~/.config/hypr/omasettings.lua`, rendered
   from our store (`~/.config/omarchy/omasettings.json`). Hyprland settings are
   applied live with `hyprctl keyword` and recorded there; the generated file is
   loaded last so the user's own files still say what they wrote.
2. **A marked block inside their file** — keybindings, appended to
   `bindings.lua` between `-- >>> omasettings bindings` markers. Everything
   outside the markers is copied through untouched, and removing the last
   binding removes the block.
3. **Edited in place, one value at a time** — `herdr/config.toml`, `tmux.conf`,
   Neovim's `options.lua`. These are hand-written *and* commented, so a value is
   replaced exactly where it stands (keeping its comment attached) and a new one
   is appended to its table or file.

Two invariants on top:

- **First-touch backup.** `backup_once` copies any hand-written file to
  `<file>.omasettings.bak` before the first write, and never again — later
  writes must not overwrite the pristine copy. Files we generate get no backup.
- **Validate, then roll back.** Each format is checked in its own terms:
  Herdr with `herdr config check`, Neovim by compiling the Lua, tmux by applying
  the option to the running server. On failure, restore the previous content and
  `die` with the tool's own message.

## Prefer Omarchy's commands to reimplementing them

Where Omarchy ships a command, drive it. It usually knows something you don't:

- `omarchy-bluetooth-power` clears an **rfkill soft block** rather than setting
  BlueZ's `Powered`, because BlueZ forgets across reboots and rfkill doesn't.
- `omarchy-bluetooth-device` trusts a device before connecting it.
- `omarchy-network-band` pins the band the same way the bar widget does.
- `omarchy-default-agent` / `-browser` / `-editor` install what is missing.

The Omarchy **menu definition** (`omarchy-menu.jsonc`, defaults merged with
`~/.config/omarchy/extensions/`) is the source of truth for pick-one groups —
agents, browsers, DNS providers. `menu_group_state` reads a group, and
`menu_run <entry-id>` runs an entry's action exactly as the menu would. Never
keep a second copy of those lists; they drift.

## Testing

There is no hot reload worth trusting for structural changes. The loop is:

```bash
omarchy plugin validate .                 # manifest against the schema
omarchy restart shell                     # ~7s; the bar is dead meanwhile
sleep 8
omarchy-shell omasettings show            # or hide / toggle
journalctl --user --since "-20 s" --no-pager | grep -i omasettings
```

QML errors surface **only** in the journal — a page that fails to load leaves
the window blank with no other sign. Grep for `qml`, `not a type`,
`non-existent property` and `undefined`.

To see a page without clicking, set `property string pageId` in
`SettingsWindow.qml`, restart, screenshot with `grim`, then set it back to
`"appearance"` before committing.

```bash
geom=$(hyprctl -j clients | jq -r '.[]|select(.title=="OmaSettings")
  |"\(((.size[0])*1.6)|floor)x\(((.size[1])*1.6)|floor)+\(((.at[0])*1.6)|floor)+\(((.at[1])*1.6)|floor)"')
grim -o DP-2 shot.png && magick shot.png -crop "$geom" +repage page.png
```

(The ×1.6 is this monitor's scale: `hyprctl clients` reports logical pixels,
`grim` captures physical ones.)

The CLI is testable on its own, and `lib/` honours env overrides so writes can
be aimed at a sandbox: `OMASETTINGS_STORE`, `OMASETTINGS_HYPR_DIR`,
`OMASETTINGS_XCOMPOSE`, `OMASETTINGS_HERDR_CONFIG`, `OMASETTINGS_TMUX_CONFIG`,
`OMASETTINGS_NVIM_OPTIONS`, `OMASETTINGS_BINDINGS_LUA`, `OMARCHY_SHELL_JSON`.

**Redirecting the file does not redirect the system.** A sandboxed tmux write
still applies to the running server, and a sandboxed keybinding write still
reloads Hyprland. Check what else a write touches before running it.

Before refactoring, capture `bin/omasettings state | jq -S .` and diff against
it afterwards; volatile fields (`.datetime.now`, Wi-Fi signal) need deleting
first.

## QML traps that cost real time here

- **Don't import `QtQuick.Controls` alongside `qs.Ui`.** Both export `Button`
  and `TextField`; the ambiguity fails the whole file, and the shell reports it
  as the useless "File name case mismatch".
- **The `Palette` singleton needs an explicit directory import.** Files in
  `ui/` use `import "." as Local` and `Local.Palette.foreground`; the implicit
  directory import does not resolve it here.
- **Pages get `app` through `Loader.setSource(url, { app: root })`**, not a
  plain `source` assignment — otherwise every binding evaluates against a null
  window on load.
- **`summon` on a bar-widget+panel plugin routes to the widget**, not the panel.
  That is why the window is hosted by the bar widget rather than declared as a
  `panel` entry point.
- **Icon glyphs are not guaranteed.** Signal-strength codepoints render as tofu
  in this Nerd Font, so signal bars are drawn with rectangles. Omarchy's own
  icon font is resolved by *file* (`fc-list ':family=omarchy:charset=e905'`) and
  loaded with a `FontLoader`, because more than one file can claim the family.
- `qmllint` exits 255 with no output when it cannot resolve `qs.*`. The
  authoritative check is the shell loading the file.

## Design

The window is a settings app, so it follows what settings apps have settled on.

**Name a thing once.** A page called Bluetooth should not then contain a group
called Bluetooth containing a row called Bluetooth. If a heading and the thing
under it would carry the same word, the heading goes.

**A control that governs the whole page belongs in the header.** Pages can
declare `property Component headerControl` and `property string headerNote`;
the window renders the control beside the page name and the note under it, in
place of the file path. The Bluetooth adapter switch and its state live there.
Anything that governs only part of a page stays a row.

**Lead with what the page is for.** Network opens with the Wi-Fi switch and
the networks it finds, because choosing a network is why anyone comes here.
Address, gateway and band are about the network you already picked, so they sit
under Connection *after* the list rather than between the switch and it.

**Group by the question being asked, not by the data.** Bluetooth devices are
Connected, Paired and Nearby — three headings — because those answer *what am I
using*, *what do I own*, *what else is here*. One list sorted by state makes the
reader infer the boundaries from the buttons on each row.

**What belongs to a heading is stepped in from it.** `SettingGroup` indents
its note and its rows under a title, so membership is a matter of looking
rather than of reading. A group with no title indents nothing — there is
nothing to belong to.

**A handful of short choices go side by side, not in a dropdown.** `ChoiceRow`
wraps the kit's `ButtonGroup` — the same pills the bar's network widget uses —
so DNS providers are all visible at once. A dropdown is for lists that are long
(themes, fonts) or whose labels are sentences; opening one to discover there
were only four options is a wasted click.

**A heading earns its place or disappears.** `SettingGroup` renders no heading
when its title is empty, which is right for a page with a single group; the
page name is already the heading.

**Say what a setting does, never what it runs.** Notes and descriptions are for
the reader — "Off lets the terminal handle clicks, so links stay clickable",
not "runs omarchy-bar transparent toggle". Implementation belongs in code
comments and the README.

**A note that restates its own rows is noise.** "Paired — yours, but not
connected right now" tells the reader nothing the heading and the rows did not.
A note earns its place by adding a fact you cannot see: that an uninstalled app
gets set up when you pick it, that a bar widget still needs a slot in the bar.

**Don't repeat state that is visible below.** The header says whether Bluetooth
is on, not which devices are connected, and the Wi-Fi switch does not name the
network you are on — the list under both is already saying it, a few rows down.

**A page that watches something keeps itself current.** Network and Bluetooth
poll every five seconds while they are the page on screen *and* the window is
open (`running: app.shown`), through a light `poll` subcommand that returns
what is known right now rather than re-reading the whole state. Nobody should
have to press a button to see what is in the room.

Discovery differs between the two: a Wi-Fi scan is a one-shot request that
NetworkManager rate-limits, while Bluetooth discovery is a *mode* the adapter
has to be held in. So the Bluetooth poll keeps a 30-second `bluetoothctl scan`
alive and lets it lapse once the polling stops — the page never has to clean up
after itself.

## Shell conventions

Bash with `set -uo pipefail` (not `-e`; several reads exit non-zero normally).
`jq` for all JSON. Two `jq` habits worth remembering:

- Inside `($list | index(.x))` the `.` is now `$list` — bind the value first
  (`. as $row | ... index($row[1])`) or every row matches.
- Building a whole file as one string in `awk` (`out = out c`) is quadratic;
  scan per line. That cost 3 seconds of a 3.4-second window open once.

## Comments

Comments say **why**, never what. If a line explains the mechanics of the code
beside it, delete it. The ones worth writing are the ones that record a
decision, a constraint, or a trap — an unbind before a bind so the override
wins; the last tmux assignment being the one that counts; reading the address
from the Wi-Fi device because the default route points at a VPN tunnel.

User-facing strings follow the same discipline in reverse: they say what a
setting does for the reader, never which command runs underneath.
