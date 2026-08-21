import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  Ui.SettingGroup {
    title: "Add a binding"
    note: "Keys as Hyprland spells them: SUPER, SHIFT, CTRL, ALT, and a key. Binding a combination that is already taken replaces it."

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
