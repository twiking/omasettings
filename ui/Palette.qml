pragma Singleton

import QtQuick
import qs.Commons

// One place for the colours and type the settings window is drawn in.
//
// Settings tracks the foundational palette rather than a themable surface of
// its own, so it renders consistently under every theme.
QtObject {
  readonly property color foreground: Color.popups.text
  // Popup surfaces are allowed to be translucent; a window full of text is
  // not, so the same colour is taken at full opacity.
  readonly property color background: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property color hairline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)
  readonly property color hover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  readonly property color selected: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
  readonly property string fontFamily: Style.font.family
}
