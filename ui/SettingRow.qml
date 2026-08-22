import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// Label on the left, control on the right — the shape every row shares.
Item {
  id: settingRow
  property string label: ""
  property string description: ""
  // Set by pages whose settings this window owns: whether the value on screen
  // was chosen here, and how to hand it back. A row that says nothing shows
  // nothing, so rows backed by live system state stay unmarked.
  property bool changed: false
  signal resetRequested()

  // ---------------- keyboard cursor ---------------------------------------
  // The window drives one cursor down the page; a row says what the cursor
  // means for its own control. A row that answers neither signal is still
  // navigable, it just has nothing to do when activated.
  property bool current: false
  // While a row owns the keyboard outright — a dropdown is open, a field is
  // being typed into — the window stops handling keys and lets it through.
  property bool navBlocking: false
  signal navActivate()
  signal navStep(int delta)

  // Rows are nested several layers inside a page, so the controller is found
  // by walking up rather than passed down through every group.
  // The walk stops at the page rather than the window — a window is not the
  // visual parent of what it shows — so what is looked for is the page's own
  // handle on the window, which every section is given when it is loaded.
  function navController() {
    var node = settingRow.parent
    while (node) {
      if (node.registerNavRow !== undefined) return node
      if (node.app !== undefined && node.app !== null
          && node.app.registerNavRow !== undefined) return node.app
      node = node.parent
    }
    return null
  }

  Component.onCompleted: {
    var nav = navController()
    if (nav) nav.registerNavRow(settingRow)
  }

  Component.onDestruction: {
    var nav = navController()
    if (nav) nav.unregisterNavRow(settingRow)
  }
  default property alias control: controlHolder.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(labelColumn.implicitHeight, controlHolder.implicitHeight)
  opacity: enabled ? 1 : 0.45

  Rectangle {
    // Wider than the row itself, so the cursor reads as a band across the
    // page rather than a box drawn around the text.
    anchors.fill: parent
    anchors.leftMargin: -Style.space(10)
    anchors.rightMargin: -Style.space(10)
    anchors.topMargin: -Style.space(6)
    anchors.bottomMargin: -Style.space(6)
    radius: Style.cornerRadius
    color: Qt.rgba(Local.Palette.accent.r, Local.Palette.accent.g, Local.Palette.accent.b, 0.14)
    visible: settingRow.current
  }

  Column {
    id: labelColumn
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.5
    spacing: Style.space(2)

    // A setting this window has changed says so on its own title line: the
    // mark ahead of the name, the way out after it.
    Row {
      spacing: Style.space(6)

      // A Row lines its children up by the top, which leaves the smaller
      // (reset) floating above the name it belongs to. Both sit on the
      // name's baseline instead, so the three read as one line.
      Text {
        anchors.baseline: titleText.baseline
        visible: settingRow.changed
        text: "\u25cf"
        color: Local.Palette.accent
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        id: titleText
        text: settingRow.label
        color: Local.Palette.foreground
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        id: resetLink
        anchors.baseline: titleText.baseline
        visible: settingRow.changed
        text: "(reset)"
        color: resetMouse.containsMouse ? Local.Palette.accent : Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
        font.underline: resetMouse.containsMouse

        MouseArea {
          id: resetMouse
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: settingRow.resetRequested()
        }
      }
    }

    Text {
      visible: settingRow.description !== ""
      width: parent.width
      text: settingRow.description
      wrapMode: Text.WordWrap
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }

    // Under the label rather than beside the control: it belongs to what the
    // setting is, not to what it is set to, and there is room here for the
    // way out to say what it does.
  }

  Item {
    id: controlHolder
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * 0.46
    implicitHeight: childrenRect.height
  }
}
