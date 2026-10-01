import QtQuick
import qs.Commons
import "../../plugins/line-icons/lib/LineIcons.js" as TaskbarIcons

// A label and a row of pick-one chips (wrapping), as in "Send to [New session]
// [an open session]" or "Effort [low] … [max]". Used by the ask bar
// (ShotActions.qml) and the ask card (AskCard.qml).
//
//   options: [{ value, label, icon? }]  (icon: a line icon's name, LineIcons.js)
//   current: the picked value    picked(value)
Flow {
  id: chips

  property string label: ""
  property var options: []
  property var current: null
  property int labelWidth: 0
  property int maxChipWidth: Style.space(200)
  property color textColor: Color.popups.text
  signal picked(var value)

  spacing: Style.space(6)

  Text {
    visible: chips.label !== ""
    width: chips.labelWidth > 0 ? chips.labelWidth : implicitWidth
    height: Style.space(24)
    verticalAlignment: Text.AlignVCenter
    text: chips.label
    color: chips.textColor
    opacity: 0.5
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: chips.options
    Rectangle {
      id: chip
      required property var modelData
      readonly property bool selected: chips.current === modelData.value
      readonly property bool hasIcon: !!modelData.icon
      width: Math.min(chips.maxChipWidth, chipContent.implicitWidth + Style.space(16))
      height: Style.space(24)
      radius: Style.cornerRadius
      color: selected ? Util.alpha(Color.accent, 0.18) : (chipMouse.containsMouse ? Util.alpha(chips.textColor, 0.06) : "transparent")
      border.width: 1
      border.color: selected ? Color.accent : Util.alpha(chips.textColor, 0.2)
      Behavior on color { ColorAnimation { duration: 90 } }

      Row {
        id: chipContent
        anchors.centerIn: parent
        spacing: Style.space(6)
        Image {
          visible: chip.hasIcon
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(14)
          height: width
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          source: chip.hasIcon ? TaskbarIcons.svg(chip.modelData.icon, String(chip.selected ? Color.accent : chips.textColor)) : ""
        }
        Text {
          id: chipLabel
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, chips.maxChipWidth - Style.space(16) - (chip.hasIcon ? Style.space(20) : 0))
          text: chip.modelData.label
          elide: Text.ElideRight
          color: chip.selected ? Color.accent : chips.textColor
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }
      }
      MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chips.picked(chip.modelData.value)
      }
    }
  }
}
