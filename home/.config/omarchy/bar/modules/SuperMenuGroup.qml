import QtQuick
import qs.Commons

// One block on the super menu's grid (SuperMenu.qml): Pinned or a group, at
// its own place and size in tiles (layout {x, y, w, h}). Its title bar drags
// it somewhere else, the corner handle resizes it, ⋯ has sizes, rename and
// delete; double-click the title to rename. Apps that don't fit end in a
// "+N" tile that lists the rest. While a tile is dragged, its empty cells
// show as drop spots.
Item {
  id: block
  required property var owner
  required property int sectionIndex
  property string title: ""
  property var entries: []
  property var layout: ({ x: 0, y: 0, w: 3, h: 2 })
  property int offset: 0
  property bool editable: false      // a group (not Pinned): rename, delete

  readonly property real colPitch: owner.tileWidth + owner.tileGap
  readonly property real rowPitch: owner.tileHeight + owner.bandHeight
  readonly property int capacity: layout.w * layout.h
  readonly property bool overflowing: entries.length > capacity
  readonly property var shown: overflowing ? entries.slice(0, Math.max(0, capacity - 1)) : entries
  readonly property bool renaming: owner.renaming === sectionIndex && editable
  readonly property bool tileDrag: owner.dragIndex >= 0
  readonly property bool dropHere: tileDrag && owner.dropSection === sectionIndex
  readonly property bool moving: owner.blockAction !== "" && owner.blockSection === sectionIndex

  x: layout.x * colPitch
  y: layout.y * rowPitch
  width: layout.w * colPitch - owner.tileGap
  height: layout.h * rowPitch
  opacity: moving ? 0.45 : 1

  function cellX(i) { return (i % layout.w) * colPitch }
  function cellY(i) { return owner.bandHeight + Math.floor(i / layout.w) * rowPitch }

  // Where a tile dropped at a point (in the scene) would land in this block:
  // a position among its tiles (past the shown ones: the end), or -1 if the
  // point isn't over it.
  function dropIndexAt(point) {
    var p = block.mapFromItem(null, point.x, point.y)
    if (p.x < 0 || p.x > width || p.y < 0 || p.y > height) return -1
    var c = Math.max(0, Math.min(layout.w - 1, Math.floor(p.x / colPitch)))
    var r = Math.max(0, Math.floor((p.y - owner.bandHeight) / rowPitch))
    var at = r * layout.w + c
    return at < shown.length ? at : entries.length
  }

  HoverHandler { id: blockHover }

  // A faint frame while hovered, the accent while a tile would drop in.
  Rectangle {
    anchors.fill: parent
    anchors.margins: -Style.space(3)
    radius: Style.cornerRadius
    color: "transparent"
    border.width: block.dropHere || (blockHover.hovered && !block.tileDrag) ? 1 : 0
    border.color: block.dropHere ? Color.accent : Util.alpha(Color.menu.text, 0.14)
  }

  // Title bar: drag it to move the block.
  Item {
    id: header
    width: parent.width
    height: block.owner.bandHeight

    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.ClosedHandCursor
      onActiveChanged: {
        if (active) block.owner.startBlock(block.sectionIndex, "move", centroid.scenePosition)
        else block.owner.endBlock()
      }
      onCentroidChanged: if (active) block.owner.updateBlock(centroid.scenePosition)
    }

    Text {
      id: titleText
      visible: !block.renaming
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width - controls.width - Style.space(8))
      text: block.title
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Color.menu.text
      opacity: titleMouse.containsMouse ? 0.85 : 0.5
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall

      MouseArea {
        id: titleMouse
        anchors.fill: parent
        anchors.margins: -Style.space(3)
        hoverEnabled: true
        cursorShape: Qt.OpenHandCursor
        onDoubleClicked: if (block.editable) block.owner.renaming = block.sectionIndex
      }
    }

    TextInput {
      visible: block.renaming
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(Style.space(80), parent.width - controls.width - Style.space(8))
      text: block.title
      color: Color.menu.text
      selectionColor: Util.alpha(Color.accent, 0.4)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      onVisibleChanged: if (visible) { text = block.title; selectAll(); forceActiveFocus() }
      onAccepted: { block.owner.renameGroup(block.sectionIndex, text); block.owner.focusKeys() }
      Keys.onEscapePressed: { block.owner.renaming = -1; block.owner.focusKeys() }
      onActiveFocusChanged: if (!activeFocus && block.renaming) block.owner.renameGroup(block.sectionIndex, text)
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.bottom
        height: 1
        color: Color.accent
      }
    }

    // Its size, and ⋯ (sizes, rename, delete), while hovered.
    Row {
      id: controls
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
      opacity: (blockHover.hovered || block.renaming) && !block.tileDrag && block.owner.blockAction === "" ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: block.owner.taskbar.motionFast } }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: block.layout.w + "×" + block.layout.h
        color: Color.menu.text
        opacity: 0.4
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
      Rectangle {
        width: Style.space(20)
        height: Style.space(18)
        radius: Style.cornerRadius
        color: moreMouse.containsMouse ? Color.accent : Util.alpha(Color.menu.text, 0.08)
        Text {
          anchors.centerIn: parent
          text: "⋯"
          color: moreMouse.containsMouse ? Color.background : Color.menu.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
        }
        MouseArea {
          id: moreMouse
          anchors.fill: parent
          enabled: controls.opacity > 0
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) { block.owner.openBlockMenu(block.sectionIndex, moreMouse.mapToItem(null, mouse.x, mouse.y)) }
        }
      }
    }
  }

  // The tiles, in the block's columns.
  Repeater {
    model: block.shown
    SuperMenuTile {
      owner: block.owner
      flatIndex: block.offset + index
      sectionIndex: block.sectionIndex
      draggable: true
      x: block.cellX(index)
      y: block.cellY(index)
    }
  }

  // More than fit: the last cell lists the rest.
  Rectangle {
    visible: block.overflowing
    x: block.cellX(block.capacity - 1)
    y: block.cellY(block.capacity - 1)
    width: block.owner.tileWidth
    height: block.owner.tileHeight
    radius: Style.cornerRadius
    color: moreTilesMouse.containsMouse ? Util.alpha(Color.menu.text, 0.06) : "transparent"
    border.width: 1
    border.color: Util.alpha(Color.menu.text, 0.14)
    Text {
      anchors.centerIn: parent
      text: "+" + (block.entries.length - block.shown.length)
      color: Color.menu.text
      opacity: 0.7
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.heading
    }
    MouseArea {
      id: moreTilesMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) { block.owner.openOverflow(block.sectionIndex, moreTilesMouse.mapToItem(null, mouse.x, mouse.y)) }
    }
  }

  // Empty cells: drop spots while a tile is dragged, a hint when it's empty.
  Repeater {
    model: block.tileDrag || block.entries.length === 0 ? Math.max(0, block.capacity - block.shown.length - (block.overflowing ? 1 : 0)) : 0
    Rectangle {
      required property int index
      readonly property bool target: block.dropHere && block.owner.dropIndex === block.entries.length && index === 0
      x: block.cellX(block.shown.length + index)
      y: block.cellY(block.shown.length + index)
      width: block.owner.tileWidth
      height: block.owner.tileHeight
      radius: Style.cornerRadius
      color: target ? Util.alpha(Color.accent, 0.12) : "transparent"
      border.width: target ? 2 : 1
      border.color: target ? Color.accent : Util.alpha(Color.menu.text, 0.1)
    }
  }
  Text {
    visible: block.entries.length === 0 && !block.tileDrag
    x: Style.space(10)
    y: block.owner.bandHeight + Style.space(10)
    width: Math.min(block.width, block.owner.tileWidth * 2) - Style.space(20)
    wrapMode: Text.WordWrap
    text: "Drag apps here, or right-click one > Move to"
    color: Color.menu.text
    opacity: 0.4
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }

  // Resize from the bottom-right corner.
  Item {
    width: Style.space(16)
    height: Style.space(16)
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: -Style.space(4)
    anchors.bottomMargin: -Style.space(4)
    opacity: blockHover.hovered && !block.tileDrag ? 1 : 0
    HoverHandler { cursorShape: Qt.SizeFDiagCursor }
    Text {
      anchors.centerIn: parent
      text: "◢"
      color: Color.menu.text
      opacity: 0.45
      font.pixelSize: Style.font.bodySmall
    }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: {
        if (active) block.owner.startBlock(block.sectionIndex, "resize", centroid.scenePosition)
        else block.owner.endBlock()
      }
      onCentroidChanged: if (active) block.owner.updateBlock(centroid.scenePosition)
    }
  }
}
