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
    title: "Add a sequence"
    note: "The compose key first, then the keys to press after it. Write the compose key as <Multi_key>."

    Row {
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: keysField
        width: (parent.width - addButton.width - Style.space(16)) * 0.45
        placeholderText: "<Multi_key> <s> <e>"
        foreground: app.foreground
        accent: app.accent
      }

      TextField {
        id: textField
        width: (parent.width - addButton.width - Style.space(16)) * 0.55
        placeholderText: "text it types"
        foreground: app.foreground
        accent: app.accent
      }

      Button {
        id: addButton
        text: "Add"
        bordered: true
        foreground: app.foreground
        accent: app.accent
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
          if (keysField.text.trim() === "" || textField.text === "") return
          app.run(["compose", "add", keysField.text.trim(), textField.text])
          keysField.text = ""
          textField.text = ""
        }
      }
    }
  }

  Ui.SettingGroup {
    title: "Your sequences"
    note: app.composeEntries.length === 0 ? "Nothing defined yet." : ""

    Repeater {
      model: app.composeEntries
      delegate: Item {
        required property var modelData
        width: parent.width
        implicitHeight: Style.spacing.controlHeight

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width * 0.45
          elide: Text.ElideRight
          text: modelData.keys
          color: app.foreground
          font.family: app.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: parent.width * 0.47
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width * 0.4
          elide: Text.ElideRight
          text: modelData.text
          color: app.muted
          font.family: app.fontFamily
          font.pixelSize: Style.font.body
        }

        PanelActionButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: "\uf00d"
          tooltipText: "Remove"
          foreground: app.foreground
          onClicked: app.run(["compose", "remove", modelData.keys])
        }
      }
    }
  }
}
