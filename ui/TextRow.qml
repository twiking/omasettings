import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

SettingRow {
  id: textRow
  property string value: ""
  property string placeholder: ""
  signal committed(string next)

  TextField {
    width: parent.width
    text: textRow.value
    placeholderText: textRow.placeholder
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    // Committing on Enter or focus loss keeps a half-typed layout string
    // from being applied one character at a time.
    onEditingFinished: if (text !== textRow.value) textRow.committed(text)
  }
}
