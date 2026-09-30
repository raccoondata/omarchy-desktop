import QtQuick
import qs.Commons

// The one status mark a taskbar entry or window card carries: an unread count
// if the title has one, otherwise a dot when the window wants you. Both take
// the theme's accent colour, like Windows' taskbar badges.
Item {
  id: badge

  property int unread: 0
  property bool attention: false
  property string fontFamily: Style.font.family
  property int size: Style.space(9)

  readonly property string mode: unread > 0 ? "count" : (attention ? "dot" : "")

  // A small pop when the unread count goes up (or a new "wants you" dot).
  property int lastUnread: unread
  onUnreadChanged: {
    if (unread > lastUnread) pop.restart()
    lastUnread = unread
  }
  onAttentionChanged: if (attention && unread === 0) pop.restart()

  SequentialAnimation {
    id: pop
    NumberAnimation { target: badge; property: "scale"; to: 1.35; duration: 110; easing.type: Easing.OutQuad }
    NumberAnimation { target: badge; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
  }
  // The theme's background or foreground, whichever stands out more on the accent.
  function luma(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
  readonly property color countText: Math.abs(luma(Color.accent) - luma(Color.background)) >= Math.abs(luma(Color.accent) - luma(Color.foreground))
    ? Color.background : Color.foreground

  visible: mode !== ""
  implicitWidth: mode === "count" ? Math.max(countPill.height, countLabel.implicitWidth + Style.space(6)) : size
  implicitHeight: mode === "count" ? countPill.height : size

  Rectangle {
    id: countPill
    visible: badge.mode === "count"
    width: badge.implicitWidth
    height: Math.round(countLabel.implicitHeight + Style.space(1))
    radius: height / 2
    color: Color.accent

    Text {
      id: countLabel
      anchors.centerIn: parent
      text: badge.unread > 99 ? "99+" : String(badge.unread)
      color: badge.countText
      font.family: badge.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - 1)
      font.bold: true
    }
  }

  Rectangle {
    visible: badge.mode === "dot"
    anchors.centerIn: parent
    width: badge.size
    height: badge.size
    radius: badge.size / 2
    color: Color.accent
    border.width: 1
    border.color: Qt.darker(Color.accent, 1.5)
  }
}
