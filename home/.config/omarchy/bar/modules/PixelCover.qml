import QtQuick
import qs.Commons

// A grid of square "pixels" laid over something (a taskbar icon), shown or
// hidden in random order as `progress` goes 0 -> 1, with the pixels right at
// the changing edge lit in the accent for a moment. Used to assemble a new
// taskbar entry out of pixels and to dissolve a closed one, in the same pixel
// language as the audio equalizer.
//
//   covering: false   progress 0 = fully covered, 1 = fully revealed
//   covering: true    progress 0 = fully revealed, 1 = fully covered
Item {
  id: cover

  property int cell: 3
  property real progress: 0
  property bool covering: false
  property color coverColor: Color.bar.background
  property color edgeColor: Color.accent

  readonly property int columns: Math.ceil(width / cell)
  readonly property int rows: Math.ceil(height / cell)
  // One random threshold per pixel, drawn once.
  property var thresholds: []

  function reseed() {
    var list = []
    for (var i = 0; i < columns * rows; i++) list.push(Math.random())
    thresholds = list
  }

  Component.onCompleted: reseed()
  onColumnsChanged: reseed()
  onRowsChanged: reseed()

  Repeater {
    model: cover.columns * cover.rows

    Rectangle {
      required property int index
      readonly property real threshold: cover.thresholds[index] === undefined ? 0.5 : cover.thresholds[index]
      // How far past this pixel's moment the sweep is (negative = not yet).
      readonly property real past: cover.progress - threshold
      readonly property bool covered: cover.covering ? past >= 0 : past < 0
      readonly property bool atEdge: Math.abs(past) < 0.1

      x: (index % cover.columns) * cover.cell
      y: Math.floor(index / cover.columns) * cover.cell
      width: cover.cell
      height: cover.cell
      visible: covered || atEdge
      color: atEdge ? cover.edgeColor : cover.coverColor
      opacity: atEdge ? 0.7 : 1
    }
  }
}
