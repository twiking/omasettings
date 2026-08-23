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

  // Space opens the list, the way clicking the control would; stepping picks
  // a neighbour without opening anything. While the list is open it owns the
  // keyboard — its own Up/Down and Escape are the ones that should run.
  navKeys: [{ key: "Space", label: "Open list" }, { key: "\u2190\u2192", label: "Choose" }]

  onNavActivate: if (dropdownLoader.item) dropdownLoader.item.open()
  navBlocking: dropdownLoader.item ? dropdownLoader.item.popupOpen === true : false

  onNavStep: function(delta) {
    var list = pickerRow.normalized
    if (list.length === 0) return
    var at = 0
    for (var i = 0; i < list.length; i++)
      if (String(list[i].value) === String(pickerRow.value)) { at = i; break }
    var next = Math.max(0, Math.min(list.length - 1, at + delta))
    if (next !== at) pickerRow.picked(String(list[next].value))
  }

  Loader {
    id: dropdownLoader
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
