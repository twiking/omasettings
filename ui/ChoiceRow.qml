import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A short list of choices shown side by side rather than hidden behind a
// dropdown: when there are only a handful and their names are short, seeing
// them all is faster than opening a list to find out what they are.
SettingRow {
  id: choiceRow

  property var options: []
  property string value: ""
  signal picked(string next)

  // Options arrive either as bare strings or as {value,label} objects.
  readonly property var normalized: {
    var out = []
    var list = choiceRow.options || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && typeof entry === "object") out.push(entry)
      else out.push({ value: String(entry), label: String(entry) })
    }
    return out
  }

  ButtonGroup {
    anchors.right: parent.right
    options: choiceRow.normalized
    value: choiceRow.value
    foreground: Local.Palette.foreground
    background: Local.Palette.background
    accent: Local.Palette.accent
    fontFamily: Local.Palette.fontFamily
    fontSize: Style.font.caption
    onChanged: function(next) { choiceRow.picked(next) }
  }
}
