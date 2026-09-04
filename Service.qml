import QtQuick
import Quickshell
import Quickshell.Io

// The plugin's always-on half: it owns the settings window and the IPC route
// that opens it, and installs the launcher entry.
//
// The window lives here rather than in the bar widget because it is not the
// bar's. A gear in the bar is one way in, `omarchy-shell omasettings toggle`
// and the launcher entry are others, and the two should not depend on the
// first: with the window in Panel.qml, taking the gear out of the bar takes
// the plugin out of shell.json, and the plugin with it. Enabled through
// `plugins[]` and with no bar entry at all, everything below still works.
//
// The launcher entry makes the window reachable from SUPER+SPACE like any
// other application. Omarchy has no install hook and no manifest field for
// registering one, so a plugin that wants to be an app has to do it itself,
// on enable.
//
// Only a file carrying the X-OmaSettings-Managed marker is ever written or
// deleted: an entry you wrote yourself at that path is left alone.
Scope {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // ---------------- window lifecycle ---------------------------------------
  //
  // The lifecycle a plugin surface is expected to carry, in the names the rest
  // of Omarchy uses. open/close and show/hide are the same pair twice, because
  // both names are in circulation and neither is worth surprising anyone over.
  //
  // The window is loaded on first use rather than at startup — the shell
  // process is long-running and a settings window nobody has opened yet should
  // not cost it anything.
  readonly property bool opened: windowLoader.item ? windowLoader.item.shown : false

  function show() { windowLoader.active = true; if (windowLoader.item) windowLoader.item.show() }
  // Opening on a named page is how a job that had to tear this window down
  // brings it back where it was: the loader is asynchronous, so the page is
  // remembered until there is an item to give it to.
  property string pendingPage: ""
  function showPage(page) {
    pendingPage = String(page || "")
    show()
    applyPendingPage()
  }
  function applyPendingPage() {
    if (pendingPage === "" || !windowLoader.item) return
    windowLoader.item.pageId = pendingPage
    pendingPage = ""
  }
  function hide() { if (windowLoader.item) windowLoader.item.hide() }
  function open() { show() }
  function close() { hide() }
  function toggle() {
    if (opened) hide()
    else show()
  }

  IpcHandler {
    target: "omasettings"
    function show(): void { root.show() }
    function showPage(page: string): void { root.showPage(page) }
    function hide(): void { root.hide() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Loader {
    id: windowLoader
    active: false
    asynchronous: true
    source: Qt.resolvedUrl("SettingsWindow.qml")
    onLoaded: {
      if (item) item.show()
      root.applyPendingPage()
    }
  }

  // ---------------- launcher entry -----------------------------------------

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
