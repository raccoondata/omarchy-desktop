import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.Commons
import "../../plugins/line-icons/lib/LineIcons.js" as TaskbarIcons
import "TaskbarStatus.js" as TaskbarStatus

// One window as a card: icon, title and status on top, a live thumbnail, and
// where the window is underneath. Used by the taskbar's group picker and the
// Alt+Tab switcher, so both read the same.
Rectangle {
  id: card

  property var toplevel: null
  property string icon: "app"
  // The app's own icon (Icons > App colours), used instead when set.
  property string appIcon: ""
  // The line icon's own colour (Icons > Line icon colours), when it has one.
  property string iconColor: ""
  property int thumbWidth: Style.space(200)
  property bool selected: false
  property bool active: false
  property bool minimized: false
  property string place: ""
  property string agent: ""
  property bool attention: false
  property int unread: 0
  property bool live: true
  property bool closable: true
  property color textColor: Color.popups.text
  property string fontFamily: Style.font.family

  signal activated()
  signal closeRequested()
  // Draggable cards report the drag in their own coordinates (the taskbar's
  // picker uses it to drop a window on a workspace number).
  property bool draggable: false
  signal dragStarted()
  signal dragMoved(real x, real y)
  signal dragEnded()
  readonly property bool dragging: cardDrag.active

  readonly property bool hovered: cardMouse.containsMouse || closeMouse.containsMouse
  readonly property int pad: Style.space(6)
  readonly property string title: TaskbarStatus.cleanTitle(toplevel && toplevel.title ? toplevel.title : "Application")

  width: thumbWidth + pad * 2
  height: layout.implicitHeight + pad * 2
  radius: Style.cornerRadius
  color: Util.alpha(textColor, selected ? 0.12 : (hovered ? 0.09 : 0.04))
  border.width: selected ? 2 : 1
  border.color: selected ? Color.accent : (active ? Util.alpha(Color.accent, 0.6) : Util.alpha(textColor, 0.12))

  opacity: dragging ? 0.45 : 1

  Behavior on color { ColorAnimation { duration: 80 } }
  Behavior on opacity { NumberAnimation { duration: 80 } }

  DragHandler {
    id: cardDrag
    enabled: card.draggable
    target: null
    acceptedButtons: Qt.LeftButton
    onActiveChanged: {
      if (active) {
        card.dragStarted()
        card.dragMoved(centroid.position.x, centroid.position.y)
      } else {
        card.dragEnded()
      }
    }
    onCentroidChanged: if (active) card.dragMoved(centroid.position.x, centroid.position.y)
  }

  // Destroyed mid-drag (its popup closed): still end the drag, so the
  // taskbar doesn't keep a floating icon waiting for a drop.
  Component.onDestruction: if (cardDrag.active) card.dragEnded()

  MouseArea {
    id: cardMouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(event) {
      // Middle-click closes, like a browser tab.
      if (event.button === Qt.MiddleButton) card.closeRequested()
      else card.activated()
    }
  }

  Column {
    id: layout
    x: card.pad
    y: card.pad
    width: card.thumbWidth
    spacing: Style.space(5)

    // Icon, title, status, close.
    Item {
      width: parent.width
      height: Math.max(Style.font.iconLarge, titleText.implicitHeight)

      Image {
        id: cardIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.font.iconLarge
        height: Style.font.iconLarge
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
        source: card.appIcon || TaskbarIcons.svg(card.icon, card.iconColor || String(card.active || card.selected ? Color.accent : card.textColor))
        smooth: true
      }

      Text {
        id: titleText
        anchors.left: cardIcon.right
        anchors.leftMargin: Style.space(6)
        anchors.right: badge.visible ? badge.left : closeButton.left
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        text: card.title
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: card.active || card.selected ? Color.accent : card.textColor
        font.family: card.fontFamily
        font.pixelSize: Style.font.body
        font.italic: card.minimized
      }

      StatusBadge {
        id: badge
        anchors.right: closeButton.left
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        unread: card.unread
        attention: card.attention
        fontFamily: card.fontFamily
      }

      Rectangle {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: card.closable ? height : 0
        height: Style.font.iconLarge + Style.space(2)
        radius: Style.cornerRadius
        color: closeMouse.containsMouse ? Color.urgent : "transparent"
        opacity: card.closable && card.hovered ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 80 } }

        Text {
          anchors.centerIn: parent
          text: ""
          color: closeMouse.containsMouse ? Color.background : card.textColor
          font.family: card.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          enabled: card.closable
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: card.closeRequested()
        }
      }
    }

    // Live thumbnail, letterboxed in a 16:10 box. Until the first frame
    // arrives (or if the window can't be captured) the app icon stands in.
    Rectangle {
      id: thumbBox
      width: parent.width
      height: Math.round(width * 0.625)
      radius: Math.max(0, Style.cornerRadius - 2)
      color: Util.alpha(card.textColor, 0.05)

      Image {
        anchors.centerIn: parent
        visible: !shot.hasContent
        width: Math.round(thumbBox.height * 0.35)
        height: width
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
        source: card.appIcon || TaskbarIcons.svg(card.icon, card.iconColor || String(card.textColor))
        opacity: 0.3
        smooth: true
      }

      ScreencopyView {
        id: shot
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        captureSource: card.toplevel && card.toplevel.wayland ? card.toplevel.wayland : null
        live: card.live
        constraintSize: Qt.size(thumbBox.width, thumbBox.height)
        opacity: card.minimized ? 0.5 : 1
        layer.enabled: thumbBox.radius > 0
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: shotMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
        }
      }

      Item {
        id: shotMask
        anchors.fill: shot
        visible: false
        layer.enabled: true

        Rectangle {
          anchors.fill: parent
          radius: thumbBox.radius
        }
      }
    }

    // Where it is and what it's doing.
    Text {
      width: parent.width
      text: [card.place,
             card.agent === "working" ? "Working…" : (card.agent === "idle" && card.attention ? "Needs you" : ""),
             card.unread > 0 ? card.unread + " unread" : ""]
            .filter(function(part) { return part !== "" }).join("  ·  ")
      visible: text !== ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: card.textColor
      opacity: 0.6
      font.family: card.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
