pragma Singleton

import QtQuick
import qs.Commons
import qs.Commons as Commons

// One place for the colours and type the settings window is drawn in.
//
// Settings tracks the foundational palette rather than a themable surface of
// its own, so it renders consistently under every theme.
QtObject {
  readonly property color foreground: Commons.Color.popups.text
  // Popup surfaces are allowed to be translucent; a window full of text is
  // not, so the same colour is taken at full opacity.
  readonly property color background: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property color hairline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)
  readonly property color hover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  readonly property color selected: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
  readonly property string fontFamily: Style.font.family
}
