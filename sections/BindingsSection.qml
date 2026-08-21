import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  // "super+shift+r", "SUPER + SHIFT + R" and "Super Shift R" are one chord;
  // the helper canonicalises the same way before it compares.
  function canonicalKeys(text) {
    return String(text).toUpperCase().replace(/\+/g, " ").trim().split(/\s+/).filter(function(part) {
      return part !== ""
    }).join(" + ")
  }

  // What the chord being typed would take over, if anything.
  function bindingFor(text) {
    var wanted = canonicalKeys(text)
    if (wanted === "") return null
    var items = app.bindings.items !== undefined ? app.bindings.items : []
    for (var i = 0; i < items.length; i++)
      if (String(items[i].canonical) === wanted) return items[i]
    return null
  }

  Ui.SettingGroup {
    title: "Add a binding"
    note: "Keys as Hyprland spells them: SUPER, SHIFT, CTRL, ALT, and a key."

    Row {
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: keysField
        width: (parent.width - addBindingButton.width - Style.space(24)) * 0.3
        placeholderText: "SUPER + SHIFT + R"
        foreground: app.foreground
        accent: app.accent
      }

      TextField {
        id: bindingDescriptionField
        width: (parent.width - addBindingButton.width - Style.space(24)) * 0.25
        placeholderText: "what it does"
        foreground: app.foreground
        accent: app.accent
      }

      TextField {
        id: commandField
        width: (parent.width - addBindingButton.width - Style.space(24)) * 0.45
        placeholderText: "command to run"
        foreground: app.foreground
        accent: app.accent
      }

      Button {
        id: addBindingButton
        text: "Add"
        bordered: true
        foreground: app.foreground
        accent: app.accent
        fontFamily: app.fontFamily
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
          if (keysField.text.trim() === "" || commandField.text.trim() === "") return
          app.run(["keys", "add", keysField.text.trim(),
                    bindingDescriptionField.text.trim(), commandField.text.trim()])
          keysField.text = ""
          bindingDescriptionField.text = ""
          commandField.text = ""
        }
      }
    }

    // Saying so before the button is pressed, rather than after the old
    // binding is gone.
    Text {
      readonly property var clash: bindingFor(keysField.text)

      width: parent.width
      visible: clash !== null
      wrapMode: Text.WordWrap
      text: clash
        ? canonicalKeys(keysField.text) + " already runs " +
          (String(clash.description) !== "" ? String(clash.description) : "something else") +
          ". Adding this replaces it."
        : ""
      color: Color.urgent
      font.family: Ui.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Ui.SettingGroup {
    title: "Every binding"

    TextField {
      width: parent.width
      placeholderText: "Search keys or actions…"
      text: app.bindingFilter
      foreground: app.foreground
      accent: app.accent
      onTextChanged: app.bindingFilter = text
    }

    Text {
      width: parent.width
      text: app.visibleBindings.length + " of " + (app.bindings.items !== undefined ? app.bindings.items.length : 0)
      color: app.muted
      font.family: app.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: app.visibleBindings
      delegate: Ui.BindingRow {
        required property var modelData
        width: parent.width
        keys: modelData.keys
        description: modelData.description
        command: modelData.command
        source: modelData.source
        onRemoveRequested: app.run(["keys", "remove", modelData.keys])
        onDisableRequested: app.run(["keys", "disable", modelData.keys])
      }
    }
  }
}
