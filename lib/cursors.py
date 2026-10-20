#!/usr/bin/env python3
"""Cursor themes for the Mouse & Touchpad page. Called by lib/pointer.sh;
bash cannot read Xcursor files or write PNGs, so this does the two things the
window needs that the rest of lib/ cannot.

  cursors.py list            JSON: every theme with previews, and what can be fetched
  cursors.py has THEME       exit 0 if THEME is an installed cursor theme
  cursors.py fetch INDEX     download one of the listed themes into ~/.local/share/icons
"""

import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "omarchy", "omasettings", "cursors")
USER_ICONS = os.path.join(HOME, ".local", "share", "icons")

ICON_DIRS = [USER_ICONS, os.path.join(HOME, ".icons"), "/usr/local/share/icons", "/usr/share/icons"]

SIZES = [24, 32, 40, 48, 64]
PREVIEW_SIZE = 64  # drawn at half that on a 2x screen, so it stays crisp

# The four shapes a card shows. Themes spell them differently.
SHAPES = [
    ("default", ["left_ptr", "default", "arrow", "top_left_arrow"]),
    ("pointer", ["pointer", "hand2", "hand1", "pointing_hand"]),
    ("text", ["text", "xterm", "ibeam"]),
    ("wait", ["wait", "watch", "progress", "left_ptr_watch"]),
]

# Pointer styles that can be fetched without a password. Pinned to releases,
# so what is fetched is what was looked at. One download can hold several.
BIBATA = "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/"
CATPPUCCIN = "https://github.com/catppuccin/cursors/releases/download/v2.0.0/"
GOOGLE = "https://github.com/ful1e5/Google_Cursor/releases/download/v2.0.0/"
APPLE = "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/"
DOWNLOADS = [
    ("Bibata Modern Ice", ["Bibata-Modern-Ice"], BIBATA + "Bibata-Modern-Ice.tar.xz"),
    ("Bibata Modern Classic", ["Bibata-Modern-Classic"], BIBATA + "Bibata-Modern-Classic.tar.xz"),
    ("Bibata Modern Amber", ["Bibata-Modern-Amber"], BIBATA + "Bibata-Modern-Amber.tar.xz"),
    ("Catppuccin Mocha Dark", ["catppuccin-mocha-dark-cursors"], CATPPUCCIN + "catppuccin-mocha-dark-cursors.zip"),
    ("Catppuccin Mocha Light", ["catppuccin-mocha-light-cursors"], CATPPUCCIN + "catppuccin-mocha-light-cursors.zip"),
    ("Catppuccin Mocha Mauve", ["catppuccin-mocha-mauve-cursors"], CATPPUCCIN + "catppuccin-mocha-mauve-cursors.zip"),
    ("Catppuccin Latte Light", ["catppuccin-latte-light-cursors"], CATPPUCCIN + "catppuccin-latte-light-cursors.zip"),
    ("GoogleDot Black", ["GoogleDot-Black"], GOOGLE + "GoogleDot-Black.tar.gz"),
    ("GoogleDot White", ["GoogleDot-White"], GOOGLE + "GoogleDot-White.tar.gz"),
    ("GoogleDot Blue", ["GoogleDot-Blue"], GOOGLE + "GoogleDot-Blue.tar.gz"),
    ("macOS", ["macOS"], APPLE + "macOS.tar.xz"),
    ("macOS White", ["macOS-White"], APPLE + "macOS-White.tar.xz"),
    ("Phinger (dark, light and left-handed)",
     ["phinger-cursors-dark", "phinger-cursors-light", "phinger-cursors-dark-left", "phinger-cursors-light-left"],
     "https://github.com/phisch/phinger-cursors/releases/download/v2.1/phinger-cursors-variants.tar.bz2"),
]

THEME_ID = re.compile(r"^[A-Za-z0-9_+][A-Za-z0-9._+-]{0,127}$")


# ------------------------------------------------------------ xcursor files

def read_xcursor(path, size):
    """First frame nearest `size` as (width, height, premultiplied ARGB words).
    The smallest image at or above the size scales down cleanly; below it is
    only a last resort, since scaling up blurs."""
    try:
        with open(path, "rb") as f:
            data = f.read(8 * 1024 * 1024)
    except OSError:
        return None
    if len(data) < 16 or data[:4] != b"Xcur":
        return None

    def u32(off):
        return struct.unpack_from("<I", data, off)[0] if 0 <= off <= len(data) - 4 else 0

    header, entries = u32(4), min(u32(12), 4096)
    best = None
    for i in range(entries):
        off = header + i * 12
        if u32(off) != 0xFFFD0002:
            continue
        nominal = u32(off + 4)
        score = nominal - size if nominal >= size else (size - nominal) * 4
        if best is None or score < best[0]:
            best = (score, u32(off + 8))
    if best is None:
        return None
    pos = best[1]
    w, h = u32(pos + 16), u32(pos + 20)
    pixels = pos + 36
    if not (0 < w <= 1024 and 0 < h <= 1024) or pixels + w * h * 4 > len(data):
        return None
    return w, h, struct.unpack_from("<%dI" % (w * h), data, pixels)


def write_png(path, w, h, argb):
    """RGBA PNG from premultiplied ARGB, without any image library."""
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            p = argb[y * w + x]
            a, r, g, b = p >> 24, (p >> 16) & 255, (p >> 8) & 255, p & 255
            if 0 < a < 255:
                r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            rows += bytes((r, g, b, a))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 6)) + chunk(b"IEND", b"")
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(png)
    os.replace(tmp, path)


# ------------------------------------------------------------ themes

def theme_dir(theme_id):
    for base in ICON_DIRS:
        d = os.path.join(base, theme_id, "cursors")
        if os.path.isdir(d):
            return d
    return None


def read_index(theme_id):
    name, inherits = "", []
    for base in ICON_DIRS:
        index = os.path.join(base, theme_id, "index.theme")
        if not os.path.isfile(index):
            continue
        try:
            with open(index, encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("Name=") and not name:
                        name = line[5:].strip()
                    elif line.startswith("Inherits="):
                        inherits = [i.strip() for i in line[9:].split(",") if i.strip()]
        except OSError:
            pass
        break
    return name, inherits


def find_themes():
    themes, seen = [], set()
    for base in ICON_DIRS:
        try:
            entries = sorted(os.listdir(base))
        except OSError:
            continue
        for theme_id in entries:
            if theme_id in seen or not THEME_ID.match(theme_id):
                continue
            if not os.path.isdir(os.path.join(base, theme_id, "cursors")):
                continue
            seen.add(theme_id)
            name, inherits = read_index(theme_id)
            # "Bibata-Modern-Ice" reads better as "Bibata Modern Ice".
            if not name or name == theme_id:
                name = theme_id.replace("-", " ").replace("_", " ")
            themes.append({"id": theme_id, "name": name, "inherits": inherits})
    themes.sort(key=lambda t: t["name"].lower())
    return themes


def shape_file(theme, names):
    """A theme can leave shapes out and name a parent to fill them in, the
    way the left-handed Phinger sets borrow the text and wait shapes."""
    queue, visited = [theme["id"]], set()
    while queue and len(visited) < 8:
        theme_id = queue.pop(0)
        if theme_id in visited:
            continue
        visited.add(theme_id)
        d = theme_dir(theme_id)
        if d:
            for n in names:
                p = os.path.join(d, n)
                if os.path.isfile(p):
                    return p
        queue += read_index(theme_id)[1]
    return None


def previews(theme):
    out = {}
    folder = os.path.join(CACHE, theme["id"])
    for shape, names in SHAPES:
        src = shape_file(theme, names)
        if not src:
            out[shape] = ""
            continue
        png = os.path.join(folder, "%s-%d.png" % (shape, PREVIEW_SIZE))
        try:
            fresh = os.path.getmtime(png) >= os.path.getmtime(src)
        except OSError:
            fresh = False
        if not fresh:
            image = read_xcursor(src, PREVIEW_SIZE)
            if not image:
                out[shape] = ""
                continue
            os.makedirs(folder, exist_ok=True)
            write_png(png, *image)
        out[shape] = png
    return out


def cursor_accent_enabled():
    """Cursor Accent applies its own recoloured pointer whenever the shell
    starts, so a pointer picked here lasts only until then while it is on."""
    try:
        with open(os.path.join(CONFIG, "omarchy", "shell.json"), encoding="utf-8") as f:
            return "io.github.smoothpixels.cursor-accent" in f.read()
    except OSError:
        return False



def listing():
    themes = find_themes()
    installed = {t["id"] for t in themes}
    for t in themes:
        t["previews"] = previews(t)
        del t["inherits"]
    downloads = [{"index": i, "name": name, "installed": all(d in installed for d in ids)}
                 for i, (name, ids, _) in enumerate(DOWNLOADS)]
    print(json.dumps({"themes": themes, "downloads": downloads, "sizes": SIZES,
                      "cursorAccent": cursor_accent_enabled()}))


def fetch(index_text):
    if not index_text.isdigit() or int(index_text) >= len(DOWNLOADS):
        sys.exit("omasettings: nothing to fetch at %r" % index_text)
    name, _, url = DOWNLOADS[int(index_text)]
    os.makedirs(USER_ICONS, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="omasettings-cursor-") as tmp:
        archive, out = os.path.join(tmp, "archive"), os.path.join(tmp, "x")
        os.mkdir(out)
        if subprocess.run(["curl", "-fsSL", "--max-time", "120", "-o", archive, url]).returncode != 0:
            sys.exit("omasettings: could not download %s" % name)
        # bsdtar comes with every Arch install and unpacks zip and every tar alike.
        if subprocess.run(["bsdtar", "-xf", archive, "-C", out]).returncode != 0:
            sys.exit("omasettings: could not unpack %s" % name)
        moved = []
        for root, dirs, _ in os.walk(out):
            if "cursors" in dirs and root != out:
                theme_id = os.path.basename(root)
                if THEME_ID.match(theme_id) and not os.path.islink(root):
                    dest = os.path.join(USER_ICONS, theme_id)
                    if os.path.lexists(dest):
                        shutil.rmtree(dest) if os.path.isdir(dest) and not os.path.islink(dest) else os.remove(dest)
                    shutil.move(root, dest)
                    moved.append(theme_id)
                dirs[:] = []
    print(json.dumps({"ok": bool(moved), "installed": moved}))


def main(argv):
    if argv[:1] == ["list"]:
        listing()
    elif len(argv) == 2 and argv[0] == "has":
        sys.exit(0 if THEME_ID.match(argv[1]) and theme_dir(argv[1]) else 1)
    elif len(argv) == 2 and argv[0] == "fetch":
        fetch(argv[1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
