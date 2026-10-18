# Tests

Not everything here is worth clicking through by hand every time — a
scenario nobody testing this on their own machine happens to be sitting at,
like a laptop docked in clamshell mode, or a check that has to run before
every push. What doesn't fit `qmllint` or the manual loop in `CLAUDE.md`
lands here instead, as a Python integration test that drives the real
`bin/omasettings` against a sandboxed store.

```
integration_tests/   Drives bin/omasettings end to end against a fake
                      hyprctl and sandboxed OMASETTINGS_* paths — see
                      integration_tests/clamshell_test.py.
```

## Running

```bash
python3 -m venv .venv
.venv/bin/pip install -r tests/requirements.txt
.venv/bin/pytest tests -v
```

`clamshell_test.py` also needs `node` on `PATH`, to evaluate the QML page
logic it checks (`alignOptions()` in `sections/DisplaysSection.qml`) as the
plain JavaScript it is once lifted out of the file, without a QML engine. A
test that `node` is unavailable for is skipped rather than failed.

## What a sandbox here does and doesn't isolate

`OMASETTINGS_STORE` and `OMASETTINGS_HYPR_DIR` — the same env vars the manual
testing loop in `CLAUDE.md` uses — move the *files* these tests write to, not
the system: a sandboxed store still applies Hyprland settings through the
real compositor, because `lib/*.sh` always shells out to the real `hyprctl`
unless something on `PATH` says otherwise. So a test that needs writes to
stay off the screen in front of you — as the clamshell tests do — puts a
fake `hyprctl` first on `PATH` as well, and reads the compositor's answers
back from a JSON fixture the test controls rather than from Hyprland.
