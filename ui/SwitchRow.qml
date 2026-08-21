import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

SettingRow {
  id: switchRow
  property bool checked: false
  signal requested(bool next)

  ToggleSwitch {
    anchors.right: parent.right
    checked: switchRow.checked
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    interactive: switchRow.enabled
    onToggled: switchRow.requested(!switchRow.checked)
  }
}
