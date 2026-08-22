import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null

  // What the update sweep has learned so far, keyed by plugin id: still
  // checking, and how many commits are waiting (-1 not a git checkout,
  // -2 the fetch failed). Both are replaced wholesale rather than mutated,
  // since that is what re-evaluates the rows' bindings.
  property var checking: ({})
  // Seeded from the last sweep's cache, so leaving the page and coming back
  // shows what was already learned instead of an empty list.
  property var behind: (app.state.pluginUpdates && app.state.pluginUpdates.results) || ({})
  property double checkedAt: (app.state.pluginUpdates && app.state.pluginUpdates.checkedAt) || 0
  property bool checked: checkedAt > 0

  // Adding, removing and updating hand off to a terminal flow that outlives
  // the window's own refresh, so the list is re-read a few times afterwards
  // rather than once, 400ms later, while the clone is still downloading.
  Timer {
    id: catchUp
    interval: 3000
    repeat: true
    property int ticks: 0
    onTriggered: {
      page.app.refresh()
      if (++ticks >= 10) stop()
    }
  }

  function handOff(args) {
    app.run(args)
    catchUp.ticks = 0
    catchUp.restart()
  }

  function checkUpdates() {
    if (updateProc.running) return
    var pending = {}
    for (var i = 0; i < app.plugins.length; i++) pending[app.plugins[i].id] = true
    page.checking = pending
    updateProc.running = true
  }

  // The sweep prints a plugin's verdict the moment its own fetch settles, so
  // spinners are retired one at a time instead of all at the end.
  Process {
    id: updateProc
    command: ["bash", page.app.helperPath, "plugin", "updates"]
    stdout: SplitParser {
      splitMarker: "\n"
      // A fresh object each time, not the same one mutated: assigning back
      // an unchanged reference tells the rows nothing, and their bindings
      // never re-run.
      onRead: function(line) {
        var parts = line.split("\t")
        if (parts.length < 2) return
        var id = parts[0].trim()
        var next = {}
        for (var k in page.behind) next[k] = page.behind[k]
        next[id] = parseInt(parts[1], 10)
        page.behind = next
        var pending = {}
        for (var p in page.checking) if (p !== id) pending[p] = true
        page.checking = pending
      }
    }
    onRunningChanged: if (!running) {
      page.checking = ({})
      page.checked = true
      // The sweep also wrote the cache; re-reading keeps checkedAt honest.
      page.app.refresh()
    }
  }

  Ui.SettingGroup {
    Ui.ActionRow {
      label: "Add plugin"
      description: "Install a plugin from a git URL"
      buttonText: "Add…"
      onTriggered: page.handOff(["menu", "run", "setup.plugin.add"])
    }

    Ui.ActionRow {
      label: "Check for updates"
      description: updateProc.running
        ? "Fetching…"
        : (page.checked
           ? ((page.updatesFound > 0
               ? page.updatesFound + (page.updatesFound === 1 ? " plugin has" : " plugins have") + " an update"
               : "Everything is up to date") + " · checked " + page.checkedAgo)
           : "Asks every plugin's remote what it has")
      buttonText: updateProc.running ? "Checking…" : "Check"
      onTriggered: page.checkUpdates()
    }
  }

  // How long ago in words, so a stale answer says so rather than passing
  // itself off as current.
  readonly property string checkedAgo: {
    if (checkedAt <= 0) return "never"
    var mins = Math.floor((Date.now() / 1000 - checkedAt) / 60)
    if (mins < 1) return "just now"
    if (mins < 60) return mins + (mins === 1 ? " minute ago" : " minutes ago")
    var hours = Math.floor(mins / 60)
    if (hours < 24) return hours + (hours === 1 ? " hour ago" : " hours ago")
    var days = Math.floor(hours / 24)
    return days + (days === 1 ? " day ago" : " days ago")
  }

  readonly property int updatesFound: {
    var n = 0
    for (var id in behind) if (behind[id] > 0) n++
    return n
  }

  // The installed list reads as its own thing, not as a third action row.
  Item { width: 1; height: Style.space(16) }

  Ui.SettingGroup {
    Repeater {
      model: app.plugins
      delegate: Ui.SettingRow {
        id: pluginRow
        required property var modelData
        readonly property int commitsBehind: page.behind[modelData.id] === undefined ? 0 : page.behind[modelData.id]
        readonly property bool busy: page.checking[modelData.id] === true

        width: parent.width
        label: modelData.name
        description: modelData.id
          + (modelData.firstParty ? " · built in" : "")
          + (commitsBehind === -1 ? " · not a git checkout"
             : commitsBehind === -2 ? " · could not reach its remote"
             : commitsBehind > 0 ? " · " + commitsBehind + (commitsBehind === 1 ? " commit" : " commits") + " behind"
             : "")

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          // One spinner per plugin, spinning only while that plugin's own
          // fetch is still out.
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: pluginRow.busy
            text: "󰑐"
            color: Ui.Palette.muted
            font.family: Ui.Palette.fontFamily
            font.pixelSize: Style.font.body
            RotationAnimator on rotation {
              running: pluginRow.busy
              from: 0
              to: 360
              duration: 900
              loops: Animation.Infinite
            }
          }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: pluginRow.commitsBehind > 0
            text: "Update"
            bordered: true
            foreground: Ui.Palette.foreground
            accent: Ui.Palette.accent
            fontFamily: Ui.Palette.fontFamily
            fontSize: Style.font.caption
            onClicked: page.handOff(["plugin", "update", pluginRow.modelData.id])
          }

          // Only a plugin you installed can be removed; the built-in ones
          // come back with the next update anyway.
          Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: !pluginRow.modelData.firstParty
            text: "Remove"
            bordered: true
            foreground: Ui.Palette.foreground
            accent: Ui.Palette.accent
            fontFamily: Ui.Palette.fontFamily
            fontSize: Style.font.caption
            onClicked: page.handOff(["plugin", "remove", pluginRow.modelData.id])
          }

          ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: pluginRow.modelData.enabled === true
            foreground: Ui.Palette.foreground
            accent: Ui.Palette.accent
            onToggled: page.app.run(["plugin", pluginRow.modelData.enabled === true ? "disable" : "enable", pluginRow.modelData.id])
          }
        }
      }
    }
  }
}
