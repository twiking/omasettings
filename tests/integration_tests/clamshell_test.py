"""A docked laptop, simulated.

Three bugs in the display page only show up with a laptop's internal panel
disabled behind a dock — a machine this repo was not being tested on. Rather
than trust the next round of "verified on a laptop in clamshell mode" to a
human with the right hardware, this fakes the one thing that scenario needs:
`hyprctl` and `omarchy-hyprland-monitor-laptop` on PATH, answering the way a
docked laptop's compositor does. Everything else — `bin/omasettings` itself,
`lib/monitors.sh`, the real `alignOptions()` out of DisplaysSection.qml — runs
unmodified.

Faking hyprctl also makes this safer than the manual loop CLAUDE.md describes:
`OMASETTINGS_HYPR_DIR`/`OMASETTINGS_STORE` only ever sandbox the *files*, so a
manual test still pokes the real compositor through `hyprctl eval`. Here
`hyprctl` is a script this test wrote, so nothing on the screen in front of
you moves.

Run with: pip install -r tests/requirements.txt && pytest tests/integration_tests/clamshell_test.py
Needs `node` on PATH (only to evaluate the real alignOptions()/logicalFootprint()
out of DisplaysSection.qml — see run_align_options below).
"""
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import textwrap
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
OMASETTINGS_BIN = REPO_ROOT / "bin" / "omasettings"
DISPLAYS_SECTION = REPO_ROOT / "sections" / "DisplaysSection.qml"

# The laptop's own panel, folded shut behind the dock. Hyprland still reports
# it — disabled, at (0, 0) — which is exactly what let it slip into Align's
# neighbour list as a screen showing nothing at the origin.
LAPTOP_PANEL = {
    "name": "eDP-1",
    "description": "AU Optronics 0x213C Internal Panel",
    "disabled": True,
    "scale": 1.0,
    "width": 1920,
    "height": 1080,
    "x": 0,
    "y": 0,
    "refreshRate": 60.0,
    "transform": 0,
    "availableModes": ["1920x1080@60.00Hz"],
}

# Two external monitors, side by side, neither of them positioned by anything
# this window has ever written.
DOCK_LEFT = {
    "name": "DP-2",
    "description": "Dell Inc. DELL U2724D 1A2B3C4",
    "disabled": False,
    "scale": 1.0,
    "width": 2560,
    "height": 1440,
    "x": 0,
    "y": 0,
    "refreshRate": 60.0,
    "transform": 0,
    "availableModes": ["2560x1440@60.00Hz"],
}
DOCK_RIGHT = {
    "name": "DP-3",
    "description": "Dell Inc. DELL U2724D 7Z8Y9X",
    "disabled": False,
    "scale": 1.0,
    "width": 2560,
    "height": 1440,
    "x": 2560,
    "y": 0,
    "refreshRate": 60.0,
    "transform": 0,
    "availableModes": ["2560x1440@60.00Hz"],
}


def _write_executable(path: Path, content: str) -> None:
    path.write_text(content)
    mode = path.stat().st_mode
    path.chmod(mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


class Sandbox:
    """A clamshell laptop, faked well enough for `bin/omasettings` to believe
    it — a fresh store, a fresh hypr dir, and a `hyprctl` that answers from a
    monitor list this test controls rather than from the real compositor."""

    def __init__(self, tmp_path: Path):
        self.tmp_path = tmp_path
        self.hypr_dir = tmp_path / "hypr"
        self.hypr_dir.mkdir()
        # Routes render_managed() at the Lua config, the only path a display
        # rule can actually take — see "hyprctl keyword does nothing on a Lua
        # config" in CLAUDE.md.
        (self.hypr_dir / "hyprland.lua").write_text("-- test fixture\n")

        self.hyprctl_log = tmp_path / "hyprctl.log"
        self.monitors_json = tmp_path / "monitors.json"
        self.monitors = [LAPTOP_PANEL, DOCK_LEFT, DOCK_RIGHT]
        self._write_monitors_json()

        fakebin = tmp_path / "fakebin"
        fakebin.mkdir()
        # A real compositor moves when hl.monitor(...) is applied, and the
        # scale-snap check in monitor_set (`hyprctl eval`, then re-read to see
        # what actually took) depends on that: a fake that only ever echoed
        # the fixture back would look like every scale write got silently
        # reverted. So `eval` is parsed well enough to fold mode/scale/
        # position/transform back into the fixture, the same fields hl.monitor
        # takes.
        _write_executable(fakebin / "hyprctl", textwrap.dedent(f"""\
            #!/usr/bin/env python3
            import json, re, sys
            LOG, MONITORS = {str(self.hyprctl_log)!r}, {str(self.monitors_json)!r}
            with open(LOG, "a") as f:
                f.write(" ".join(sys.argv[1:]) + "\\n")
            args = sys.argv[1:]
            if args[:2] == ["-j", "monitors"]:
                sys.stdout.write(open(MONITORS).read())
                sys.exit(0)
            if args and args[0] == "eval":
                table = args[1] if len(args) > 1 else ""
                m = re.search(r'hl\\.monitor\\(\\{{(.*)\\}}\\)', table, re.S)
                if m:
                    body = m.group(1)
                    strs = dict(re.findall(r'(\\w+)\\s*=\\s*"([^"]*)"', body))
                    nums = dict(re.findall(r'(\\w+)\\s*=\\s*([-0-9.]+)(?=[,}}\\s])', body))
                    monitors = json.loads(open(MONITORS).read())
                    output = strs.get("output", "")
                    def matches(entry):
                        desc = entry.get("description", "")
                        key = ("desc:" + desc) if desc else entry["name"]
                        return (key == output or entry["name"] == output
                                or (output.startswith("desc:") and desc.startswith(output[5:])))
                    for entry in monitors:
                        if not matches(entry):
                            continue
                        mode = strs.get("mode")
                        if mode and mode != "preferred":
                            mm = re.match(r'(\\d+)x(\\d+)@([\\d.]+)', mode)
                            if mm:
                                entry["width"] = int(mm.group(1))
                                entry["height"] = int(mm.group(2))
                                entry["refreshRate"] = float(mm.group(3))
                        if "scale" in nums:
                            entry["scale"] = float(nums["scale"])
                        pos = strs.get("position")
                        if pos and pos != "auto":
                            pm = re.match(r'(-?\\d+)x(-?\\d+)', pos)
                            if pm:
                                entry["x"] = int(pm.group(1))
                                entry["y"] = int(pm.group(2))
                        if "transform" in nums:
                            entry["transform"] = int(float(nums["transform"]))
                    open(MONITORS, "w").write(json.dumps(monitors))
                sys.exit(0)
            sys.exit(0)
            """))
        _write_executable(fakebin / "omarchy-hyprland-monitor-laptop", textwrap.dedent("""\
            #!/usr/bin/env bash
            printf '%s\\n' "eDP-1"
            """))

        env = os.environ.copy()
        env["PATH"] = f"{fakebin}:{env['PATH']}"
        env["OMASETTINGS_STORE"] = str(tmp_path / "store.json")
        env["OMASETTINGS_HYPR_DIR"] = str(self.hypr_dir)
        self.env = env

    def _write_monitors_json(self) -> None:
        (self.tmp_path / "monitors.json").write_text(json.dumps(self.monitors))

    def run(self, *args: str) -> str:
        result = subprocess.run(
            [str(OMASETTINGS_BIN), *args],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert result.returncode == 0, f"{args} failed: {result.stderr}"
        return result.stdout

    def monitors_state(self) -> list[dict]:
        return json.loads(self.run("state", "monitors"))["monitors"]

    def by_connector(self, connector: str) -> dict:
        """`monitor_state`'s `name` field is the store key — a description
        like "desc:Dell Inc. DELL U2724D 1A2B3C4" whenever there is one — not
        the connector; `output` carries the connector instead. Tests want to
        say "DP-3" the way a person plugging things in would."""
        return next(m for m in self.monitors_state() if m["output"] == connector)

    def store(self) -> dict:
        path = Path(self.env["OMASETTINGS_STORE"])
        return json.loads(path.read_text()) if path.exists() else {}

    def hand_write_monitor_rule(self, output: str, **fields: str) -> None:
        """A line as a user's own hyprland.lua would carry it — read by
        monitor_config_settings, never written by this window."""
        parts = ", ".join(f'{k} = "{v}"' for k, v in fields.items())
        line = f'hl.monitor({{ output = "{output}", {parts} }})\n'
        path = self.hypr_dir / "hyprland.lua"
        path.write_text(path.read_text() + line)


@pytest.fixture
def clamshell(tmp_path: Path) -> Sandbox:
    return Sandbox(tmp_path)


def run_align_options(sandbox: Sandbox, connector: str) -> list[dict]:
    """Evaluates the actual alignOptions()/logicalFootprint() shipped in
    DisplaysSection.qml — not a reimplementation of them — against the state
    the sandbox produces, the same way the Repeater delegate would call it
    with `name` and `modelData` bound to one display and `displays` to all of
    them. QML's property-function syntax is plain JS here (no bindings, no
    types), so lifting the two function bodies out and running them under
    node is enough to exercise the real filtering logic without a QML engine.

    `connector` names the display the way a person plugging things in would
    ("DP-3"); the row's actual `name` — what alignOptions compares against —
    is that display's store key, resolved from the state the same way the
    real delegate's `name` property is.
    """
    if shutil.which("node") is None:
        pytest.skip("node not on PATH; needed to evaluate the real alignOptions()")

    source = DISPLAYS_SECTION.read_text()

    def extract(signature: str) -> str:
        start = source.index(signature)
        depth = 0
        i = source.index("{", start)
        body_start = i
        while True:
            if source[i] == "{":
                depth += 1
            elif source[i] == "}":
                depth -= 1
                if depth == 0:
                    return source[start:i + 1]
            i += 1
        raise AssertionError(f"unbalanced braces after {signature!r}")  # pragma: no cover

    logical_footprint = extract("function logicalFootprint(m) {")
    align_options = extract("function alignOptions() {")

    displays = sandbox.monitors_state()
    model_data = sandbox.by_connector(connector)

    script = f"""
    const displays = {json.dumps(displays)};
    const name = {json.dumps(model_data["name"])};
    const modelData = {json.dumps(model_data)};
    {logical_footprint}
    {align_options}
    console.log(JSON.stringify(alignOptions()));
    """
    result = subprocess.run(
        ["node", "--input-type=commonjs", "-"],
        input=script,
        capture_output=True,
        text=True,
        timeout=15,
    )
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


# --------------------------------------------------------------------- tests

def test_disabled_panel_is_reported_disabled_at_the_origin(clamshell: Sandbox):
    """Establishes the actual clamshell condition the other tests rely on:
    Hyprland still reports the folded panel, disabled, sitting at (0, 0)."""
    panel = clamshell.by_connector("eDP-1")
    assert panel["disabled"] is True
    assert panel["connected"] is True
    assert panel["x"] == 0 and panel["y"] == 0


def test_align_options_excludes_the_disabled_panel(clamshell: Sandbox):
    """alignOptions() must not offer a neighbour nobody can see. Before the
    fix this included "Left of Internal Panel" etc., computed against a
    screen that shows nothing and overlaps DP-2."""
    options = run_align_options(clamshell, "DP-3")
    labels = [o["label"] for o in options]
    assert not any("Panel" in label for label in labels), labels
    assert any("DELL U2724D 1A2B3C4" in label for label in labels), labels


def test_align_options_offers_automatic_first(clamshell: Sandbox):
    """auto has to be reachable as a choice, not only through Backspace."""
    options = run_align_options(clamshell, "DP-3")
    assert options[0] == {"value": "auto", "label": "Automatic"}


def test_position_of_an_unpositioned_display_is_auto_not_live_coordinates(clamshell: Sandbox):
    """DP-2 is running at real coordinates (Hyprland always reports some),
    but nothing has ever positioned it — the page must say "auto", not the
    numbers Hyprland happens to be using this session."""
    dp2 = clamshell.by_connector("DP-2")
    assert dp2["x"] == 0 and dp2["y"] == 0  # real coordinates are on offer
    assert dp2["position"] == "auto"  # and not mistaken for a real setting


def test_hand_written_auto_position_survives_an_unrelated_write(clamshell: Sandbox):
    """A user's own `position = "auto"` line must not be replaced by whatever
    coordinates the display happens to be running at the moment something
    else on it — like scale — gets changed."""
    clamshell.hand_write_monitor_rule("DP-2", mode="preferred", position="auto")

    clamshell.run("set", "monitor:desc:Dell Inc. DELL U2724D 1A2B3C4:scale", "1.5")

    entry = clamshell.store()["monitors"]["desc:Dell Inc. DELL U2724D 1A2B3C4"]
    assert entry.get("position") == "auto"
    assert entry["scale"] == 1.5


def test_resetting_position_returns_to_auto_not_pinned_coordinates(clamshell: Sandbox):
    """The full round trip the review caught: position an unpositioned
    display, change something else on it so the store keeps a rule at all,
    then reset the position. It must come back "auto" and let the display
    reflow — not stay pinned at the coordinates it happened to occupy the
    moment it was first touched.
    """
    key = "monitor:desc:Dell Inc. DELL U2724D 1A2B3C4:position"

    clamshell.run("set", key, "2560x0")
    clamshell.run("set", "monitor:desc:Dell Inc. DELL U2724D 1A2B3C4:scale", "1.5")

    clamshell.run("reset", key)

    entry = clamshell.store()["monitors"]["desc:Dell Inc. DELL U2724D 1A2B3C4"]
    assert entry.get("position") == "auto", (
        "position reset should hand placement back to Hyprland, not pin the "
        f"coordinates it happened to have: {entry}"
    )
    # The setting that was not reset must survive the reset of the one that was.
    assert entry["scale"] == 1.5


def test_resetting_the_only_setting_drops_the_rule_entirely(clamshell: Sandbox):
    """When position is the only thing on record, Reset should forget the
    display outright rather than leave an empty rule behind."""
    key = "monitor:desc:Dell Inc. DELL U2724D 1A2B3C4:position"
    clamshell.run("set", key, "2560x0")

    clamshell.run("reset", key)

    assert "desc:Dell Inc. DELL U2724D 1A2B3C4" not in clamshell.store().get("monitors", {})
