import QtQuick
import qs.Commons

// One titled grid of app tiles in the super menu (SuperMenu.qml): Pinned, a
// group, Frequent or search results. Tiles in Pinned and the groups can be
// dragged to a new spot, in their section or another (Frequent's too, which
// pins them there); every tile has a +/- button (on hover or when selected)
// to pin or unpin it, and right-click opens its menu (move to a group, ...);
// in a removable grid (Frequent) an × takes the app out of that grid. A
// section's title folds it (collapsible); a group's can be renamed
// (double-click), moved up or down, or deleted (editable).
Column {
  id: section
  required property var owner
  property string title: ""
  property var entries: []
  property int offset: 0
  property string empty: ""
  property bool reorderable: false
  property bool removable: false
  property int sectionIndex: -1      // its section in the owner (-2: Frequent)
  property bool draggable: false     // tiles can be dragged out (into a section)
  property bool collapsible: false
  property bool collapsed: false
  property bool editable: false      // a group: rename, move, delete
  property bool isFirstGroup: false
  property bool isLastGroup: false

  width: owner.gridWidth
  spacing: Style.space(6)

  readonly property int gap: Style.space(6)

  readonly property bool renaming: owner.renaming === sectionIndex && editable
  readonly property bool dropHere: owner.dragIndex >= 0 && owner.dropSection === sectionIndex && sectionIndex >= 0

  // Where a tile dropped at a point (in the scene) would land in this
  // section: a position among its tiles (its length: the end), or -1 if the
  // point isn't over it. A folded or empty section takes it at the end.
  function dropIndexAt(point) {
    if (!visible || sectionIndex < 0) return -1
    var p = section.mapFromItem(null, point.x, point.y)
    if (p.x < 0 || p.x > width || p.y < -gap || p.y > height + gap) return -1
    if (collapsed || entries.length === 0) return entries.length
    var g = grid.mapFromItem(null, point.x, point.y)
    var column = Math.max(0, Math.min(owner.columns - 1, Math.floor(g.x / (owner.tileWidth + gap))))
    var row = Math.floor(g.y / (owner.tileHeight + gap))
    if (row < 0) return 0
    return Math.min(entries.length, row * owner.columns + column)
  }

  // Title: click folds (collapsible), double-click renames (a group); on
  // hover a group shows move up / down and delete.
  Item {
    width: parent.width
    height: Math.max(titleRow.implicitHeight, Style.space(20))

    Rectangle {
      // Lit while a dragged tile would drop into this (folded or empty) section.
      anchors.fill: parent
      anchors.margins: -Style.space(2)
      radius: Style.cornerRadius
      color: "transparent"
      border.width: section.dropHere && (section.collapsed || section.entries.length === 0) ? 1 : 0
      border.color: Color.accent
    }

    HoverHandler { id: headerHover }

    Row {
      id: titleRow
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Text {
        visible: section.collapsible
        anchors.verticalCenter: parent.verticalCenter
        text: section.collapsed ? "\u25b8" : "\u25be"
        color: Color.menu.text
        opacity: 0.5
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        id: titleText
        visible: !section.renaming
        anchors.verticalCenter: parent.verticalCenter
        text: section.title + (section.collapsed && section.entries.length ? "  (" + section.entries.length + ")" : "")
        textFormat: Text.PlainText
        color: Color.menu.text
        opacity: titleMouse.containsMouse ? 0.85 : 0.5
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall

        MouseArea {
          id: titleMouse
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          enabled: section.collapsible
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: clickDelay.restart()
          onDoubleClicked: {
            clickDelay.stop()
            if (section.editable) section.owner.renaming = section.sectionIndex
          }
          // A single click folds, once it's clearly not a double-click.
          Timer {
            id: clickDelay
            interval: 220
            onTriggered: section.owner.toggleCollapsed(section.sectionIndex)
          }
        }
      }

      TextInput {
        id: nameInput
        visible: section.renaming
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(200)
        text: section.title
        color: Color.menu.text
        selectionColor: Util.alpha(Color.accent, 0.4)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        onVisibleChanged: if (visible) { text = section.title; selectAll(); forceActiveFocus() }
        onAccepted: { section.owner.renameGroup(section.sectionIndex, text); section.owner.focusKeys() }
        Keys.onEscapePressed: { section.owner.renaming = -1; section.owner.focusKeys() }
        onActiveFocusChanged: if (!activeFocus && section.renaming) section.owner.renameGroup(section.sectionIndex, text)
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.bottom
          height: 1
          color: Color.accent
        }
      }
    }

    // A group's controls: up, down, delete (its apps go back to Pinned).
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      visible: section.editable && (headerHover.hovered || section.renaming) && section.owner.dragIndex < 0

      Repeater {
        model: [{ glyph: "\u2191", tip: "Move group up", act: "up", on: !section.isFirstGroup },
                { glyph: "\u2193", tip: "Move group down", act: "down", on: !section.isLastGroup },
                { glyph: "\u00d7", tip: "Delete group (its apps go back to Pinned)", act: "delete", on: true }]
        Rectangle {
          required property var modelData
          visible: modelData.on
          width: Style.space(20)
          height: width
          radius: Math.min(Style.cornerRadius, width / 2)
          color: ctlMouse.containsMouse ? Color.accent : Util.alpha(Color.menu.text, 0.08)
          border.width: 1
          border.color: Util.alpha(Color.menu.text, 0.25)
          Text {
            anchors.centerIn: parent
            text: parent.modelData.glyph
            color: ctlMouse.containsMouse ? Color.background : Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }
          MouseArea {
            id: ctlMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: section.owner.hoverDetail = parent.modelData.tip
            onExited: section.owner.hoverDetail = ""
            onClicked: {
              section.owner.hoverDetail = ""
              var a = parent.modelData.act
              if (a === "up") section.owner.moveGroup(section.sectionIndex, -1)
              else if (a === "down") section.owner.moveGroup(section.sectionIndex, 1)
              else section.owner.deleteGroup(section.sectionIndex)
            }
          }
        }
      }
    }
  }

  Text {
    visible: !section.collapsed && section.entries.length === 0 && section.empty !== ""
    text: section.empty
    color: Color.menu.text
    opacity: 0.4
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
  }

  Grid {
    id: grid
    visible: !section.collapsed
    columns: section.owner.columns
    columnSpacing: section.gap
    rowSpacing: section.gap

    Repeater {
      model: section.entries

      Rectangle {
        id: tile
        required property var modelData
        required property int index
        readonly property int flatIndex: section.offset + index
        readonly property bool current: section.owner.selected === flatIndex
        readonly property bool pinned: section.owner.isPinned(modelData)
        readonly property bool running: section.owner.opened && section.owner.windowsOf(modelData).length > 0
        readonly property bool dragging: section.owner.dragIndex === index && section.owner.dragSection === section.sectionIndex
          && section.sectionIndex !== -1
        readonly property bool dropTarget: section.dropHere && section.owner.dropIndex === index && !dragging

        width: section.owner.tileWidth
        height: section.owner.tileHeight
        radius: Style.cornerRadius
        color: current && section.owner.dragIndex < 0 ? Color.menu.selectedBackground : "transparent"
        border.width: dropTarget ? 2 : (current ? 1 : 0)
        border.color: dropTarget ? Color.accent : Util.alpha(Color.accent, 0.5)
        opacity: dragging ? 0.35 : shown
        // Tiles fade and settle in one after another as the menu opens.
        property real shown: 0
        property real settle: 6
        transform: Translate { y: tile.settle }

        Component.onCompleted: tileIn.start()
        SequentialAnimation {
          id: tileIn
          PauseAnimation { duration: Math.min(tile.flatIndex, 18) * 14 }
          ParallelAnimation {
            NumberAnimation { target: tile; property: "shown"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: tile; property: "settle"; from: 6; to: 0; duration: 200; easing.type: Easing.OutCubic }
          }
        }

        Behavior on color { ColorAnimation { duration: section.owner.taskbar.motionFast } }

        Column {
          anchors.centerIn: parent
          width: parent.width - Style.space(8)
          spacing: Style.space(6)

          Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: section.owner.iconSize
            height: section.owner.iconSize
            sourceSize.width: Math.round(section.owner.iconSize * Screen.devicePixelRatio)
            sourceSize.height: Math.round(section.owner.iconSize * Screen.devicePixelRatio)
            source: section.owner.library && !tile.modelData.folder ? section.owner.tileIcon(tile.modelData) : ""
            smooth: true
            asynchronous: true
            // A folder: its project's (or git's, or a folder's) icon.
            Text {
              anchors.centerIn: parent
              visible: !!tile.modelData.folder
              text: tile.modelData.folder ? tile.modelData.glyph : ""
              color: tile.current ? Color.menu.selectedText : Color.menu.text
              opacity: tile.modelData.missing ? 0.35 : 0.9
              font.family: Style.font.menuFamily
              font.pixelSize: section.owner.iconSize * 0.78
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            // A dot under apps that are open, like the taskbar's.
            Rectangle {
              visible: tile.running
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.bottom
              anchors.topMargin: Style.space(3)
              width: Style.space(4)
              height: width
              radius: width / 2
              color: Color.accent
            }
            text: section.owner.entryName(tile.modelData)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: tile.current ? Color.menu.selectedText : Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        MouseArea {
          id: tileMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: section.owner.dragIndex >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor
          onEntered: {
            if (section.owner.dragIndex < 0) section.owner.selected = tile.flatIndex
            detailDelay.restart()
          }
          onExited: {
            detailDelay.stop()
            section.owner.hoverDetail = ""
          }
          onClicked: function(event) {
            if (event.button === Qt.RightButton) section.owner.openTileMenu(tile.modelData, tileMouse.mapToItem(null, event.x, event.y))
            else if (tile.modelData.folder)
              section.owner.openFolderRow(tile.modelData, (event.modifiers & Qt.ControlModifier) ? "ctrl"
                                          : (event.modifiers & Qt.ShiftModifier) ? "shift" : "enter")
            else section.owner.launch(tile.modelData, (event.modifiers & Qt.ShiftModifier) !== 0)
          }
        }

        // After a moment's rest: what the app is, in the hint line.
        Timer {
          id: detailDelay
          interval: 500
          onTriggered: {
            var e = tile.modelData
            var name = section.owner.entryName(e)
            var about = e.folder ? (e.missing ? "gone: " : "") + e.path : String(e.comment || e.genericName || "")
            section.owner.hoverDetail = about ? name + "  —  " + about : ""
          }
        }

        // Drag a tile to rearrange, or into another section (takes over from
        // the click once it moves).
        DragHandler {
          enabled: section.reorderable || section.draggable
          target: null
          acceptedButtons: Qt.LeftButton
          onActiveChanged: {
            if (active) {
              section.owner.dragSection = section.sectionIndex
              section.owner.dragIndex = tile.index
              section.owner.dragPoint = centroid.scenePosition
              section.owner.updateDrop(centroid.scenePosition)
            } else {
              section.owner.endDrag()
            }
          }
          onCentroidChanged: {
            if (!active) return
            section.owner.dragPoint = centroid.scenePosition
            section.owner.updateDrop(centroid.scenePosition)
          }
        }

        // Take it out of this grid (Frequent), in the other corner.
        Rectangle {
          id: removeButton
          readonly property bool shown: section.removable && (tileMouse.containsMouse || removeMouse.containsMouse || pinMouse.containsMouse || tile.current)
            && section.owner.dragIndex < 0
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.margins: Style.space(4)
          width: Style.space(20)
          height: width
          radius: Math.min(Style.cornerRadius, width / 2)
          color: removeMouse.containsMouse ? Color.accent : Util.alpha(Color.menu.text, 0.08)
          border.width: 1
          border.color: Util.alpha(Color.menu.text, 0.25)
          opacity: shown ? 1 : 0
          visible: section.removable

          Behavior on opacity { NumberAnimation { duration: section.owner.taskbar.motionFast } }

          Text {
            anchors.centerIn: parent
            text: "×"
            color: removeMouse.containsMouse ? Color.background : Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: removeMouse
            anchors.fill: parent
            enabled: removeButton.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: section.owner.hoverDetail = "Remove from Frequent (Delete) · still in search"
            onExited: section.owner.hoverDetail = ""
            onClicked: section.owner.hideFrequent(tile.modelData)
          }
        }

        // Pin (+) or unpin (−), in the corner while hovered or selected.
        Rectangle {
          id: pinButton
          readonly property bool shown: (tileMouse.containsMouse || pinMouse.containsMouse || (section.removable && removeMouse.containsMouse) || tile.current)
            && section.owner.dragIndex < 0
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: Style.space(4)
          width: Style.space(20)
          height: width
          radius: Math.min(Style.cornerRadius, width / 2)
          color: pinMouse.containsMouse ? Color.accent : Util.alpha(Color.menu.text, 0.08)
          border.width: 1
          border.color: Util.alpha(Color.menu.text, 0.25)
          opacity: shown ? 1 : 0

          Behavior on opacity { NumberAnimation { duration: section.owner.taskbar.motionFast } }

          Text {
            anchors.centerIn: parent
            text: tile.pinned ? "−" : "+"
            color: pinMouse.containsMouse ? Color.background : Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: pinMouse
            anchors.fill: parent
            enabled: pinButton.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: section.owner.togglePin(tile.modelData)
          }
        }
      }
    }
  }
}
