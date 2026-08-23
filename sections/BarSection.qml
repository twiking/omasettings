import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null

  readonly property var layout: (app.barState.layout !== undefined ? app.barState.layout : ({}))

  function widgets(section) {
    var list = layout[section]
    return list !== undefined && list !== null ? list : []
  }

  // The bar stores ids; the plugin list is where the names are.
  function widgetName(id) {
    var list = app.plugins
    for (var i = 0; i < list.length; i++)
      if (list[i].id === id) return list[i].name
    return id
  }

  Ui.SettingGroup {
    title: "Placement"

    Ui.PickerRow {
      label: "Position"
      value: app.barState.position !== undefined ? String(app.barState.position) : "top"
      options: ["top", "bottom", "left", "right"]
      onPicked: function(next) { app.set("bar-position", next) }
      changed: app.isChanged("bar-position")
      onResetRequested: app.resetSetting("bar-position")
    }

    Ui.SwitchRow {
      label: "Transparent"
      description: "Drops the bar's own background so the wallpaper shows through."
      checked: app.barState.transparent === true
      onRequested: function(next) { app.set("bar-transparent", next ? "true" : "false") }
      changed: app.isChanged("bar-transparent")
      onResetRequested: app.resetSetting("bar-transparent")
    }

    Ui.PickerRow {
      label: "Centered widget"
      description: "The widget the centre section is anchored on."
      value: app.barState.centerAnchor !== undefined ? String(app.barState.centerAnchor) : ""
      options: app.barWidgetIds()
      searchable: true
      onPicked: function(next) { app.set("bar-center-anchor", next) }
      changed: app.isChanged("bar-center-anchor")
      onResetRequested: app.resetSetting("bar-center-anchor")
    }
  }

  // ---------------- layout -------------------------------------------------
  // One group per section, in the order the bar draws them. A widget moves
  // sideways between sections and up or down within one, which is the whole
  // vocabulary the bar has: there is no position beyond which section and
  // which place in it.
  Repeater {
    model: [
      { key: "left", title: "Left" },
      { key: "center", title: "Center" },
      { key: "right", title: "Right" }
    ]

    delegate: Ui.SettingGroup {
      id: sectionGroup
      required property var modelData
      readonly property string sectionKey: modelData.key
      width: parent.width
      title: modelData.title
      note: page.widgets(modelData.key).length === 0 ? "Nothing here yet." : ""

      Repeater {
        model: page.widgets(modelData.key)
        delegate: Ui.SettingRow {
          id: widgetRow
          required property var modelData
          required property int index
          readonly property string section: sectionGroup.sectionKey
          readonly property int total: page.widgets(section).length

          width: parent.width
          label: page.widgetName(modelData)
          description: modelData

          // Which section a widget belongs to is one decision, so it is one
          // button: Move asks, and the two sections it is not in answer.
          property bool choosing: false
          readonly property var elsewhere: ["left", "center", "right"].filter(function(s) {
            return s !== widgetRow.section
          })

          function sectionTitle(key) {
            return key === "left" ? "Left" : key === "center" ? "Center" : "Right"
          }

          Row {
            anchors.right: parent.right
            spacing: Style.space(6)

            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: !widgetRow.choosing
              text: "Move"
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: widgetRow.choosing = true
            }

            Repeater {
              model: widgetRow.choosing ? widgetRow.elsewhere : []
              delegate: Button {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                text: widgetRow.sectionTitle(modelData)
                bordered: true
                foreground: Ui.Palette.foreground
                accent: Ui.Palette.accent
                fontFamily: Ui.Palette.fontFamily
                fontSize: Style.font.caption
                onClicked: {
                  widgetRow.choosing = false
                  page.app.run(["bar", "move", widgetRow.modelData, modelData])
                }
              }
            }

            // Asking and then thinking better of it has to be possible.
            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: widgetRow.choosing
              text: "\uf00d"
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: widgetRow.choosing = false
            }

            // Its place within the section stays a straight nudge.
            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: !widgetRow.choosing
              enabled: widgetRow.index > 0
              opacity: enabled ? 1 : 0.35
              text: "\uf062"
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: page.app.run(["bar", "shift", widgetRow.modelData, "up"])
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: !widgetRow.choosing
              enabled: widgetRow.index < widgetRow.total - 1
              opacity: enabled ? 1 : 0.35
              text: "\uf063"
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: page.app.run(["bar", "shift", widgetRow.modelData, "down"])
            }
          }
        }
      }
    }
  }
}
