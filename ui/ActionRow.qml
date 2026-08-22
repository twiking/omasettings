import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A row whose setting lives behind someone else's flow: the state is shown,
// and the button hands off to the command that owns it.
SettingRow {
  id: actionRow
  property string buttonText: ""
  signal triggered()

  // The row has one button, so activating the row presses it.
  onNavActivate: actionRow.triggered()

  Button {
    anchors.right: parent.right
    text: actionRow.buttonText
    bordered: true
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    fontFamily: Local.Palette.fontFamily
    onClicked: actionRow.triggered()
  }
}
