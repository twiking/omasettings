import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

SettingRow {
  id: pickerRow
  property var options: []
  property string value: ""
  property bool searchable: false
  signal picked(string next)

  // Options arrive either as bare strings or as {value,label} objects.
  readonly property var normalized: {
    var out = []
    var list = pickerRow.options || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && typeof entry === "object") out.push(entry)
      else out.push({ value: String(entry), label: String(entry) })
    }
    return out
  }

  Loader {
    width: parent.width
    sourceComponent: pickerRow.searchable ? searchableComponent : plainComponent
  }

  Component {
    id: plainComponent
    Dropdown {
      width: parent ? parent.width : 0
      showLabel: false
      fontFamily: Local.Palette.fontFamily
      value: pickerRow.value
      options: pickerRow.normalized
      onChanged: function(next) { pickerRow.picked(next) }
    }
  }

  Component {
    id: searchableComponent
    SearchableDropdown {
      width: parent ? parent.width : 0
      showLabel: false
      fontFamily: Local.Palette.fontFamily
      placeholderText: "Search…"
      value: pickerRow.value
      options: pickerRow.normalized
      onChanged: function(next) { pickerRow.picked(next) }
    }
  }
}
