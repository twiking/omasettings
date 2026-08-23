import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// The keyboard cursor for a row that is not a SettingRow.
//
// A device, a network and a binding are lists of things rather than one
// setting each, and their rows are built to look like it. Rather than force
// them into SettingRow's shape, this carries the same contract into them:
// drop one in, anchored over the row, and the row joins the cursor.
//
// It registers itself rather than its parent, and mirrors the geometry the
// window sorts by, so from the window's side it is simply another row.
Item {
  id: nav

  // Filled in by whoever drops it in.
  property var navKeys: []
  signal navActivate()
  signal navStep(int delta)

  // The window's side of the contract.
  property bool current: false
  property bool navBlocking: false
  property bool changed: false
  signal resetRequested()

  // Behind the row's own content: the band is a background, and drawing it
  // over the text would tint what it is meant to be pointing at.
  z: -1

  property var navController: null

  function findController() {
    var node = nav.parent
    while (node) {
      if (node.registerNavRow !== undefined) return node
      if (node.app !== undefined && node.app !== null
          && node.app.registerNavRow !== undefined) return node.app
      node = node.parent
    }
    return null
  }

  Component.onCompleted: {
    nav.navController = findController()
    if (nav.navController) nav.navController.registerNavRow(nav)
  }

  Component.onDestruction: {
    if (nav.navController) nav.navController.unregisterNavRow(nav)
  }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -Style.space(10)
    anchors.rightMargin: -Style.space(10)
    radius: Style.cornerRadius
    color: Qt.rgba(Local.Palette.accent.r, Local.Palette.accent.g, Local.Palette.accent.b, 0.14)
    visible: nav.current
  }
}
