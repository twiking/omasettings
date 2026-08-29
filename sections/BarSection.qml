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
          description: isSpacer ? effective + " px" : modelData

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

          Row {
            anchors.right: parent.right
            spacing: Style.space(6)

            // A spacer is its width, so the width is the first thing on its
            // row rather than something to go looking for.
            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: widgetRow.isSpacer && !widgetRow.choosing
              enabled: widgetRow.effective > 0
              opacity: enabled ? 1 : 0.35
              text: ""
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: widgetRow.setSize(widgetRow.effective - 4)
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: widgetRow.isSpacer && !widgetRow.choosing
              enabled: widgetRow.effective < 400
              opacity: enabled ? 1 : 0.35
              text: ""
              bordered: true
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              fontFamily: Ui.Palette.fontFamily
              fontSize: Style.font.caption
              onClicked: widgetRow.setSize(widgetRow.effective + 4)
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

            // Disabling is about the widget rather than where it goes, so it
            // sits last, after the buttons that place it. A spacer is removed
            // instead: there is nothing of it to keep, and nothing waiting in
            // the Disabled group for it to come back to.
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
          }
        }
      }

      // Under the section it adds to, because which section is the whole of
      // the question — one row here says it, where three buttons somewhere
      // else would have had to ask it again.
      Ui.ActionRow {
        width: parent.width
        label: "Add spacer"
        description: "Blank space, as wide as you set it. Add as many as you like."
        buttonText: "Add"
        onTriggered: page.app.run(["bar", "spacer", "add", sectionGroup.sectionKey])
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
