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

  // Widths, in step with the ids above: a spacer is nothing but its width, so
  // its row cannot describe itself without this. Null everywhere else.
  readonly property var layoutSizes: (app.barState.sizes !== undefined ? app.barState.sizes : ({}))
  function sizeAt(section, index) {
    var list = layoutSizes[section]
    var size = list !== undefined && list !== null ? list[index] : null
    return size === undefined || size === null ? -1 : Number(size)
  }

  // Blank space is the one bar widget you add rather than own — its manifest
  // allows more than one — so it is added to a section here and removed from
  // it, and never sits in the Disabled group waiting to come back.
  readonly property string spacerId: "omarchy.spacer"

  // One width for every row's controls, so the names after them line up down
  // the whole page. Wide enough for the longest set — two arrows, Move and
  // Disable — since a row that outgrew it would push its own name out of the
  // column and undo the point of having one.
  readonly property real controlsWidth: Style.space(230)

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

  // Every bar widget appears once on this page: under the section it sits in,
  // or — if it is disabled — in the group at the foot. A list of switches
  // beside the three section lists would have named each widget twice and left
  // the reader to work out which of the two lists to believe.
  readonly property var barWidgets: {
    var all = app.plugins !== undefined ? app.plugins : []
    var out = []
    for (var i = 0; i < all.length; i++)
      if ((all[i].kinds || []).indexOf("bar-widget") !== -1) out.push(all[i])
    return out
  }

  function inBar(id) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = widgets(sections[s])
      for (var i = 0; i < list.length; i++)
        if (String(list[i]) === String(id)) return true
    }
    return false
  }

  readonly property var offWidgets: barWidgets.filter(function(widget) {
    return widget.id !== page.spacerId && !page.inBar(widget.id)
  }).sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })

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

          readonly property bool isSpacer: String(modelData) === page.spacerId

          // A width takes a state refresh to come back, so two presses inside
          // that window would both compute from the same stale number and the
          // second would be swallowed. What was asked for stands until the
          // answer arrives.
          readonly property int size: page.sizeAt(section, index)
          property int pending: -1
          readonly property int effective: pending >= 0 ? pending : size
          onSizeChanged: if (size === pending) pending = -1

          function setSize(next) {
            var wanted = Math.max(0, Math.min(400, next))
            if (wanted === effective) return
            pending = wanted
            page.app.run(["bar", "spacer", "size", section, String(index), String(wanted)])
          }

          width: parent.width
          label: isSpacer ? "Spacer" : page.widgetName(modelData)
          // The width was the description while there was nowhere else to
          // say it. The slider reads it out now, so the row says what every
          // other row in the list says: which widget this is.
          description: modelData

          // The width is the only thing a spacer has, so the cursor edits it
          // directly rather than making the reader reach for the buttons.
          navKeys: isSpacer ? [{ key: "←→", label: "Width" }] : []
          onNavStep: function(delta) {
            if (widgetRow.isSpacer) widgetRow.setSize(widgetRow.effective + delta * 4)
          }

          // Which section a widget belongs to is one decision, so it is one
          // button: Move asks, and the two sections it is not in answer.
          property bool choosing: false
          readonly property var elsewhere: ["left", "center", "right"].filter(function(s) {
            return s !== widgetRow.section
          })

          function sectionTitle(key) {
            return key === "left" ? "Left" : key === "center" ? "Center" : "Right"
          }

          // Everything you can do to a row sits in front of its name, in the
          // order you reach for it: where it sits, then which section, then
          // whether it is in the bar at all. One width for the lot, so every
          // name in the list starts in the same place.
          leadingWidth: page.controlsWidth
          leading: Row {
            spacing: Style.space(6)

            // Its place within the section is a straight nudge.
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
              onClicked: page.app.run(["bar", "shift-at", widgetRow.section, String(widgetRow.index),
                                       "up", String(widgetRow.modelData)])
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
              onClicked: page.app.run(["bar", "shift-at", widgetRow.section, String(widgetRow.index),
                                       "down", String(widgetRow.modelData)])
            }

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

            // Which section a widget belongs to is one decision, so it is one
            // button: Move asks, and the two sections it is not in answer.
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
                // The move goes first and the buttons close after it. Closing
                // them empties this Repeater's model, which destroys this
                // delegate and invalidates the context every id in here is
                // resolved through — `page` included, so the line that did the
                // work came after the line that took away its ability to do it,
                // and the move was silently dropped.
                //
                // By place, not by id: two spacers in a section are the same
                // id twice, and only where they sit tells them apart. The id
                // rides along to be checked against the slot.
                onClicked: {
                  page.app.run(["bar", "move-at", widgetRow.section, String(widgetRow.index),
                                modelData, String(widgetRow.modelData)])
                  widgetRow.choosing = false
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

            // A spacer is removed rather than disabled: there is nothing of it
            // to keep, and nothing waiting in the Disabled group to come back.
            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: widgetRow.isSpacer && !widgetRow.choosing
              text: "Remove"
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: page.app.run(["bar", "spacer", "remove", widgetRow.section, String(widgetRow.index)])
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: !widgetRow.isSpacer && !widgetRow.choosing
              text: "Disable"
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: page.app.run(["bar", "disable", String(widgetRow.modelData)])
            }
          }

          // The width is read and set the way every other number in this
          // window is: the slider fills the control side of the row and says
          // what it is worth beside it, the same shape NumberRow gives a
          // setting on any other page. It is a value, not something you do to
          // the row, so it stays on the right while the controls lead.
          Row {
            width: parent.width
            visible: widgetRow.isSpacer && !widgetRow.choosing
            spacing: Style.space(10)

            // Written when the drag ends, like every other slider here, so
            // crossing the row is one write rather than a hundred.
            PanelSlider {
              id: widthSlider
              width: parent.width - widthReadout.width - Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              integer: true
              step: 2
              minimum: 0
              maximum: 400
              value: widgetRow.effective
              onReleased: function(next) { widgetRow.setSize(next) }
            }

            Text {
              id: widthReadout
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(76)
              horizontalAlignment: Text.AlignRight
              text: (widthSlider.dragging ? Math.round(widthSlider.liveValue) : widgetRow.effective) + " px"
              color: Ui.Palette.muted
              font.family: Ui.Palette.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

    }
  }

  // One row rather than one under each section: three of these said the same
  // thing three times, and where a spacer goes is a question the row can ask
  // once it is pressed — the same way Move asks it.
  Ui.SettingGroup {
    Ui.SettingRow {
      id: addSpacer
      width: parent.width
      label: "Add spacer"
      description: "Blank space, as wide as you set it. Add as many as you like."
      // The same column as the rows above, so this name lines up with theirs.
      leadingWidth: page.controlsWidth

      property bool choosing: false
      navKeys: [{ key: "↵", label: "Add" }]
      onNavActivate: addSpacer.choosing = true

      // Everything you can do sits in front of the name here too, so this row
      // reads like the ones above it: press Add, then say where.
      leading: Row {
        spacing: Style.space(6)

        Button {
          anchors.verticalCenter: parent.verticalCenter
          visible: !addSpacer.choosing
          text: "Add"
          bordered: true
          foreground: Ui.Palette.foreground
          accent: Ui.Palette.accent
          fontFamily: Ui.Palette.fontFamily
          fontSize: Style.font.caption
          onClicked: addSpacer.choosing = true
        }

        Repeater {
          model: addSpacer.choosing ? ["left", "center", "right"] : []
          delegate: Button {
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            text: modelData === "left" ? "Left" : modelData === "center" ? "Center" : "Right"
            bordered: true
            foreground: Ui.Palette.foreground
            accent: Ui.Palette.accent
            fontFamily: Ui.Palette.fontFamily
            fontSize: Style.font.caption
            // The work first: closing the buttons destroys this delegate along
            // with the context every id here resolves through.
            onClicked: {
              page.app.run(["bar", "spacer", "add", modelData])
              addSpacer.choosing = false
            }
          }
        }

        Button {
          anchors.verticalCenter: parent.verticalCenter
          visible: addSpacer.choosing
          text: "\uf00d"
          bordered: true
          foreground: Ui.Palette.foreground
          accent: Ui.Palette.accent
          fontFamily: Ui.Palette.fontFamily
          fontSize: Style.font.caption
          onClicked: addSpacer.choosing = false
        }
      }
    }
  }

  // Not settings, but the other half of the layout: what the bar could show
  // and does not.
  Ui.SettingGroup {
    title: "Disabled"
    note: page.offWidgets.length === 0
      ? "Every widget you have is in the bar."
      : "These keep their settings and their old place until they are enabled again."

    Repeater {
      model: page.offWidgets

      delegate: Ui.WidgetRow {
        required property var modelData
        width: parent.width
        buttonText: "Enable"
        label: String(modelData.name)
        detail: String(modelData.id)
        onTriggered: page.app.run(["bar", "enable", String(modelData.id)])
      }
    }
  }
}
