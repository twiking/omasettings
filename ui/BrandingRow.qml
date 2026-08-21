import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// Three ways to set one piece of branding, the way the menu offers them:
// type it, point at an image, or put the shipped one back.
SettingRow {
  id: brandingRow
  // "text", "image" or "default" — the caller decides what each one runs.
  signal chose(string variant)

  Row {
    anchors.right: parent.right
    spacing: Style.space(8)

    Button {
      text: "Text…"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      onClicked: brandingRow.chose("text")
    }

    Button {
      text: "Image…"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      onClicked: brandingRow.chose("image")
    }

    Button {
      text: "Reset"
      bordered: true
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      fontFamily: Local.Palette.fontFamily
      onClicked: brandingRow.chose("default")
    }
  }
}
