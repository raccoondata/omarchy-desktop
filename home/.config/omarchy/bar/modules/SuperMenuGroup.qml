import QtQuick
import qs.Commons

// One block on the super menu's grid (SuperMenu.qml): Pinned or a group, at
// its place (layout {x, y, w, h}, in tiles), each tile in its own cell
// (tiles: [{entry, c, r}]; the size is what they cover). Its title bar drags it somewhere else; a group's
// ⋯ renames or deletes it, and double-clicking its title renames it.
Item {
  id: block
  required property var owner
  required property int sectionIndex
  property string title: ""
  property var entries: []
  property var tiles: []             // [{ entry, c, r }], same order as entries
  property var layout: ({ x: 0, y: 0, w: 1, h: 1 })
  property int offset: 0
  property bool editable: false      // a group (not Pinned): rename, delete
  property string shade: ""          // a soft fill in one of the theme's colours ("" none)
  property string iconStyle: ""      // its own icon style ("": the Icons setting)

  readonly property real colPitch: owner.tileWidth + owner.tileGap
  readonly property real rowPitch: owner.tileHeight + owner.bandHeight
  readonly property bool renaming: owner.renaming === sectionIndex && editable
  readonly property bool tileDrag: owner.dragIndex >= 0
  readonly property bool dropHere: tileDrag && owner.dropPlan !== null && owner.dropPlan.sec === sectionIndex
  readonly property bool moving: owner.blockAction !== "" && owner.blockSection === sectionIndex

  x: layout.x * colPitch
  y: layout.y * rowPitch
  width: layout.w * colPitch - owner.tileGap
  height: layout.h * rowPitch
  opacity: moving ? 0.45 : 1


  HoverHandler { id: blockHover }

  // Its shade: a soft fill (icons keep their own colours over it).
  Rectangle {
    visible: block.shade !== ""
    anchors.fill: parent
    // In from the edges a little, so neighbouring blocks' shades don't touch.
    anchors.leftMargin: -Style.space(1)
    anchors.rightMargin: -Style.space(1)
    anchors.topMargin: -Style.space(2)
    anchors.bottomMargin: Style.space(5)
    radius: Style.cornerRadius
    color: block.shade !== "" ? Util.alpha(block.shade, 0.22) : "transparent"
    border.width: 1
    border.color: block.shade !== "" ? Util.alpha(block.shade, 0.5) : "transparent"
  }

  // A faint frame while hovered, the accent while a tile would go in.
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
      onCanceled: block.owner.cancelDrag()
    }

    Text {
      visible: !block.renaming
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width - controls.width - Style.space(8))
      text: block.title
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: block.shade !== "" ? block.shade : Color.menu.text
      opacity: titleMouse.containsMouse ? 1 : (block.shade !== "" ? 1 : 0.5)
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

    // ⋯ (shade; a group's rename and delete too), while hovered.
    Rectangle {
      id: controls
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(20)
      height: Style.space(18)
      radius: Style.cornerRadius
      opacity: (blockHover.hovered || block.renaming) && !block.tileDrag && block.owner.blockAction === "" ? 1 : 0
      color: moreMouse.containsMouse ? Color.accent : Util.alpha(Color.menu.text, 0.08)
      Behavior on opacity { NumberAnimation { duration: block.owner.taskbar.motionFast } }
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

  // The tiles, in the block's columns.
  Repeater {
    model: block.entries
    SuperMenuTile {
      owner: block.owner
      flatIndex: block.offset + index
      sectionIndex: block.sectionIndex
      draggable: true
      iconStyle: block.iconStyle
      shadeHex: block.shade
      x: block.tiles[index] ? block.tiles[index].c * block.colPitch : 0
      y: block.tiles[index] ? block.owner.bandHeight + block.tiles[index].r * block.rowPitch : 0
    }
  }

  // An empty group (just made): a hint.
  Text {
    visible: block.entries.length === 0 && !block.tileDrag
    x: Style.space(4)
    y: block.owner.bandHeight + Style.space(6)
    width: block.owner.tileWidth - Style.space(8)
    wrapMode: Text.WordWrap
    text: "Drag apps here"
    color: Color.menu.text
    opacity: 0.4
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }
}
