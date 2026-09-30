import QtQuick
import qs.Commons

// One titled grid of app tiles in the super menu (SuperMenu.qml). In the
// pinned grid (reorderable) tiles can be dragged to a new spot; every tile has
// a +/- button (on hover or when selected) to pin or unpin it.
Column {
  id: section
  required property var owner
  property string title: ""
  property var entries: []
  property int offset: 0
  property string empty: ""
  property bool reorderable: false

  width: owner.gridWidth
  spacing: Style.space(6)

  readonly property int gap: Style.space(6)

  // The pinned position under a point in this section's grid, or -1.
  function indexAt(point) {
    var p = grid.mapFromItem(null, point.x, point.y)
    var column = Math.floor(p.x / (owner.tileWidth + gap))
    var row = Math.floor(p.y / (owner.tileHeight + gap))
    if (column < 0 || column >= owner.columns || row < 0) return -1
    return Math.min(entries.length - 1, row * owner.columns + column)
  }

  Text {
    text: section.title
    color: Color.menu.text
    opacity: 0.5
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
  }

  Text {
    visible: section.entries.length === 0 && section.empty !== ""
    text: section.empty
    color: Color.menu.text
    opacity: 0.4
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
  }

  Grid {
    id: grid
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
        readonly property bool dragging: section.reorderable && section.owner.dragIndex === index
        readonly property bool dropTarget: section.reorderable && section.owner.dragIndex >= 0
          && section.owner.dropIndex === index && section.owner.dragIndex !== index

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
            source: section.owner.library ? section.owner.tileIcon(tile.modelData) : ""
            smooth: true
            asynchronous: true
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: section.owner.library ? section.owner.library.entryName(tile.modelData) : tile.modelData.name
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
          onEntered: if (section.owner.dragIndex < 0) section.owner.selected = tile.flatIndex
          onClicked: function(event) {
            if (event.button === Qt.RightButton) section.owner.togglePin(tile.modelData)
            else section.owner.launch(tile.modelData, (event.modifiers & Qt.ShiftModifier) !== 0)
          }
        }

        // Drag a pinned tile to rearrange (takes over from the click once it moves).
        DragHandler {
          enabled: section.reorderable
          target: null
          acceptedButtons: Qt.LeftButton
          onActiveChanged: {
            if (active) {
              section.owner.dragIndex = tile.index
              section.owner.dropIndex = tile.index
              section.owner.dragPoint = centroid.scenePosition
            } else {
              section.owner.endDrag()
            }
          }
          onCentroidChanged: {
            if (!active) return
            section.owner.dragPoint = centroid.scenePosition
            var at = section.indexAt(centroid.scenePosition)
            if (at >= 0) section.owner.dropIndex = at
          }
        }

        // Pin (+) or unpin (−), in the corner while hovered or selected.
        Rectangle {
          id: pinButton
          readonly property bool shown: (tileMouse.containsMouse || pinMouse.containsMouse || tile.current)
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
