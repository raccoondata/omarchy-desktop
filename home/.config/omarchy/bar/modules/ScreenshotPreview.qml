import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../../plugins/agent-tools/ui"

// The screenshot preview: after Print Screen when "After a screenshot" is set
// to the preview, or when the screenshot editor doesn't open. A window-like
// card in the middle of the screen, the capture flying into it:
//
//   Screenshot  2560 × 1440                                            ×
//   ┌──────────────────────────────────────────────────────────────┐
//   │                        the screenshot                        │
//   └──────────────────────────────────────────────────────────────┘
//   Ask Claude · Ask Codex · Edit in Tensaku     On your clipboard · Open folder · Done
//
// Two looks (Taskbar & Desktop > Screenshots > Ask controls, screenshotAsk):
//   panel (default)  the ask layout (AskPanel.qml, as the ask card): agents,
//                    the question box ready to type into, the screenshot under
//                    it, Send to / Effort, and Edit · Open folder · Done
//   bar              the screenshot, then a row of buttons (ShotActions.qml,
//                    shared with the editor dock)
//   button           the screenshot and an Ask button that opens the panel
// Drag the picture into any app to drop the file there. Esc, Done, × or a
// click anywhere else closes it. It has the keyboard while it's up.
Item {
  id: preview

  required property var taskbar
  property string path: ""
  property string app: ""
  property string title: ""
  property bool shown: false
  property bool landed: false
  property bool dragging: false
  property rect captureArea: Qt.rect(0, 0, 0, 0)
  // The screenshot editor, if one is installed (for "Edit in …").
  property string editorName: ""

  signal editRequested(string path, string app, string title)
  readonly property bool panelStyle: taskbar.screenshotAsk !== "bar"
  // "button": the panel opens from an Ask button in the footer.
  readonly property bool buttonStyle: taskbar.screenshotAsk === "button"
  property bool askOpen: true
  readonly property bool showPanel: panelStyle && askOpen

  Process {
    id: editorCheck
    command: [preview.taskbar.omarchyDir + "/screenshot-editor", "ready"]
    stdout: StdioCollector { onStreamFinished: preview.editorName = this.text.trim() }
  }

  function show(file, appName, windowTitle, area) {
    path = file
    app = appName || ""
    title = windowTitle || ""
    captureArea = area
    actions.reset()
    landed = false
    dragging = false
    editorCheck.running = true
    shown = true
    popIn.restart()
    if (area.width > 0) {
      taskbar.outlineCapture(area)
      // Once laid out: fly the capture into the picture's place.
      Qt.callLater(function() {
        var p = picture.mapToItem(null, 0, 0)
        var ox = panel.screen ? panel.screen.x : 0
        var oy = panel.screen ? panel.screen.y : 0
        taskbar.releaseCapture()
        taskbar.flyCapture(path, area, Qt.rect(ox + p.x, oy + p.y, picture.width, picture.height), false)
      })
    } else {
      landed = true
    }
    askOpen = !buttonStyle
    if (showPanel) askPanel.start("")
    else Qt.callLater(function() { keys.forceActiveFocus() })
  }

  function captureLanded() { landed = true }

  function hide() {
    shown = false
    actions.reset()
    taskbar.releaseCapture()
  }

  PanelWindow {
    id: panel

    screen: preview.taskbar.QsWindow.window ? preview.taskbar.QsWindow.window.screen : null
    visible: preview.shown || fade.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: preview.shown ? cardRegion : noRegion
    property Region cardRegion: Region { item: card }
    property Region noRegion: Region {}
    WlrLayershell.namespace: "omarchy-screenshot-preview"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: preview.shown && !preview.dragging ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // A click anywhere else closes it (not while dragging the picture out).
    HyprlandFocusGrab {
      active: preview.shown && !preview.dragging
      windows: [panel]
      onCleared: preview.hide()
    }

    // The picture's size: bar, the capture scaled to fit about 62% of the
    // screen; panel, the width of the card's content and at most 40% of the
    // screen's height.
    readonly property real natW: Math.max(1, sizer.implicitWidth)
    readonly property real natH: Math.max(1, sizer.implicitHeight)
    readonly property int pad: preview.panelStyle ? Style.space(14) : Style.space(12)
    readonly property real panelWidth: Math.min(Style.space(680), width - Style.space(40))
    readonly property real fit: preview.panelStyle
      ? Math.min(1, (panelWidth - pad * 2) / natW, height * 0.4 / natH)
      : Math.min(1, width * 0.62 / natW, height * 0.62 / natH)
    readonly property real picW: Math.round(natW * fit)
    readonly property real picH: Math.round(natH * fit)

    // Only for the capture's natural size.
    Image {
      id: sizer
      visible: false
      source: preview.path ? "file://" + preview.path : ""
      asynchronous: false
      cache: false
    }

    Rectangle {
      id: card
      width: preview.panelStyle ? panel.panelWidth : Math.max(panel.picW, actions.implicitWidth) + panel.pad * 2
      height: preview.panelStyle
        ? footer.y + footer.height + panel.pad
        : header.height + panel.picH + actions.implicitHeight + panel.pad * 3 + Style.space(4)
      x: Math.round((panel.width - width) / 2)
      y: Math.round((panel.height - height) / 2)
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: 2
      border.color: Color.popups.border
      opacity: preview.shown ? 1 : 0
      Behavior on opacity { NumberAnimation { id: fade; duration: 160; easing.type: Easing.OutCubic } }
      NumberAnimation { id: popIn; target: card; property: "scale"; from: 0.97; to: 1; duration: 200; easing.type: Easing.OutCubic }

      Item {
        id: keys
        focus: true
        Keys.onEscapePressed: {
          if (actions.asking !== "") actions.reset()
          else preview.hide()
        }
      }

      // Header: a window-like title and a close button.
      Item {
        id: header
        x: panel.pad
        y: Style.space(8)
        width: card.width - panel.pad * 2
        height: Style.space(22)

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)
          Text {
            id: titleText
            text: "Screenshot"
            color: Color.popups.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
          Text {
            text: Math.round(panel.natW) + " × " + Math.round(panel.natH)
            color: Color.popups.text
            opacity: 0.45
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            anchors.baseline: titleText.baseline
          }
        }
        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "×"
          color: Color.popups.text
          opacity: closeMouse.containsMouse ? 1 : 0.5
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          MouseArea {
            id: closeMouse
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: preview.hide()
          }
        }
      }

      // The screenshot; drag it into any app that takes files.
      Rectangle {
        id: picture
        // Panel: under the question, in the ask panel (which lays it out).
        parent: preview.showPanel ? askPanel.slotItem : card
        x: Math.round((parent.width - width) / 2)
        y: preview.showPanel ? 0 : header.y + header.height + Style.space(6)
        width: panel.picW
        height: panel.picH
        color: Util.alpha(Color.popups.text, 0.04)
        border.width: 1
        border.color: Util.alpha(Color.popups.text, 0.12)

        Image {
          anchors.fill: parent
          anchors.margins: 1
          source: preview.path ? "file://" + preview.path : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          sourceSize.width: Math.round(panel.picW * 2)
          opacity: preview.landed ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        // Hover: how to use it.
        Rectangle {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.margins: Style.space(8)
          width: dragHint.implicitWidth + Style.space(14)
          height: dragHint.implicitHeight + Style.space(8)
          radius: Style.cornerRadius
          color: Util.alpha(Color.popups.background, 0.85)
          border.width: 1
          border.color: Util.alpha(Color.popups.text, 0.15)
          opacity: pictureHover.hovered && !preview.dragging ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 140 } }
          Text {
            id: dragHint
            anchors.centerIn: parent
            text: "Drag into any app to drop the file"
            color: Color.popups.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }

        HoverHandler { id: pictureHover; cursorShape: Qt.OpenHandCursor }

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot.x: Style.space(60)
        Drag.hotSpot.y: Style.space(34)
        Drag.mimeData: ({ "text/uri-list": "file://" + preview.path + "\r\n", "text/plain": preview.path })
        Drag.active: pictureDrag.active
        // Drops from layer windows always report "ignored", so don't guess:
        // leave it up; Esc or a click away closes it.
        Drag.onDragFinished: preview.dragging = false
        DragHandler {
          id: pictureDrag
          target: null
          onActiveChanged: if (active) {
            preview.dragging = true
            picture.grabToImage(function(r) { picture.Drag.imageSource = r.url }, Qt.size(Style.space(120), Style.space(68)))
          }
        }
      }

      // Panel: the ask layout, the picture in its slot.
      AskPanel {
        id: askPanel
        visible: preview.showPanel
        x: panel.pad
        y: header.y + header.height + Style.space(10)
        width: card.width - panel.pad * 2
        mode: "image"
        path: preview.path
        app: preview.app
        title: preview.title
        showClose: false
        minQuestionHeight: Style.space(84)
        onSent: preview.hide()
        onCloseRequested: preview.hide()
      }

      // Panel: the other things to do with it.
      Item {
        id: footer
        visible: preview.panelStyle
        x: panel.pad
        y: preview.showPanel ? askPanel.y + askPanel.height + Style.space(12) : picture.y + picture.height + Style.space(12)
        width: card.width - panel.pad * 2
        height: visible ? footerRow.implicitHeight : 0

        Row {
          id: footerRow
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          // "button" style: the ask panel opens from here.
          Button {
            visible: !preview.askOpen
            text: "Ask"
            iconText: "󰚩"
            foreground: Color.accent
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onClicked: {
              preview.askOpen = true
              askPanel.start("")
            }
          }
          Button {
            visible: preview.editorName !== ""
            text: "Edit in " + preview.editorName
            iconText: ""
            foreground: Color.popups.text
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onClicked: {
              var p = preview.path, a = preview.app, t = preview.title
              preview.hide()
              preview.editRequested(p, a, t)
            }
          }
          Button {
            text: "Open folder"
            foreground: Color.popups.text
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onClicked: Util.execArgv(["nautilus", "--select", preview.path])
          }
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "On your clipboard"
            color: Color.popups.text
            opacity: 0.45
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
          Button {
            text: "Done"
            foreground: Color.popups.text
            fontFamily: Style.font.menuFamily
            fontSize: Style.font.bodySmall
            onClicked: preview.hide()
          }
        }
      }

      ShotActions {
        id: actions
        visible: !preview.panelStyle
        x: panel.pad
        y: picture.y + picture.height + panel.pad
        width: card.width - panel.pad * 2
        taskbar: preview.taskbar
        path: preview.path
        app: preview.app
        title: preview.title
        editLabel: preview.editorName ? "Edit in " + preview.editorName : ""
        showFolder: true
        status: "On your clipboard"
        onDone: preview.hide()
        onSent: preview.hide()
        onEdit: {
          var p = preview.path, a = preview.app, t = preview.title
          preview.hide()
          preview.editRequested(p, a, t)
        }
      }
    }
  }
}
