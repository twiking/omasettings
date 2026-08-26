import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

SettingRow {
  id: textRow
  property string value: ""
  property string placeholder: ""
  signal committed(string next)

  // A field that is an entry box rather than a setting: what is typed is added
  // somewhere and the box goes back to empty, and a button says so where an
  // Enter nobody presses would not.
  property string buttonText: ""
  property bool clearOnCommit: false

  // Enter starts typing. Until then the row is navigated past like any other,
  // which is what makes Up/Down usable on a page full of fields; while the
  // field has focus it owns every key, so navigation stops rather than
  // stealing the arrows out of a half-typed value.
  // Editing is a state this row owns, not a reading of where the focus
  // happens to be: the field can take focus back on its own, and a stale
  // "still editing" would strand the keyboard in a row nobody is typing into.
  // The window handles keys before the field sees them, so this flag is what
  // decides who gets them.
  property bool editing: false

  navKeys: editing
    ? [{ key: "\u21b5", label: clearOnCommit ? "Add" : "Save" }, { key: "Esc", label: "Cancel" }]
    : [{ key: "\u21b5", label: "Edit" }]

  // One door for the button and the key, so the two cannot drift apart.
  function commit(next) {
    if (clearOnCommit) {
      if (next === "") return
      textRow.committed(next)
      field.text = ""
    } else if (next !== textRow.value) {
      textRow.committed(next)
    }
  }

  onNavActivate: {
    editing = true
    field.forceActiveFocus()
    field.selectAll()
  }
  navBlocking: editing
  onCurrentChanged: if (!current && editing) navStopEditing()

  // Leaving the selection behind would have the next Backspace eat the value
  // rather than reset the setting.
  function navStopEditing() {
    editing = false
    field.deselect()
    field.focus = false
    textRow.navRelease()
  }

  TextField {
    id: field
    anchors.left: parent.left
    // Never to the holder's verticalCenter: it sizes itself from its children,
    // and a child centred in it is a binding loop.
    anchors.right: addButton.visible ? addButton.left : parent.right
    anchors.rightMargin: addButton.visible ? Style.space(8) : 0
    text: textRow.value
    placeholderText: textRow.placeholder
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    // The kit draws the keyboard cursor on the control itself, so a field the
    // cursor is resting on looks different from one being typed into.
    hasCursor: textRow.current
    // Committing on Enter or focus loss keeps a half-typed layout string
    // from being applied one character at a time.
    onEditingFinished: textRow.commit(text)
    // Enter and Escape are handled here and stopped here. The field emits
    // accepted without accepting the event, so an Enter left to bubble
    // reaches the window, which reads it as "activate this row" and drops
    // straight back into editing the field just left.
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        // Dropping focus is what commits: editingFinished writes the value.
        textRow.navStopEditing()
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        text = textRow.value
        textRow.navStopEditing()
        event.accepted = true
      }
    }
  }

  Button {
    id: addButton
    anchors.right: parent.right
    visible: textRow.buttonText !== ""
    text: textRow.buttonText
    bordered: true
    foreground: Local.Palette.foreground
    accent: Local.Palette.accent
    fontFamily: Local.Palette.fontFamily
    // Committing from here rather than dropping focus: the field may never
    // have had it, so there is no editingFinished to wait for.
    onClicked: textRow.commit(field.text)
  }
}
