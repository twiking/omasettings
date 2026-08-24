import QtQuick
import Quickshell

// Installs the launcher entry, so the window is reachable from SUPER+SPACE
// like any other application rather than only from the bar. Omarchy has no
// install hook and no manifest field for registering one, so a plugin that
// wants to be an app has to do it itself, on enable.
//
// Only a file carrying the X-OmaSettings-Managed marker is ever written or
// deleted: an entry you wrote yourself at that path is left alone.
QtObject {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  readonly property string dest: Quickshell.env("HOME") + "/.local/share/applications/omasettings.desktop"
  readonly property string marker: "^X-OmaSettings-Managed=true$"

  // $1 template, $2 destination, $3 marker, $4 icon. Every failure is a quiet
  // exit: a launcher entry is a convenience, and nothing here is worth
  // interrupting the shell over.
  // The destination is a predictable path in a directory anyone on the machine
  // could have written to first, so nothing here writes through a name it did
  // not create: a symlink at either path is left alone rather than followed,
  // and the rendered entry is built in a fresh random sibling.
  readonly property string installScript:
      '[ -f "$1" ] || exit 0\n'
    + '[ -L "$2" ] && exit 0\n'
    + 'if [ -e "$2" ] && ! grep -q "$3" "$2"; then exit 0; fi\n'
    + 'mkdir -p "${2%/*}" || exit 0\n'
    + 'tmp=$(mktemp "$2.omasettings.XXXXXX") || exit 0\n'
    + 'sed "s|@ICON@|$4|" "$1" >"$tmp" || { rm -f "$tmp"; exit 0; }\n'
    + 'chmod 644 "$tmp"\n'
    + 'if cmp -s "$tmp" "$2"; then rm -f "$tmp"; else mv -f "$tmp" "$2"; fi\n'

  readonly property string removeScript:
      '[ -L "$1" ] && exit 0\n'
    + 'grep -q "$2" "$1" 2>/dev/null && rm -f "$1"\n'

  property bool installed: false

  // The shell assigns manifest after createObject() has already run
  // Component.onCompleted, so the paths are built when it arrives rather than
  // bound ahead of it.
  onManifestChanged: {
    var dir = manifest && manifest.__sourceDir
    if (installed || !dir) return
    installed = true
    Quickshell.execDetached(["sh", "-c", installScript, "sh",
                             dir + "/omasettings.desktop", dest, marker, dir + "/icon.png"])
  }

  // Reached on disable and on remove alike: omarchy-plugin-remove disables
  // first, so the service is torn down while the entry is still ours.
  Component.onDestruction: {
    if (!installed) return
    Quickshell.execDetached(["sh", "-c", removeScript, "sh", dest, marker])
  }
}
