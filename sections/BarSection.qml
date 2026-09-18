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
  // the whole page. Wide enough for the longest set — the place field, two
  // arrows, Move and Disable — since a row that outgrew it would push its own
  // name out of the column and undo the point of having one, and no wider
  // than that: the slack is space between a widget and its own controls.
  readonly property real controlsWidth: Style.space(256)

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

      // ---------------- ordering by number ---------------------------------
      //
      // Every row shows the place it holds, as a number you can type over.
      // Nothing moves while you type: the numbers are a description of where
      // the section should end up, and Apply is where it is asked for. Moving
      // a widget from the end of a long section to the front is one number
      // and one press here, rather than a row of arrow clicks with the bar
      // redrawing itself between each of them.
      //
      // What was typed is kept here rather than on the rows: a refresh
      // rebuilds every row in the section, and a number typed into one of
      // them has to outlive that.
      property var typed: ({})

      function typedAt(index) {
        var value = typed[index]
        return value === undefined ? "" : String(value)
      }

      // A number equal to the place the row already holds is not a change,
      // and is dropped rather than staged — otherwise typing a number and
      // typing it back would leave a section waiting to be applied that has
      // nothing to say.
      function stage(index, value) {
        var next = {}
        for (var key in typed) next[key] = typed[key]
        if (String(value) === "") delete next[index]
        else next[index] = String(value)
        typed = next
      }

      function clearTyped() { typed = ({}) }

      // The numbers describe the list as it stands, by the places its widgets
      // hold now — so a list that changed under them leaves them describing
      // something that is no longer there: an arrow pressed, a widget
      // disabled, the bar edited from somewhere else entirely. They go when it
      // does. A re-read that says the same thing is not a change and leaves a
      // half-typed section alone.
      readonly property string signature: page.widgets(sectionGroup.sectionKey).join("\u0000")
      onSignatureChanged: sectionGroup.clearTyped()

      // The order the numbers add up to, as the places the widgets hold now.
      //
      // A number is where that widget should *end up*, so it is an insertion
      // and not a sort key. Sorting was the first thing tried here and it is
      // wrong in the one case the field exists for: giving the last of
      // twenty-three widgets the number 1 sorted it against a row that
      // already held 1, the tie went to the row that was there first, and the
      // widget landed second — every time, one place short of where it was
      // sent, at either end of the list.
      //
      // So the numbered widgets are lifted out, the rest close ranks in the
      // order they already have, and each numbered one is put back at the
      // place it was given. Several at once go in ascending order, so each
      // lands at the place it asks for in the list as the earlier ones have
      // left it.
      readonly property var order: {
        var count = page.widgets(sectionGroup.sectionKey).length
        var placed = []
        var out = []
        for (var i = 0; i < count; i++) {
          var text = sectionGroup.typedAt(i)
          var place = Number(text)
          if (text !== "" && isFinite(place)) placed.push({ index: i, place: place })
          else out.push(i)
        }
        placed.sort(function(a, b) { return a.place === b.place ? a.index - b.index : a.place - b.place })
        for (var p = 0; p < placed.length; p++) {
          var at = Math.max(0, Math.min(out.length, Math.round(placed[p].place) - 1))
          out.splice(at, 0, placed[p].index)
        }
        return out
      }

      readonly property bool reordered: {
        for (var i = 0; i < sectionGroup.order.length; i++)
          if (sectionGroup.order[i] !== i) return true
        return false
      }

      // One command for the whole section, so what the bar draws next is the
      // list as it was asked for, rather than a run of single moves it has to
      // redraw between.
      function applyOrder() {
        if (!sectionGroup.reordered) return
        var args = ["bar", "reorder", sectionGroup.sectionKey]
        for (var i = 0; i < sectionGroup.order.length; i++)
          args.push(String(sectionGroup.order[i]))
        // The work first: clearing the numbers takes the Apply row off the
        // page, and the button this came from with it.
        page.app.run(args)
        sectionGroup.clearTyped()
      }

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

          // What the place field shows: the number typed into it if there is
          // one, and otherwise the place this row holds, counted from one the
          // way the reader counts the rows.
          readonly property string placeText: sectionGroup.typedAt(widgetRow.index) !== ""
            ? sectionGroup.typedAt(widgetRow.index)
            : String(widgetRow.index + 1)

          // Enter starts typing into the place field and the row owns every
          // key until it is done, the same bargain TextRow makes: arrows that
          // moved the cursor down the page would otherwise be taken out of a
          // half-typed number.
          property bool editing: false

          navKeys: widgetRow.editing
            ? [{ key: "↵", label: "Save" }, { key: "Esc", label: "Cancel" }]
            : (isSpacer ? [{ key: "↵", label: "Place" }, { key: "←→", label: "Width" }]
                        : [{ key: "↵", label: "Place" }])
          navBlocking: widgetRow.editing
          onCurrentChanged: if (!widgetRow.current && widgetRow.editing) widgetRow.stopEditing()

          onNavActivate: placeField.forceActiveFocus()

          // The width is the only thing a spacer has, so the cursor edits it
          // directly rather than making the reader reach for the buttons.
          onNavStep: function(delta) {
            if (widgetRow.isSpacer) widgetRow.setSize(widgetRow.effective + delta * 4)
          }

          function stopEditing() {
            widgetRow.editing = false
            placeField.deselect()
            placeField.focus = false
            widgetRow.navRelease()
          }

          // A number counts from the keystroke that made it, not from some
          // later Enter: the Apply row is what says a section has an order
          // waiting, and a row that appeared only once the field was left
          // would have the page look like it had ignored what was typed.
          // Nothing is written either way — Apply is still the only thing
          // that touches the bar.
          function stagePlace(text) {
            var wanted = parseInt(text, 10)
            if (!isFinite(wanted)) {
              sectionGroup.stage(widgetRow.index, "")
              return
            }
            sectionGroup.stage(widgetRow.index,
                               wanted === widgetRow.index + 1 ? "" : String(wanted))
          }

          // Out of range is clamped rather than refused: asking for place 40
          // in a section of twelve is asking for the end of it, and a field
          // that simply refused the number would say nothing about why. It is
          // clamped once the number is done rather than while it is being
          // typed, since 4 is on the way to 40 and is a place of its own.
          function commitPlace(text) {
            var wanted = parseInt(text, 10)
            if (!isFinite(wanted)) {
              placeField.text = widgetRow.placeText
              return
            }
            wanted = Math.max(1, Math.min(widgetRow.total, wanted))
            widgetRow.stagePlace(String(wanted))
            // Typing into the field broke the binding that fills it, and a
            // number that staged nothing leaves that binding nothing to say,
            // so the field is put back by hand.
            placeField.text = String(wanted)
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

            // Where this row should end up, as a number. It reads as the
            // row's place until something is typed into it, so the list is
            // numbered whether or not anyone is sorting it.
            TextField {
              id: placeField
              anchors.verticalCenter: parent.verticalCenter
              visible: !widgetRow.choosing
              width: Style.space(48)
              horizontalPadding: Style.space(4)
              horizontalAlignment: TextInput.AlignHCenter
              text: widgetRow.placeText
              foreground: Ui.Palette.foreground
              accent: Ui.Palette.accent
              font.pixelSize: Style.font.caption
              hasCursor: widgetRow.current
              validator: IntValidator { bottom: 1; top: 999 }

              // The number already in the field is the answer to the last
              // question, not the start of the next one, so entering the
              // field selects it and the first digit replaces it.
              property bool fresh: false

              // Clicking straight into the field is editing too: the row has
              // to hand over the keyboard for it, or the window goes on
              // reading Up and Down as cursor moves while a number is being
              // typed.
              onActiveFocusChanged: {
                if (!activeFocus) return
                widgetRow.editing = true
                placeField.fresh = true
                placeField.selectAll()
              }

              // The binding above is broken by the first keystroke, so the
              // field is put back by hand wherever the number behind it
              // changes — Apply clearing the section among them.
              Connections {
                target: widgetRow
                function onPlaceTextChanged() { placeField.text = widgetRow.placeText }
              }

              // Every keystroke, so the Apply row is there as soon as there
              // is something to apply; the clamp and the tidy-up wait for the
              // number to be finished.
              onTextEdited: widgetRow.stagePlace(text)
              onEditingFinished: widgetRow.commitPlace(text)

              // Enter and Escape are answered here and stopped here: left to
              // bubble, the window reads Enter as "activate this row" and
              // drops straight back into the field it just left.
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  widgetRow.commitPlace(placeField.text)
                  widgetRow.stopEditing()
                  event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                  placeField.text = widgetRow.placeText
                  widgetRow.stopEditing()
                  event.accepted = true
                } else if (placeField.fresh) {
                  placeField.fresh = false
                  // A click puts the cursor where it landed and takes the
                  // selection with it, so what is in the field is cleared
                  // here rather than left to a selection that may not have
                  // survived the press. The key itself is not accepted: it
                  // goes on to the field and is the whole of the new number.
                  if (event.text.length === 1 && event.text >= " ") placeField.text = ""
                }
              }
            }

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

      // The numbers are worth nothing until they are asked for, so the row
      // that asks appears once they say something the section does not
      // already say, and goes again once they have been acted on or dropped.
      Ui.SettingRow {
        id: applyRow
        width: parent.width
        visible: sectionGroup.reordered && !applyRow.searchHidden
        label: "Apply order"
        description: "Puts every widget you numbered at the place you gave it, in one move."
        leadingWidth: page.controlsWidth
        navKeys: [{ key: "↵", label: "Apply" }]
        onNavActivate: sectionGroup.applyOrder()

        leading: Row {
          spacing: Style.space(6)

          Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Apply"
            bordered: true
            foreground: Ui.Palette.foreground
            accent: Ui.Palette.accent
            fontFamily: Ui.Palette.fontFamily
            fontSize: Style.font.caption
            onClicked: sectionGroup.applyOrder()
          }

          // Typing a number and thinking better of it has to be possible
          // here too, and one press puts the whole section back.
          Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf00d"
            bordered: true
            foreground: Ui.Palette.foreground
            accent: Ui.Palette.accent
            fontFamily: Ui.Palette.fontFamily
            fontSize: Style.font.caption
            onClicked: sectionGroup.clearTyped()
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
