import QtQuick
import qs.Commons

// A wrapping row of checkboxes, for switching several things on or off, as
// in Taskbar & Desktop > Windows > Bring together (TaskbarSettings.qml).
//
//   options: [{ value, label }]   checked: [value, ...]   toggled(value)
Flow {
  id: list

  property var options: []
  property var checked: []
  property color textColor: Color.menu.text
  signal toggled(var value)

  spacing: Style.space(16)

  Repeater {
    model: list.options
    Item {
      id: item
      required property var modelData
      readonly property bool on: list.checked.indexOf(modelData.value) !== -1
      width: row.implicitWidth
      height: Style.space(26)

      Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(16)
          height: width
          radius: Math.max(2, Style.cornerRadius / 2)
          color: item.on ? Color.accent : (mouse.containsMouse ? Util.alpha(list.textColor, 0.08) : "transparent")
          border.width: 1
          border.color: item.on ? Color.accent : Util.alpha(list.textColor, mouse.containsMouse ? 0.6 : 0.35)
          Behavior on color { ColorAnimation { duration: 90 } }
          Text {
            anchors.centerIn: parent
            visible: item.on
            text: "✓"
            color: Color.menu.background
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: item.modelData.label
          color: list.textColor
          opacity: item.on ? 1 : 0.6
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: list.toggled(item.modelData.value)
      }
    }
  }
}
