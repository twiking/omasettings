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
   applied live with `hyprctl eval` — not `keyword`, which does nothing on a Lua
   config — and recorded there; the generated file is loaded last so the user's
   own files still say what they wrote. It is created on the first write, not at
   install, and the `require` line is appended to `hyprland.lua` at the same
   moment.
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

## Pages for applications you may not have

Tmux, Neovim and Herdr get a page each, and an application you do not have is
a page of settings with nowhere to go — so `pageAvailable()` drops it from the
menu, from the search counts and from Alt navigation, and steps off it if the
application goes away while its page is open.

**The binary is the test, not the config file.** An application can be
installed and never yet configured, and a config file can outlive the thing it
configured; only `command -v` answers the question actually being asked. Each
of the three reports it in its own state as `installed`.

## Where each page writes

This app stores almost nothing. Each page writes into whatever owns the
setting, which is why the sidebar shows the file in the page header:

| Page | Lands in |
| --- | --- |
| Windows, Layout, Effects, Groups, Keyboard, Mouse | `~/.config/hypr/omasettings.lua`, loaded last |
| Appearance | Omarchy's own config, via `omarchy-theme-set`, `omarchy font set`, `omarchy display text size` |
| Bar, Idle & Lock, Plugins | `~/.config/omarchy/shell.json` |
| Keybindings | a marked block in `~/.config/hypr/bindings.lua` |
| Compose Keys | `~/.XCompose` |
| Herdr, Tmux, Neovim | their own configs, edited in place |
| Displays | `~/.config/hypr/omasettings.lua`, applied with `hyprctl eval` |
| Audio, Network, Bluetooth, Power | nowhere — live system state, owned by PipeWire, NetworkManager, BlueZ and power-profiles-daemon |

A display is the one thing here worth writing down as well as applying: it is
unplugged and plugged back in, and Hyprland matches its monitor rules again on
every connect. So a resolution or a scale set on the Displays page becomes an
`hl.monitor` call in the managed file, and a display that is **not** connected
can be set up by name for the next time it arrives. `hyprctl keyword monitor`
was the original bug there — it answers "keyword can't work with non-legacy
parsers" on stderr while exiting 0, so both settings looked applied and never
were.

**Our store holds no settings of its own**, only what is needed to say what
changed and put it back: `hypr` and `hyprOriginal` (Hyprland keys we override
and what they were), `written` (pre-change values for settings living in other
people's configs), `devices`, `monitors`, `bindings`, and `extras` (animation
speed, full opacity). Delete the store and nothing you configured is lost —
only the memory of which parts came from here.

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

## When the bar already shows the same thing

A page that duplicates a bar widget has to agree with it, or the two become
two answers to one question. Audio was a lesson in this: `pactl` lists every
sink in the graph, so the page offered four HDMI outputs with no cable in them
and a physical speaker sink sitting behind a tuning, under names like "Radeon
High Definition Audio Controller HDMI / DisplayPort 3 Output". The widget shows
two devices called "ALC285 Analog" and "HDMI 3".

The difference was not taste. `omarchy-audio-sink-availability` reports which
sinks have a live port and hides the one a speaker tuning fronts; the widget
labels a device by its own short nickname (`node.nick`) rather than the
sentence PulseAudio assembles. Both now feed this page too.

Before building a page over something the bar already shows, read the widget
and use the same source, the same filter, and the same labels.

## Keyboard navigation

`PanelKeyCatcher` in `qs.Ui` defines the vocabulary Omarchy panels answer to,
and this window follows it rather than inventing one: Up/Down and j/k move,
Left/Right and h/l change a value, Enter and Space act, Tab changes section,
Escape closes. Alt+Up/Down for the sidebar, Home/End, and Backspace for the
(reset) beside a changed setting are the additions a window with pages needs.

The cursor lives in `SettingsWindow`, but a row says what it means: `SettingRow`
carries `current`, `navActivate()` and `navStep(delta)`, and each row type
answers those in its own terms — a switch flips, a slider steps, a picker
opens. A row type that answers neither is still navigable and simply does
nothing when activated.

Rows register themselves on load, by walking up to the page and taking the
`app` handle it was loaded with — a window is not the visual parent of what it
shows, so walking to the top does not find it. The order is recomputed from
where rows actually sit, not from the order they registered, since groups come
and go with the settings they depend on.

Two things worth knowing before changing this:

- **A field commits by losing focus, and stops its own Enter.** `accepted`
  fires without accepting the event, so an Enter left to bubble reaches the
  window, which reads it as "activate this row" and drops straight back into
  the field it just left. Editing is a flag the row owns rather than a reading
  of `activeFocus`, which the field can take back on its own.
- **A row holding the keyboard sets `navBlocking`** — an open dropdown, a field
  being typed into. The window then forwards every key, Escape included, or
  Escape would close the window out from under an open list.
- **Stepping keeps its own `pending` value.** A write takes a state refresh to
  come back, and two presses inside that window would both compute from the
  same stale number, so the second would be swallowed. `effective` is what the
  slider and the next press read.

## Changed, and putting back

"Changed" means the value differs from what the setting was before this window
first wrote it — not merely that the window wrote it. A switch flipped and
flipped back is not a change, and must stop saying it is.

Three kinds of change, three ways back:

- **A Hyprland key** is an override: drop it and the value comes from wherever
  it came from before — Omarchy, the theme, a hand-written `looknfeel.lua`.
  A **per-device** setting is the same shape; clearing it hands the device back
  to the global one, so the store is the whole record and no original is kept.
- **A value in someone else's config** — theme, font, text size, the bar, the
  idle timeouts, tmux, Neovim, Herdr, a monitor scale — has no unset state.
  The way back is the value found before the first write, kept in `.written`
  under a key naming what it configures (`tmux:mouse`, `device:<name>:<opt>`,
  `monitor:DP-2`). Hyprland keys keep theirs in `.hyprOriginal`.
- **A list you add to** — compose entries, keybindings — is not a setting with
  a default at all. Those rows carry Remove, Turn off and Restore, which is
  what a thing you created wants rather than a reset.

The window shows one mark for all of them, because from the outside they are
the same thing: you changed it, and it can go back. `Ctrl+Backspace` or the **Reset all
settings** button under the menu puts back everything at once, after asking — the one
action here a second click cannot undo.

The live pages are deliberately unmarked: audio, network, bluetooth and power
move on their own, so "you changed this" would be a guess.

Three things this will not forgive:

- **Read the previous value before the write.** Read after, and the recorded
  original is the value it has just become.
- **Read it with `has()`, never `//`.** jq's alternative operator treats
  **false** as empty, so every switch that starts off reads its original back
  as null and never matches. This bit twice: Shadow, Blur and Glow went on
  claiming a change after being turned off again.
- **Restoring writes the value found at the first change.** If a theme has
  moved text size since, the reset puts back the older number, not the theme's.
  A key written before any of this existed has no original at all, and stays
  marked until reset once.

## The two that are not keywords

Speed and full opacity cannot be set or read like the rest, because Hyprland
has neither. Each is a piece of Lua written into the managed file, with a
value of our own in `.extras` saying what to write, and both ride into the
window inside `state.hypr` so a page asks for them like anything else.

- **Speed** multiplies the animation set Omarchy ships, read from
  `default/hypr/looknfeel.lua` rather than from the running config: reading
  live speeds would multiply what has already been multiplied and the setting
  would run away from itself. The cost is that an animation you wrote yourself
  is replaced by the scaled default while this is anything but 1.
- **Full opacity** writes `o.window(".*", { opacity = "1.0 1.0" })`. Omarchy
  tags every window and fades it to 0.985, which multiplies with the opacity
  sliders, so without this 100% renders at 98.5%. The managed file loads last,
  so the rule lands after the one it is undoing.

## Keyboard values that will not compile

Hyprland accepts a layout or variant xkb cannot build and says nothing: it
keeps the last keymap that worked, so the window would show the new value
while the keys went on doing the old thing — or, worse, leave you unable to
type the fix. `kb_check` compiles the pair as it would be after the write
(either half can break it) with `xkbcli compile-keymap`, and refuses before
anything is written. It runs for the per-device settings too.

Options are deliberately not checked: xkb ignores an option it does not know
rather than failing, so a typo there costs nothing, and a check would only be
a guess at a list that changes.

## The legend bar

Fourteen keys listed at once would be a wall nobody reads, so the bar says
what the keys do *here*: the four that always apply, plus whatever the cursor
is on. A row type declares its own keys in `navKeys` — the same place it
answers `navActivate` and `navStep` — so a new row type that forgets adds
nothing to the bar rather than lying about what it does.

`\u232b Reset` appears only on a row this window has changed, which makes the
bar the discovery path for the reset as well.

## Which screen it opens on

A layer surface goes to the screen it is given, and given none it goes to the
first one — so on two monitors the settings could open on the one you are not
looking at. Hyprland knows which monitor has the focus and Quickshell knows
the screens by name; `focusedScreen()` matches the two, and `show()` pins the
result for that opening.

Pinned, not bound: a window that hops to another screen because the focus
moved is worse than one that stays where it was opened. This machine has one
monitor, so the choice is verified by what it resolves rather than by where
it lands.

## Rows that are not settings

A device, a network and a binding are lists of things rather than one setting
each, and their rows are built to look like it — `PickableRow`, `DeviceRow`,
`WifiRow`, `BindingRow` are not `SettingRow`s. `NavCursor` carries the cursor
contract into them instead of forcing them into that shape: drop one in,
anchored over the row, and the row joins the cursor. It registers itself, not
its parent, and mirrors the geometry the window sorts by, so from the window's
side it is another row.

Its key is whatever clicking the row does, which is not fixed: connect or
disconnect depending on the device, remove or turn off depending on whose
binding it is. The legend says which, because the row does.

## Search

Only the open page is instantiated, which is what keeps the window cheap and
what makes searching awkward: the window cannot ask a page it has not built
what it holds. `omasettings search` reads the section sources instead and
returns every label, description and heading per page, keyed by the page ids
taken from `SettingsWindow.qml`'s own routing — so a page renamed or a setting
added is in the index without a second list to update.

The index arrives with the state, not from a call of its own, because half of
it is the state: a page that is a list of things — this keyboard, that
network, your bindings, the plugins you have — can only be described by the
running system, and `state.sh` has already asked. The section sources give the
rest. Rows named by the system say so through `NavCursor.searchText`.

One thing follows from that:

- **The index is only as fresh as the state.** A device that appears while the
  window is open is searchable at the next read, not the moment it arrives.
- **The heading is part of the match, in both places.** The index carries the
  group, and rows read their heading off the `SettingGroup` above them, or a
  search for "blur" would count eleven settings and show seven.
- **So is the page name, and its parent's.** "bluetooth" has to find a page
  whose rows are all device names, and "applications" has to find what sits
  under it. A page whose name matches is listed whatever its settings are
  called — including the pages that declare no labels at all, which is why
  those show no number beside them.
- **Every page needs its own `case` in `sectionSource`.** The index learns
  which file holds which page by reading those cases; a page reachable only
  through the `default` branch is one the search cannot see. That is exactly
  what hid Herdr's 25 settings.

## The launcher entry

The plugin is an app as well as a bar widget: `Service.qml` is a `service`
entry point that writes `~/.local/share/applications/omasettings.desktop` from
the template beside it, substituting the icon path, and deletes it again on
disable or remove. Omarchy has no install hook, which is why this lives in the
plugin rather than in a package.

Both halves guard on `X-OmaSettings-Managed=true`: a file at that path without
the marker is never written and never deleted, so a hand-written entry
survives. Every failure in the script is a quiet exit — a launcher entry is a
convenience, and none of it is worth interrupting the shell over.

Changing either file means testing the whole cycle, not just the write:
`omarchy plugin disable`, check the file is gone, `omarchy plugin enable`,
check it is back, and `desktop-file-validate` what it wrote.

## Watching instead of asking

Two pages follow the system rather than re-reading it. Audio follows
`pactl subscribe`, because mute and volume belong to the server and the media
keys, the bar and every other panel move them. Power follows three signals at
once — the profile daemon over D-Bus, UPower for the battery, and inotify on
the files `omarchy-powerprofiles-set` writes — because the bar's power plugin,
the menu and the daemon all move the profile.

Both run only while their page is open, and both drain a burst of events
before re-reading, or one key press costs four reads. The monitors are killed
by an EXIT trap *and* by a watchdog on the reader, since neither notices the
page closing on its own.

Every other page is only as fresh as the last state read. Change a theme
elsewhere and this window shows the old one until something makes it read
again — worth knowing before chasing a "stale value" bug that is not one.

## Reading Hyprland in one call

`hypr_state` asks for every setting in a single `hyprctl --batch` and sorts the
answers out in jq. One call each was fine at a dozen settings and not at
seventy-odd: it took a second on its own, the window sat on "Loading" for
seconds, and — the part that actually misleads — every page rendered the
fallbacks written into its rows rather than the values Hyprland holds. If a
page shows suspiciously round numbers, suspect that before suspecting the page.

## The bar layout

`bar move` and `bar shift` edit `.bar.layout` in `shell.json`. Both move the
widget's **whole object**, never rebuild it from its id: a widget keeps its own
settings in that same object, and half the bar would lose its configuration the
first time it was reordered.

## The Plugins page

Add and remove hand off to the Omarchy flows in a terminal, because both ask
questions and print what they did. The update check fetches every plugin at
once and prints each verdict as it lands, so spinners retire one at a time
rather than all at the end; the verdicts outlive the sweep in
`~/.cache/omarchy/omasettings/plugin-updates.json`, since a check costs a
network round trip per plugin.

The window is a plugin too, and says so in its own corner when it is behind:
the cached verdict draws it at once and a single background fetch corrects it
a moment after opening. The comparison is `omarchy-plugin-update`'s own — fetch
`origin HEAD`, count `HEAD..FETCH_HEAD` — on purpose, so the count never
promises an update the button then refuses to make.

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

**Driving it from the keyboard.** `wtype` types into whatever holds keyboard
focus, and the window takes focus exclusively while it is open — so check it
is open before every burst:

```bash
hyprctl layers -j | jq -e '..|select(.namespace?=="omasettings")' >/dev/null \
  && wtype "/" && wtype "blur"
```

Skip that check and the keystrokes go to the terminal you are working in. Two
things close the window out from under a test: `Escape` with nothing focused,
and `toggle` when it is already open. `Escape` only clears the search when the
search box has focus.

**Finding it in a screenshot.** `grim -g` takes *logical* coordinates while a
full `grim` capture is physical pixels, and the card is 90% of the screen
centred — three different frames of reference. Capture the whole screen, crop
from that with `magick`, and read the geometry out of
`hyprctl monitors` rather than assuming it.

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

**Redirecting the file does not redirect the system.** `OMASETTINGS_HYPR_DIR`
moves the *files*; it does not move Hyprland. A sandboxed Hyprland write still
goes to the running compositor through `hyprctl eval`, so a "safe" demo changes
the gaps on the screen in front of you. A sandboxed tmux write still applies to
the running server, and a sandboxed keybinding write still reloads Hyprland.

Check what else a write touches before running it, and if you only want to see
what a write *produces*, read `render_managed_lua` rather than performing one.

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
- **`forceActiveFocus()` on a `FocusScope` gives focus back to the child that
  had it last** — which, when a field has just finished editing, is that field.
  The scope holds a `keySink` Item for focus to land on instead.
- **A `TextField` emits `accepted` without accepting the event.** An Enter left
  to bubble reaches the window, which reads it as "activate this row" and drops
  straight back into the field just left. Handle Enter at the field and accept
  it there.
- **A `Repeater` is a visible child with no height**, sitting among the rows it
  made. Counting children to decide whether a group is empty must skip it, or
  every heading survives a search that removed everything under it.
- **A binding read from inside its own change handler is the previous value.**
  `onSearchTermChanged` reading `sidebarRows` got the list for the term before,
  and switched to a page that no longer matched. Recompute from the source, not
  from the binding you are invalidating.
- **A property named `<x>Changed` collides with `<x>`'s change signal.**
  `hyprChanged` beside `hypr` is a duplicated name; Qt 6's qmllint catches it,
  Qt 5's does not.
- **A child anchored to a parent that sizes itself from its children is a
  binding loop.** Row content anchored to `verticalCenter` of a holder whose
  `implicitHeight` is `childrenRect.height` loops silently — it shows up in the
  journal, not in the lint.
- **`hyprctl keyword` does nothing on a Lua config.** It answers "keyword can't
  work with non-legacy parsers. Use eval." — on stderr, while still exiting 0,
  so a setting looks applied and is not. `hypr_apply_live` sends
  `hyprctl eval 'hl.config({...})'` instead, with the keyword form kept for
  setups still on `.conf`. Per-device settings go the same way, as
  `hl.device({ name = ..., ... })`.
- `qmllint` on `PATH` is Qt 5's (`qt5-declarative`), and Quickshell is Qt 6.
  It cannot parse a typed function signature — `function show(): void`, which
  `IpcHandler` requires — and exits 255 with no output when it meets one, so
  `Panel.qml` never gets linted by it. It also passes nearly everything else
  regardless of merit, which makes a clean run from it worth nothing. Use the
  Qt 6 binary, and give it the `qs.*` root, which Quickshell aliases to the
  shell directory:

  ```bash
  mkdir -p /tmp/qsimports && ln -sfn /usr/share/omarchy/shell /tmp/qsimports/qs
  /usr/lib/qt6/bin/qmllint -I /tmp/qsimports SettingsWindow.qml sections/*.qml
  ```

  Two warnings are expected and are not yours to fix: `Property "state"
  already exists in base type` (the window has carried it from the start) and
  `Type PanelWindow is not creatable`, which Omarchy's own bar and menu raise
  on the same type. Unqualified-access and missing-property notes on `Style`
  and `Color` are singletons qmllint cannot follow.

  Even so, the authoritative check is the shell loading the file.

## Per-device input

Hyprland lets one keyboard or pointer depart from the global input settings
(`hl.device`). Each device gets **its own group**, below the global settings
and titled with the device name, so what a control writes is never in doubt:
the rows under a device name write that device, the rows above write all of
them.

The first attempt used one picker that switched what the page's controls wrote.
It was fewer rows and it was wrong — the same slider meaning different things
depending on a dropdown three groups up is a trap, not a saving. If a control
can write to two places, show two controls.

Only a device that has departed from the global settings gets a group. The
rest sit behind one "Settings for one pointer" dropdown, so a machine with five
input devices and no overrides still reads as a page about pointers rather than
a list of hardware.

A device row shows the value in force for it: what was set here, else what the
user's own config gives it, else the global setting above.

Removing a device takes its `hl.device` with it, including one the user wrote:
that block is **commented out rather than deleted**, with a line saying how to
bring it back, and the file is checked with `luac -p` and restored if the edit
broke it. Their config is still never regenerated — this is the same targeted
in-place edit the per-application configs get.

`hyprctl devices` also reports **displays** as input devices: a monitor's HID
control endpoint advertises keyboard and pointer capability, so DP-3 arrives as
a keyboard `dp-3` and a mouse `dp-3-1`. They are filtered by DRM connector
shape (`dp-1`, `hdmi-a-2`, `edp-1`, and their numbered siblings) rather than
against the connected monitors, because an unplugged display leaves its input
device behind.

`hyprctl devices` reports far more devices than anyone has on a desk — power
buttons, lid switches, video buses, virtual keyboards — so `devices.sh` filters
them out. The picker hides itself entirely when only one real device exists.

Two things the first version got wrong, both worth keeping in mind:

- **A device you own is not always plugged in.** Listing only what
  `hyprctl devices` reports means a Bluetooth mouse vanishes from settings the
  moment you undock. Devices that appear in any config are listed too, marked
  "(not connected)".
- **Read their config even though you never write it.** The no-parsing rule is
  about *writing*. A device already configured in `input.lua` would otherwise
  read as unconfigured here, and a value set from this page would silently
  fight a line the user wrote by hand. `device_config_settings` reads the
  `hl.device` blocks out of their Lua, and a control falls back
  ours → theirs → global, which is the order Hyprland itself resolves them in.

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
