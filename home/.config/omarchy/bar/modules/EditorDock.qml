import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "taskbar-icons.js" as TaskbarIcons

// After Print Screen (~/.config/omarchy/screenshot), when "After a
// screenshot" is set to the editor: the capture opens in the screenshot
// editor (~/.config/omarchy/screenshot-editor: Tensaku, or Satty, Swappy,
// ksnip, any editor that opens a file) and this bar attaches to the editor's
// window, under it (above when there's no room):
//
//   [thumbnail] · Ask Claude · Ask Codex            it's on your clipboard · Done
//
// The capture flies from where it was into the editor as it opens. The bar is
// ShotActions.qml (shared with the preview): asking sends the newest version,
// with your annotations, and closes the editor; drag the thumbnail into
// another app to drop the file there; Done closes the editor.
// The bar follows the window, tucks away while the window is being dragged,
// and only shows on the editor's workspace. If the editor doesn't open within
// a few seconds, `failed` fires and the taskbar shows its own preview
// (ScreenshotPreview.qml) instead.
Item {
  id: dock

  required property var taskbar
  readonly property string script: taskbar.omarchyDir + "/screenshot-editor"
  property string path: ""
  property string app: ""
  property string title: ""
  property rect captureArea: Qt.rect(0, 0, 0, 0)
  property bool active: false

  property string editorClass: ""
  property string editorName: "the editor"
  property var known: ({})
  property var editorWindow: null
  // The editor window, global layout coordinates.
  property rect geo: Qt.rect(0, 0, 0, 0)
  property bool onWorkspace: false
  // Bumped when the image file changes (the editor saved), to refresh the
  // thumbnail.
  property int rev: 0

  signal failed(string path, string app, string title)
  // Taskbar & Desktop > Screenshots > Ask controls: "panel" = the ask layout
  // (AskPanel.qml) docked beside the editor; "bar" = a bar under it;
  // "button" = the panel, starting folded into its Ask tab.
  readonly property bool panelStyle: taskbar.screenshotAsk !== "bar"

  // Esc folds the panel/bar into a small "Ask" tab (click it to bring it
  // back) instead of closing the editor and the screenshot; folded, Esc
  // reaches the editor again, so a second one closes it. For Esc pressed in
  // the editor, Hyprland has to catch it: while the panel/bar shows, Escape
  // is bound to omarchy_screenshot_escape (hypr/desktop/bindings.lua), which only
  // acts in the editor window and passes Esc through everywhere else.
  property bool collapsed: false
  function collapse() { collapsed = true }
  readonly property bool catchEscape: active && editorWindow !== null && !collapsed && panel.shown
  // Off: stop catching presses at once (the next Esc reaches the editor),
  // and drop the binding a moment later, once the caught key is released.
  onCatchEscapeChanged: {
    if (catchEscape) {
      escapeRelease.stop()
      Util.execArgv(["hyprctl", "eval", 'hl.unbind("ESCAPE"); omarchy_screenshot_editor = "' + addressOf(editorWindow) + '"; '
        + 'hl.bind("ESCAPE", omarchy_screenshot_escape, { description = "Screenshot editor: fold the ask panel away" }); '
        + 'hl.bind("ESCAPE", omarchy_screenshot_escape_release, { release = true })'])
    } else {
      Util.execArgv(["hyprctl", "eval", 'omarchy_screenshot_editor = ""'])
      escapeRelease.restart()
    }
  }
  Timer {
    id: escapeRelease
    interval: 800
    onTriggered: if (!dock.catchEscape) Util.execArgv(["hyprctl", "eval", 'if omarchy_screenshot_editor == "" then omarchy_screenshot_swallow = false; hl.unbind("ESCAPE") end'])
  }

  // --- which editor ------------------------------------------------------------
  Process {
    id: classProc
    command: [dock.script, "class"]
    stdout: StdioCollector { onStreamFinished: dock.editorClass = this.text.trim() }
  }
  Process {
    id: nameProc
    command: [dock.script, "name"]
    stdout: StdioCollector { onStreamFinished: dock.editorName = this.text.trim() || "the editor" }
  }
  function readEditor() {
    classProc.running = true
    nameProc.running = true
  }
  Component.onCompleted: {
    readEditor()
    // A binding left from before a shell restart.
    Util.execArgv(["hyprctl", "eval", 'omarchy_screenshot_editor = ""; hl.unbind("ESCAPE")'])
  }
  FileView {
    path: dock.taskbar.omarchyDir + "/screenshot-editor.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: dock.readEditor()
  }

  function classOf(t) {
    return t && t.lastIpcObject ? String(t.lastIpcObject.class || "") : ""
  }
  function matches(t) {
    if (!dock.editorClass) return false
    try { return new RegExp(dock.editorClass).test(classOf(t)) } catch (e) { return false }
  }
  function addressOf(t) {
    var a = String(t && t.address || "")
    return a.indexOf("0x") === 0 ? a : "0x" + a
  }

  // --- a session -----------------------------------------------------------------
  function start(file, appName, windowTitle, area) {
    path = file
    app = appName || ""
    title = windowTitle || ""
    captureArea = area
    actions.reset()
    askPanel.start("")
    collapsed = taskbar.screenshotAsk === "button"
    editorWindow = null
    // Editor windows already open (an earlier screenshot) aren't this one.
    var before = {}
    var tops = Hyprland.toplevels.values
    for (var i = 0; i < tops.length; i++) if (matches(tops[i])) before[addressOf(tops[i])] = true
    known = before
    active = true
    if (area.width > 0) taskbar.outlineCapture(area)
    Util.execArgv([script, "open", file])
    waitForEditor.restart()
    track.restart()
  }

  function end() {
    active = false
    actions.reset()
    editorWindow = null
    track.stop()
    waitForEditor.stop()
  }

  Timer {
    id: waitForEditor
    interval: 6000
    onTriggered: {
      if (dock.editorWindow) return
      dock.end()
      dock.taskbar.releaseCapture()
      dock.failed(dock.path, dock.app, dock.title)
    }
  }

  // Follow the editor window (floating windows report no event when moved
  // or resized, so ask a few times a second while a session is on).
  Timer {
    id: track
    interval: 150
    repeat: true
    onTriggered: {
      Hyprland.refreshToplevels()
      var tops = Hyprland.toplevels.values
      var win = null
      for (var i = 0; i < tops.length; i++) {
        var t = tops[i]
        if (dock.editorWindow ? t === dock.editorWindow : (dock.matches(t) && !dock.known[dock.addressOf(t)])) { win = t; break }
      }
      if (!win) {
        if (dock.editorWindow) dock.end()   // the editor closed
        return
      }
      var ipc = win.lastIpcObject || {}
      if (!ipc.at || !ipc.size) return
      var g = Qt.rect(ipc.at[0], ipc.at[1], ipc.size[0], ipc.size[1])
      if (!dock.editorWindow) {
        dock.editorWindow = win
        waitForEditor.stop()
        // The capture flies from where it was into the editor.
        dock.taskbar.releaseCapture()
        if (dock.captureArea.width > 0) dock.taskbar.flyCapture(dock.path, dock.captureArea, g, true)
      }
      if (g.x !== dock.geo.x || g.y !== dock.geo.y || g.width !== dock.geo.width || g.height !== dock.geo.height) dock.geo = g
      var ws = ipc.workspace ? ipc.workspace.id : -1
      dock.onWorkspace = Hyprland.focusedWorkspace ? ws === Hyprland.focusedWorkspace.id : true
    }
  }

  FileView {
    path: dock.active ? dock.path : ""
    watchChanges: true
    printErrors: false
    onFileChanged: dock.rev++
  }

  // --- actions -------------------------------------------------------------------
  function done() {
    if (editorWindow) Util.execArgv([taskbar.omarchyDir + "/taskbar-action", "close", addressOf(editorWindow)])
    end()
  }

  // --- the bar -------------------------------------------------------------------
  // A full-screen, click-through layer with only the bar taking input, so
  // following the window is just moving an item (no layer resizes).
  PanelWindow {
    id: panel

    screen: dock.taskbar.QsWindow.window ? dock.taskbar.QsWindow.window.screen : null
    visible: dock.active && dock.editorWindow !== null || fade.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: shown ? cardRegion : noRegion
    property Region cardRegion: Region { item: card }
    property Region noRegion: Region {}
    WlrLayershell.namespace: "omarchy-editor-dock"
    WlrLayershell.layer: WlrLayer.Top
    // Panel: the question box can take the keyboard (click it). Bar: only
    // while asking. Folded: never, so the keyboard is the editor's again
    // (else the next Esc lands in the hidden question box).
    WlrLayershell.keyboardFocus: !dock.collapsed && (dock.panelStyle ? shown : actions.asking !== "") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool shown: dock.active && dock.editorWindow !== null && dock.onWorkspace && !dock.taskbar.windowDragging
    readonly property real ox: screen ? screen.x : 0
    readonly property real oy: screen ? screen.y : 0
    readonly property real gap: Style.space(6)
    // The window, screen-local.
    readonly property real wx: dock.geo.x - ox
    readonly property real wy: dock.geo.y - oy
    readonly property real ww: dock.geo.width
    readonly property real wh: dock.geo.height
    readonly property real screenH: height
    readonly property real topLimit: Style.space(48)
    // Under the window; above it if there's no room; inside its bottom edge
    // if neither fits.
    readonly property string side: {
      if (dock.panelStyle) {
        if (wx + ww + gap + panelWidth <= width - Style.gapsOut) return "right"
        if (wx - gap - panelWidth >= Style.gapsOut) return "left"
        return "inside-right"
      }
      if (wy + wh + gap + card.height <= screenH - Style.gapsOut) return "below"
      if (wy - gap - card.height >= topLimit) return "above"
      return "inside"
    }
    readonly property int panelWidth: Style.space(400)
    readonly property int pad: Style.space(14)

    Rectangle {
      id: card
      // From the rows' own sizes only: nothing inside may size itself from
      // the card (that fed back into the card's width and hung the shell).
      width: dock.collapsed ? tab.implicitWidth + Style.space(20)
        : dock.panelStyle ? panel.panelWidth : Math.max(panel.ww, actions.implicitWidth + Style.space(16))
      height: dock.collapsed ? tab.implicitHeight + Style.space(12)
        : dock.panelStyle
        ? askPanel.implicitHeight + footer.height + panel.pad * 2 + Style.space(12)
        : actions.implicitHeight + Style.space(12)
      x: panel.side === "right" ? panel.wx + panel.ww + panel.gap
        : panel.side === "left" ? panel.wx - panel.gap - width
        : panel.side === "inside-right" ? panel.wx + panel.ww - width - Style.space(10)
        : Math.max(Style.gapsOut, Math.min(panel.width - width - Style.gapsOut, panel.wx + (panel.ww - width) / 2))
      // Folded over the editor (no room beside it): its bottom-right corner,
      // clear of the editor's toolbar.
      y: dock.panelStyle && dock.collapsed && panel.side === "inside-right" ? panel.wy + panel.wh - height - Style.space(10)
        : dock.panelStyle ? Math.max(panel.topLimit, Math.min(panel.screenH - height - Style.gapsOut, panel.wy))
        : panel.side === "below" ? panel.wy + panel.wh + panel.gap
        : panel.side === "above" ? panel.wy - panel.gap - height
        : panel.wy + panel.wh - height - Style.space(10)
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: 1
      border.color: Color.popups.border
      opacity: panel.shown ? 1 : 0
      // Slides out from under (or beside) the window as it appears.
      transform: Translate {
        x: panel.shown || !dock.panelStyle ? 0 : (panel.side === "left" ? Style.space(8) : -Style.space(8))
        y: panel.shown || dock.panelStyle ? 0 : (panel.side === "above" ? Style.space(8) : -Style.space(8))
      }
      Behavior on opacity { NumberAnimation { id: fade; duration: 180; easing.type: Easing.OutCubic } }

      // Panel: the ask layout, with the screenshot as it is now (your edits
      // so far) to drag out.
      AskPanel {
        id: askPanel
        visible: dock.panelStyle && !dock.collapsed
        x: panel.pad
        y: panel.pad
        width: card.width - panel.pad * 2
        taskbar: dock.taskbar
        mode: "image"
        path: dock.path
        app: dock.app
        title: dock.title
        showClose: false
        minQuestionHeight: Style.space(110)
        maxQuestionHeight: Style.space(240)
        onSent: dock.done()
        onCloseRequested: dock.collapse()

        Row {
          width: parent.width
          spacing: Style.space(10)
          Rectangle {
            id: liveThumb
            width: Style.space(72)
            height: Style.space(44)
            radius: Math.max(0, Style.cornerRadius - 2)
            color: Util.alpha(Color.popups.text, 0.06)
            border.width: 1
            border.color: Util.alpha(Color.accent, 0.7)
            clip: true
            Image {
              anchors.fill: parent
              anchors.margins: 1
              source: dock.path ? "file://" + dock.path + "?" + dock.rev : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: false
              sourceSize.width: Style.space(144)
            }
            HoverHandler { cursorShape: Qt.OpenHandCursor }
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.proposedAction: Qt.CopyAction
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.mimeData: ({ "text/uri-list": "file://" + dock.path + "\r\n", "text/plain": dock.path })
            Drag.active: liveDrag.active
            DragHandler {
              id: liveDrag
              target: null
              onActiveChanged: if (active) liveThumb.grabToImage(function(r) { liveThumb.Drag.imageSource = r.url })
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - liveThumb.width - Style.space(10)
            wrapMode: Text.WordWrap
            text: "With your edits so far. Drag it into any app to drop the file."
            color: Color.popups.text
            opacity: 0.45
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
      Item {
        id: footer
        visible: dock.panelStyle && !dock.collapsed
        x: panel.pad
        y: askPanel.y + askPanel.height + Style.space(12)
        width: card.width - panel.pad * 2
        height: visible ? doneButton.implicitHeight : 0
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "On your clipboard, with your edits"
          color: Color.popups.text
          opacity: 0.45
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }
        Button {
          id: doneButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "Done"
          foreground: Color.popups.text
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onClicked: dock.done()
        }
      }

      // Folded (Esc): a small tab; click it for the panel/bar again.
      Row {
        id: tab
        visible: dock.collapsed
        anchors.centerIn: parent
        spacing: Style.space(6)
        Image {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(14)
          height: width
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          source: TaskbarIcons.svg(askPanel.agentIcon(askPanel.agent || "claude"), String(Color.accent))
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Ask"
          color: Color.popups.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
      MouseArea {
        anchors.fill: parent
        visible: dock.collapsed
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          dock.collapsed = false
          askPanel.focusQuestion()
        }
      }

      ShotActions {
        id: actions
        visible: !dock.panelStyle && !dock.collapsed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        taskbar: dock.taskbar
        path: dock.path
        app: dock.app
        title: dock.title
        showThumb: true
        rev: dock.rev
        status: "On your clipboard, with your edits"
        onDone: dock.done()
        // Sending it to an agent is the end of it: close the editor too (your
        // edits are already saved, and that's what's sent).
        onSent: dock.done()
      }
    }
  }
}
