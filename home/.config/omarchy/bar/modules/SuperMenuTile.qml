import QtQuick
import qs.Commons

// One app (or pinned folder) tile in the super menu (SuperMenu.qml): its icon
// and name, a dot if it's open, + / − to pin, × to take it out of Frequent
// (removable), right-click for its menu, and dragging (draggable) to another
// spot. Used by SuperMenuSection (results, Frequent) and SuperMenuGroup
// (Pinned and the groups).
Rectangle {
  id: tile
  required property var owner
  required property var modelData
  required property int index        // in its section (or block)
  required property int flatIndex    // among every tile shown (selection)
  property int sectionIndex: -1      // the owner's section (-2: Frequent, -1: results)
  property bool removable: false     // an × to take it out (Frequent)
  property bool draggable: false     // can be dragged to another spot
  readonly property bool current: tile.owner.selected === flatIndex
  readonly property bool pinned: tile.owner.isPinned(modelData)
  readonly property bool running: tile.owner.opened && tile.owner.windowsOf(modelData).length > 0
  readonly property bool dragging: tile.owner.dragIndex === index && tile.owner.dragSection === sectionIndex
    && sectionIndex !== -1
  readonly property bool dropTarget: tile.owner.dragIndex >= 0 && sectionIndex >= 0 && tile.owner.dropSection === sectionIndex
    && tile.owner.dropIndex === index && !dragging

  width: tile.owner.tileWidth
  height: tile.owner.tileHeight
  radius: Style.cornerRadius
  color: current && tile.owner.dragIndex < 0 ? Color.menu.selectedBackground : "transparent"
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

  Behavior on color { ColorAnimation { duration: tile.owner.taskbar.motionFast } }

  Column {
    anchors.centerIn: parent
    width: parent.width - Style.space(8)
    spacing: Style.space(6)

    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      width: tile.owner.iconSize
      height: tile.owner.iconSize
      sourceSize.width: Math.round(tile.owner.iconSize * Screen.devicePixelRatio)
      sourceSize.height: Math.round(tile.owner.iconSize * Screen.devicePixelRatio)
      source: tile.owner.library && !tile.modelData.folder ? tile.owner.tileIcon(tile.modelData) : ""
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
        font.pixelSize: tile.owner.iconSize * 0.78
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
      text: tile.owner.entryName(tile.modelData)
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
    cursorShape: tile.owner.dragIndex >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    onEntered: {
      if (tile.owner.dragIndex < 0) tile.owner.selected = tile.flatIndex
      detailDelay.restart()
    }
    onExited: {
      detailDelay.stop()
      tile.owner.hoverDetail = ""
    }
    onClicked: function(event) {
      if (event.button === Qt.RightButton) tile.owner.openTileMenu(tile.modelData, tileMouse.mapToItem(null, event.x, event.y))
      else if (tile.modelData.folder)
        tile.owner.openFolderRow(tile.modelData, (event.modifiers & Qt.ControlModifier) ? "ctrl"
                                    : (event.modifiers & Qt.ShiftModifier) ? "shift" : "enter")
      else tile.owner.launch(tile.modelData, (event.modifiers & Qt.ShiftModifier) !== 0)
    }
  }

  // After a moment's rest: what the app is, in the hint line.
  Timer {
    id: detailDelay
    interval: 500
    onTriggered: {
      var e = tile.modelData
      var name = tile.owner.entryName(e)
      var about = e.folder ? (e.missing ? "gone: " : "") + e.path : String(e.comment || e.genericName || "")
      tile.owner.hoverDetail = about ? name + "  —  " + about : ""
    }
  }

  // Drag a tile to rearrange, or into another section (takes over from
  // the click once it moves).
  DragHandler {
    enabled: tile.draggable
    target: null
    acceptedButtons: Qt.LeftButton
    onActiveChanged: {
      if (active) {
        tile.owner.dragSection = tile.sectionIndex
        tile.owner.dragIndex = tile.index
        tile.owner.dragPoint = centroid.scenePosition
        tile.owner.updateDrop(centroid.scenePosition)
      } else {
        tile.owner.endDrag()
      }
    }
    onCentroidChanged: {
      if (!active) return
      tile.owner.dragPoint = centroid.scenePosition
      tile.owner.updateDrop(centroid.scenePosition)
    }
    onCanceled: tile.owner.cancelDrag()
  }

  // Take it out of this grid (Frequent), in the other corner.
  Rectangle {
    id: removeButton
    readonly property bool shown: tile.removable && (tileMouse.containsMouse || removeMouse.containsMouse || pinMouse.containsMouse || tile.current)
      && tile.owner.dragIndex < 0
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
    visible: tile.removable

    Behavior on opacity { NumberAnimation { duration: tile.owner.taskbar.motionFast } }

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
      onEntered: tile.owner.hoverDetail = "Remove from Frequent (Delete) · still in search"
      onExited: tile.owner.hoverDetail = ""
      onClicked: tile.owner.hideFrequent(tile.modelData)
    }
  }

  // Pin (+) or unpin (−), in the corner while hovered or selected.
  Rectangle {
    id: pinButton
    readonly property bool shown: (tileMouse.containsMouse || pinMouse.containsMouse || (tile.removable && removeMouse.containsMouse) || tile.current)
      && tile.owner.dragIndex < 0
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

    Behavior on opacity { NumberAnimation { duration: tile.owner.taskbar.motionFast } }

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
      onClicked: tile.owner.togglePin(tile.modelData)
    }
  }
}
