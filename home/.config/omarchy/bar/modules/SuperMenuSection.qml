import QtQuick
import qs.Commons

// A titled, full-width grid of tiles in the super menu (SuperMenu.qml): the
// search results, or Frequent. (Pinned and the groups are SuperMenuGroup
// blocks, placed and sized freely.) Frequent's tiles can be dragged into a
// block, which pins them there, and have an × to take them out of Frequent.
Column {
  id: section
  required property var owner
  property string title: ""
  property var entries: []
  property int offset: 0
  property string empty: ""
  property bool removable: false
  property int sectionIndex: -1      // -2: Frequent, -1: results
  property bool draggable: false

  width: owner.gridWidth
  spacing: Style.space(6)

  readonly property int gap: Style.space(6)

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
    columns: section.owner.columns
    columnSpacing: section.gap
    rowSpacing: section.gap

    Repeater {
      model: section.entries
      SuperMenuTile {
        owner: section.owner
        flatIndex: section.offset + index
        sectionIndex: section.sectionIndex
        removable: section.removable
        draggable: section.draggable
      }
    }
  }
}
