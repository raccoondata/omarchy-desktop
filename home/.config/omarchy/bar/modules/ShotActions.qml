import QtQuick
import qs.Commons
import qs.Ui

// The action bar for handing something to a coding agent, shared by the
// editor dock (EditorDock.qml, under the screenshot editor's window), the
// screenshot preview (ScreenshotPreview.qml) and the ask card (AskCard.qml:
// files, selected text):
//
//   [thumbnail] · Ask Claude · Ask Codex · More · Edit     status · Open folder · Done
//
// The agents are the installed ones (~/.config/omarchy/agents): the two
// primaries as buttons, the rest behind More (shown in place, not as a menu:
// a menu would be clipped by these small windows).
//
// Asking turns the left side into a question field, with "Send to" chips (a
// new session, or one that's already open) on a second line; Enter sends via
// ~/.config/omarchy/ask-agent, which picks up the newest (annotated) version.
// The thumbnail (dock only) drags out as the file.
//
// Sizing: its implicitWidth comes from its own rows only, and nothing inside
// takes its size from the bar's width except the chips' wrapping (height).
// The container may size itself from implicitWidth/implicitHeight freely.
Item {
  id: actions

  required property var taskbar
  // What's being asked about: "image" (path), "files" (paths) or "text".
  property string mode: "image"
  property var paths: []
  property string text: ""
  property string path: ""
  property string app: ""
  property string title: ""
  property bool showThumb: false
  // Bumped when the file changes, to refresh the thumbnail.
  property int rev: 0
  // "" hides the button.
  property string editLabel: ""
  property bool showFolder: false
  property string status: ""
  // The agent id while asking ("" otherwise); target "new" or a window address.
  property string asking: ""
  property string target: "new"
  readonly property var sessions: asking !== "" ? taskbar.agentSessions(asking) : []
  // Showing the other agents (More) instead of the primaries.
  property bool more: false
  readonly property var primaryAgents: taskbar.agents.filter(function(a) { return a.primary })
  readonly property var otherAgents: taskbar.agents.filter(function(a) { return !a.primary })
  function glyph(id) {
    return id === "claude" ? "󰛄" : (id === "codex" ? "" : "󰚩")
  }

  signal edit()
  signal done()
  signal sent()
  signal dragStarted()
  signal dragFinished()

  implicitWidth: left.implicitWidth + right.implicitWidth + Style.space(28)
  implicitHeight: row.height + (chips.visible ? chips.implicitHeight + Style.space(6) : 0)
    + (effortRow.visible ? effortRow.implicitHeight + Style.space(6) : 0)

  // Effort for a new session, from the agent's own levels (./agents list);
  // "" = the agent's own default. Remembered per agent when picked.
  property string effort: ""
  readonly property var askingAgent: {
    for (var i = 0; i < taskbar.agents.length; i++) if (taskbar.agents[i].id === asking) return taskbar.agents[i]
    return null
  }
  readonly property var effortOptions: {
    var a = askingAgent
    if (!a || !a.efforts || a.efforts.length === 0) return []
    var list = a.effort === "" || a.efforts.indexOf(a.effort) === -1 ? [{ value: "", label: "Auto" }] : []
    return list.concat(a.efforts.map(function(e) { return { value: e, label: e } }))
  }
  function pickEffort(level) {
    effort = level
    if (level !== "") Util.execArgv([taskbar.omarchyDir + "/agents", "effort", asking, level])
  }

  function reset() {
    asking = ""
    target = "new"
    more = false
    question.text = ""
  }
  function ask(agent) {
    asking = agent
    target = "new"
    more = false
    effort = askingAgent && askingAgent.effort ? askingAgent.effort : ""
    Qt.callLater(function() { question.forceActiveFocus() })
  }
  function send() {
    var q = question.text.trim()
    var to = target !== "new" ? target : asking
    // Effort only means something for a new session.
    var script = taskbar.omarchyDir + "/ask-agent"
    var pre = target === "new" && effort !== "" ? ["--effort", effort] : []
    if (mode === "files") Util.execArgv([script].concat(pre, ["files", to, q], paths))
    else if (mode === "text") Util.execArgv([script].concat(pre, ["text", to, q, actions.text, app, title]))
    else if (target !== "new") Util.execArgv([script, "paste", target, path, app, title, q])
    else Util.execArgv([script].concat(pre, [asking, path, app, title, q]))
    reset()
    sent()
  }
  function openFolder() {
    Util.execArgv(["nautilus", "--select", path])
  }

  Item {
    id: row
    width: parent.width
    height: Math.max(left.implicitHeight, right.implicitHeight)

    Row {
      id: left
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Rectangle {
        id: thumb
        visible: actions.showThumb
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(48)
        height: Style.space(30)
        radius: Math.max(0, Style.cornerRadius - 2)
        color: Util.alpha(Color.popups.text, 0.06)
        border.width: 1
        border.color: Util.alpha(Color.accent, 0.7)
        clip: true

        Image {
          anchors.fill: parent
          anchors.margins: 1
          source: actions.path ? "file://" + actions.path + "?" + actions.rev : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          sourceSize.width: Math.round(thumb.width * 2)
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.OpenHandCursor
        }
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.mimeData: ({ "text/uri-list": "file://" + actions.path + "\r\n", "text/plain": actions.path })
        Drag.active: thumbDrag.active
        Drag.onDragFinished: actions.dragFinished()
        DragHandler {
          id: thumbDrag
          target: null
          onActiveChanged: if (active) {
            actions.dragStarted()
            thumb.grabToImage(function(r) { thumb.Drag.imageSource = r.url })
          }
        }
      }

      Divider { visible: actions.showThumb }

      Repeater {
        model: {
          if (actions.asking !== "") return []
          if (actions.more)
            return [{ kind: "back", label: "", icon: "󰁍" }].concat(actions.otherAgents.map(function(a) {
              return { kind: "agent", id: a.id, label: a.name, icon: actions.glyph(a.id) } }))
          var list = actions.primaryAgents.map(function(a) {
            return { kind: "agent", id: a.id, label: "Ask " + a.name, icon: actions.glyph(a.id) } })
          if (actions.otherAgents.length > 0) list.push({ kind: "more", label: "More", icon: "󰇘" })
          if (actions.editLabel) list.push({ kind: "edit", label: actions.editLabel, icon: "" })
          return list
        }
        Button {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.label
          iconText: modelData.icon
          foreground: Color.popups.text
          fontFamily: Style.font.menuFamily
          fontSize: Style.font.bodySmall
          onClicked: {
            if (modelData.kind === "edit") actions.edit()
            else if (modelData.kind === "more") actions.more = true
            else if (modelData.kind === "back") actions.more = false
            else actions.ask(modelData.id)
          }
        }
      }

      Text {
        visible: actions.asking !== ""
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: Style.space(2)
        text: actions.glyph(actions.asking)
        color: Color.accent
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }
      TextField {
        id: question
        visible: actions.asking !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(320)
        foreground: Color.popups.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        placeholderText: "Ask " + actions.taskbar.agentName(actions.asking) + " about it…  (empty: " + (actions.mode === "files" ? "what's this?" : "what's this / what's wrong?") + ")"
        onAccepted: actions.send()
        Keys.onEscapePressed: actions.reset()
      }
    }

    Row {
      id: right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: actions.asking === "" && actions.status !== ""
        rightPadding: Style.space(4)
        text: actions.status
        color: Color.popups.text
        opacity: 0.45
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
      Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: actions.showFolder && actions.asking === ""
        text: "Open folder"
        iconText: ""
        foreground: Color.popups.text
        fontFamily: Style.font.menuFamily
        fontSize: Style.font.bodySmall
        onClicked: actions.openFolder()
      }
      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: actions.asking !== "" ? "Cancel" : "Done"
        foreground: Color.popups.text
        fontFamily: Style.font.menuFamily
        fontSize: Style.font.bodySmall
        onClicked: {
          if (actions.asking !== "") actions.reset()
          else actions.done()
        }
      }
    }
  }

  // Asking: where to send it.
  ChoiceChips {
    id: chips
    anchors.top: row.bottom
    anchors.topMargin: Style.space(6)
    width: parent.width
    visible: actions.asking !== "" && actions.sessions.length > 0
    leftPadding: actions.showThumb ? thumb.width + Style.space(10) : Style.space(4)
    label: "Send to"
    options: [{ value: "new", label: "New session" }].concat(actions.sessions.map(function(s) { return { value: s.address, label: s.title || "session" } }))
    current: actions.target
    onPicked: function(v) { actions.target = v; question.forceActiveFocus() }
  }

  // Asking, for a new session: how hard the agent should think.
  ChoiceChips {
    id: effortRow
    anchors.top: chips.visible ? chips.bottom : row.bottom
    anchors.topMargin: Style.space(6)
    width: parent.width
    visible: actions.asking !== "" && actions.target === "new" && actions.effortOptions.length > 0
    leftPadding: actions.showThumb ? thumb.width + Style.space(10) : Style.space(4)
    label: "Effort"
    options: actions.effortOptions
    current: actions.effort
    onPicked: function(v) { actions.pickEffort(v); question.forceActiveFocus() }
  }

  component Divider: Rectangle {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: 1
    height: Style.space(18)
    color: Color.popups.text
    opacity: 0.15
  }
}
