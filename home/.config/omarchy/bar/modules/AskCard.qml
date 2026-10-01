import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../../plugins/line-icons/lib/LineIcons.js" as TaskbarIcons

// Ask a coding agent about files (Files' right-click "Ask …",
// ~/.local/share/nautilus-python/extensions/omarchy_agents.py) or the selected
// text (Super+Alt+A). A compact card in the middle of the screen, the
// question first:
//
//   Ask  [✳ Claude] [ Codex] [ Grok] …  (up to five; the rest under More)  ×
//   ┌ the question, a few lines tall, growing as you type ─────────┐
//   └ Enter sends, Shift+Enter a new line ────────────────────────┘
//   [thumb] name · folder             (files: chips; text: quoted)
//   Send to  [New session] [an open session] …
//   Effort   [low] … [max]                    Enter to send · Esc to close
//
// Agents: ~/.config/omarchy/agents (primaries, the rest behind More). Effort
// only for a new session, per agent, remembered. Sending closes it; so do
// Esc, × and a click anywhere else. Chip rows: ChoiceChips.qml.
Item {
  id: card

  required property var taskbar
  property bool shown: false
  // "files" or "text"
  property string mode: "files"
  property var paths: []
  property string text: ""
  property string app: ""
  property string title: ""

  function showFiles(agentId, list) {
    mode = "files"
    paths = list
    text = ""
    app = ""
    title = ""
    open(agentId)
  }

  // The selected text: the primary selection (just highlighted), else the
  // clipboard's text. The focused window says where it came from.
  function showSelection() {
    var t = Hyprland.activeToplevel
    var ipc = t && t.lastIpcObject ? t.lastIpcObject : {}
    app = String(ipc.class || "")
    title = String(t && t.title ? t.title : "")
    selectionProc.running = true
  }
  Process {
    id: selectionProc
    command: ["bash", "-c", "t=$(wl-paste --primary --no-newline --type text 2>/dev/null); [ -n \"$t\" ] || t=$(wl-paste --no-newline --type text 2>/dev/null); printf '%s' \"$t\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var t = this.text
        if (t.trim() === "") {
          Util.execArgv(["omarchy-notification-send", "-u", "low", "Nothing selected", "Select some text first, then Super+Alt+A"])
          return
        }
        card.mode = "text"
        card.text = t.length > 20000 ? t.slice(0, 20000) : t
        card.paths = []
        card.open("")
      }
    }
  }

  function open(agentId) {
    shown = true
    askPanel.start(agentId)
    popIn.restart()
  }
  function hide() {
    shown = false
  }

  function baseName(p) { var s = String(p).replace(/\/+$/, ""); return s.slice(s.lastIndexOf("/") + 1) || s }
  function dirName(p) {
    var s = String(p).replace(/\/+$/, "")
    var d = s.slice(0, s.lastIndexOf("/")) || "/"
    var home = Quickshell.env("HOME")
    return d.indexOf(home) === 0 ? "~" + d.slice(home.length) : d
  }
  function isImage(p) { return /\.(png|jpe?g|webp|gif|bmp)$/i.test(String(p)) }
  readonly property bool oneImage: mode === "files" && paths.length === 1 && isImage(paths[0])

  PanelWindow {
    id: panel

    screen: card.taskbar.QsWindow.window ? card.taskbar.QsWindow.window.screen : null
    visible: card.shown || fade.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: card.shown ? cardRegion : noRegion
    property Region cardRegion: Region { item: box }
    property Region noRegion: Region {}
    WlrLayershell.namespace: "omarchy-ask-card"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: card.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // A click anywhere else closes it.
    HyprlandFocusGrab {
      active: card.shown
      windows: [panel]
      onCleared: card.hide()
    }

    readonly property int pad: Style.space(14)

    Rectangle {
      id: box
      width: Math.min(Style.space(560), panel.width - Style.space(40))
      height: askPanel.implicitHeight + panel.pad * 2
      x: Math.round((panel.width - width) / 2)
      y: Math.round(panel.height * 0.28)
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: 2
      border.color: Color.popups.border
      opacity: card.shown ? 1 : 0
      Behavior on opacity { NumberAnimation { id: fade; duration: 160; easing.type: Easing.OutCubic } }
      NumberAnimation { id: popIn; target: box; property: "scale"; from: 0.97; to: 1; duration: 200; easing.type: Easing.OutCubic }

      AskPanel {
        id: askPanel
        x: panel.pad
        y: panel.pad
        width: box.width - panel.pad * 2
        taskbar: card.taskbar
        mode: card.mode
        paths: card.paths
        text: card.text
        app: card.app
        title: card.title
        onSent: card.hide()
        onCloseRequested: card.hide()

          // What's attached: an image as a picture, other files as chips, text quoted.
          Row {
            visible: card.oneImage
            width: parent.width
            spacing: Style.space(12)
            Rectangle {
              id: picBox
              width: pic.status === Image.Ready
                ? Math.min(Style.space(96), Math.round(Style.space(44) * pic.implicitWidth / Math.max(1, pic.implicitHeight)))
                : Style.space(78)
              height: Style.space(44)
              color: Util.alpha(Color.popups.text, 0.04)
              border.width: 1
              border.color: Util.alpha(Color.popups.text, 0.15)
              Image {
                id: pic
                anchors.fill: parent
                anchors.margins: 1
                source: card.oneImage ? "file://" + card.paths[0] : ""
                sourceSize.height: Style.space(88)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
              }
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - picBox.width - Style.space(12)
              spacing: Style.space(3)
              Text {
                width: parent.width
                text: card.oneImage ? card.baseName(card.paths[0]) : ""
                elide: Text.ElideMiddle
                color: Color.popups.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                width: parent.width
                text: card.oneImage ? card.dirName(card.paths[0]) : ""
                elide: Text.ElideMiddle
                color: Color.popups.text
                opacity: 0.45
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          Column {
            visible: card.mode === "files" && !card.oneImage
            width: parent.width
            spacing: Style.space(5)
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: card.paths.slice(0, 8)
                Rectangle {
                  required property var modelData
                  width: Math.min(Style.space(200), chipRow.implicitWidth + Style.space(16))
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  color: Util.alpha(Color.popups.text, 0.06)
                  border.width: 1
                  border.color: Util.alpha(Color.popups.text, 0.15)
                  Row {
                    id: chipRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: Style.space(8)
                    spacing: Style.space(6)
                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(13)
                      height: width
                      sourceSize.width: width * 2
                      sourceSize.height: height * 2
                      source: TaskbarIcons.svg(/\/$/.test(String(modelData)) ? "folder" : "document", String(Color.accent))
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.min(implicitWidth, Style.space(160))
                      text: card.baseName(modelData)
                      elide: Text.ElideMiddle
                      color: Color.popups.text
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
              Text {
                visible: card.paths.length > 8
                height: Style.space(24)
                verticalAlignment: Text.AlignVCenter
                text: "+" + (card.paths.length - 8) + " more"
                color: Color.popups.text
                opacity: 0.5
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
            }
            Text {
              width: parent.width
              text: card.paths.length ? card.dirName(card.paths[0]) : ""
              elide: Text.ElideMiddle
              color: Color.popups.text
              opacity: 0.45
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            visible: card.mode === "text"
            width: parent.width
            spacing: Style.space(10)
            Rectangle { width: 2; height: quote.height; color: Color.accent; opacity: 0.7 }
            Column {
              width: parent.width - Style.space(12)
              spacing: Style.space(4)
              Text {
                id: quote
                width: parent.width
                text: card.text
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                color: Color.popups.text
                opacity: 0.8
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                visible: card.app !== ""
                width: parent.width
                elide: Text.ElideRight
                text: "from " + (card.title.replace(/^[^A-Za-z0-9]+/, "") || card.app) + (card.text.length > 400 ? "  ·  " + card.text.length + " characters" : "")
                color: Color.popups.text
                opacity: 0.4
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
      }
    }
  }
}
