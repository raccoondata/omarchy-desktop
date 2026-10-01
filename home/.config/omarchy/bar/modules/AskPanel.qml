import QtQuick
import qs.Commons
import qs.Ui
import "../../plugins/line-icons/lib/LineIcons.js" as TaskbarIcons
import "../../plugins/line-icons/lib/IconMatch.js" as TaskbarMatch

// The ask layout, shared by the ask card (AskCard.qml: files, selected text)
// and the screenshot panel (ScreenshotPreview.qml and EditorDock.qml when
// Screenshots > Ask controls is "Panel"):
//
//   Ask  [✳ Claude] [ Codex] [ Grok] …  (up to five; the rest under More)  ×
//   ┌ the question, a few lines tall, growing as you type ─────────┐
//   └ Enter sends, Shift+Enter a new line                         ┘
//   (whatever the container puts inside: the screenshot, file chips, text)
//   Send to  [New session] [an open session] …
//   Effort   [low] … [max]
//
// Agents: ~/.config/omarchy/agents (taskbar.agents). Effort only for a new
// session, per agent, remembered. Sending runs ~/.config/omarchy/ask-agent
// and emits sent(); Esc and × emit closeRequested().
Column {
  id: ask

  required property var taskbar
  // What's being asked about: "image" (path), "files" (paths) or "text".
  property string mode: "image"
  property string path: ""
  property var paths: []
  property string text: ""
  property string app: ""
  property string title: ""
  property bool showClose: true
  property int labelWidth: Style.space(52)
  // The question box's height range.
  property int minQuestionHeight: Style.space(96)
  property int maxQuestionHeight: Style.space(180)
  // Children go between the question and the Send to row (slotItem: that
  // column, for an item that moves in and out, like the screenshot preview's
  // picture).
  default property alias attachment: slot.data
  property alias slotItem: slot

  property string agent: ""
  property string target: "new"
  property string effort: ""
  property bool more: false

  signal sent()
  signal closeRequested()

  spacing: Style.space(10)

  readonly property var primaryAgents: taskbar.agents.filter(function(a) { return a.primary })
  // Up to five agents as chips (primaries first); any more behind More.
  readonly property int inlineAgents: 5
  readonly property var shownAgents: taskbar.agents.length <= inlineAgents ? taskbar.agents : taskbar.agents.slice(0, inlineAgents - 1)
  readonly property var otherAgents: taskbar.agents.length <= inlineAgents ? [] : taskbar.agents.slice(inlineAgents - 1)
  readonly property var agentInfo: {
    for (var i = 0; i < taskbar.agents.length; i++) if (taskbar.agents[i].id === agent) return taskbar.agents[i]
    return null
  }
  readonly property var sessions: visible && agent !== "" ? taskbar.agentSessions(agent) : []
  readonly property var effortOptions: {
    var a = agentInfo
    if (!a || !a.efforts || a.efforts.length === 0) return []
    var list = a.effort === "" || a.efforts.indexOf(a.effort) === -1 ? [{ value: "", label: "Auto" }] : []
    return list.concat(a.efforts.map(function(e) { return { value: e, label: e } }))
  }

  // The agent's taskbar icon, by the taskbar's own rules (TaskbarMatch.js:
  // its program), else a terminal.
  function agentIcon(id) {
    var name = TaskbarMatch.programIcons[id] || id
    return TaskbarIcons.icons[name] ? name : "terminal"
  }

  function pickAgent(id) {
    agent = id
    target = "new"
    more = false
    effort = agentInfo && agentInfo.effort ? agentInfo.effort : ""
    question.forceActiveFocus()
  }
  // A fresh question for this agent (or the first one).
  function start(agentId) {
    question.text = ""
    pickAgent(agentId || (primaryAgents.length ? primaryAgents[0].id : "claude"))
    Qt.callLater(function() { question.forceActiveFocus() })
  }
  function focusQuestion() { question.forceActiveFocus() }

  function send() {
    var q = question.text.trim()
    var to = target !== "new" ? target : agent
    var pre = target === "new" && effort !== "" ? ["--effort", effort] : []
    var args = [taskbar.omarchyDir + "/ask-agent"]
    if (mode === "files") args = args.concat(pre, ["files", to, q], paths)
    else if (mode === "text") args = args.concat(pre, ["text", to, q, text, app, title])
    else if (target !== "new") args = args.concat(["paste", target, path, app, title, q])
    else args = args.concat(pre, [agent, path, app, title, q])
    Util.execArgv(args)
    question.text = ""
    sent()
  }

  // Which agent (primaries first, the rest behind More).
  Item {
    width: parent.width
    height: agentChips.implicitHeight
    ChoiceChips {
      id: agentChips
      anchors.left: parent.left
      anchors.right: closeText.visible ? closeText.left : parent.right
      anchors.rightMargin: closeText.visible ? Style.space(10) : 0
      labelWidth: ask.labelWidth
      label: "Ask"
      options: ask.more
        ? [{ value: "__back", label: "‹" }].concat(ask.otherAgents.map(function(a) { return { value: a.id, label: a.name, icon: ask.agentIcon(a.id) } }))
        : ask.shownAgents.map(function(a) { return { value: a.id, label: a.name, icon: ask.agentIcon(a.id) } })
          .concat(ask.otherAgents.length ? [{ value: "__more", label: "More" }] : [])
      current: ask.agent
      onPicked: function(v) {
        if (v === "__more") ask.more = true
        else if (v === "__back") ask.more = false
        else ask.pickAgent(v)
      }
    }
    Text {
      id: closeText
      visible: ask.showClose
      anchors.right: parent.right
      anchors.top: parent.top
      height: Style.space(24)
      verticalAlignment: Text.AlignVCenter
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
        onClicked: ask.closeRequested()
      }
    }
  }

  // The question: the main thing here. A few lines tall, growing with what
  // you type, then it scrolls.
  Rectangle {
    width: parent.width
    height: Math.min(ask.maxQuestionHeight, Math.max(ask.minQuestionHeight, question.contentHeight + Style.space(44)))
    radius: Style.cornerRadius
    color: Util.alpha(Color.popups.text, 0.04)
    border.width: 1
    border.color: question.activeFocus ? Color.accent : Util.alpha(Color.popups.text, 0.2)
    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Flickable {
      id: questionScroll
      anchors.fill: parent
      anchors.margins: Style.space(12)
      anchors.bottomMargin: Style.space(30)
      contentWidth: width
      contentHeight: question.contentHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      function follow(r) {
        if (r.y < contentY) contentY = r.y
        else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height
      }

      TextEdit {
        id: question
        width: questionScroll.width
        wrapMode: TextEdit.Wrap
        color: Color.popups.text
        selectionColor: Util.alpha(Color.accent, 0.35)
        selectedTextColor: Color.popups.text
        selectByMouse: true
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        onCursorRectangleChanged: questionScroll.follow(cursorRectangle)
        Keys.onPressed: function(event) {
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
            ask.send()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            ask.closeRequested()
            event.accepted = true
          }
        }
      }
    }
    Text {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(12)
      visible: question.text === ""
      elide: Text.ElideRight
      text: "Ask " + (ask.agentInfo ? ask.agentInfo.name : "") + " about "
        + (ask.mode === "text" ? "this text" : ask.mode === "image" ? "the screenshot" : (ask.paths.length === 1 ? "it" : "them"))
        + "…  (empty: " + (ask.mode === "files" ? "what's this?" : "what's this / what's wrong?") + ")"
      color: Color.popups.text
      opacity: 0.4
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.IBeamCursor
      acceptedButtons: Qt.NoButton
    }
    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(8)
      text: "Enter to send · Shift+Enter new line · Esc to close"
      color: Color.popups.text
      opacity: 0.3
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
    }
  }

  // What's attached (the container's children).
  Column {
    id: slot
    width: parent.width
    spacing: Style.space(6)
  }

  // Where, and how hard.
  ChoiceChips {
    width: parent.width
    visible: ask.sessions.length > 0
    labelWidth: ask.labelWidth
    label: "Send to"
    options: [{ value: "new", label: "New session" }].concat(ask.sessions.map(function(s) { return { value: s.address, label: s.title || "session" } }))
    current: ask.target
    onPicked: function(v) { ask.target = v; question.forceActiveFocus() }
  }
  ChoiceChips {
    width: parent.width
    visible: ask.target === "new" && ask.effortOptions.length > 0
    labelWidth: ask.labelWidth
    label: "Effort"
    options: ask.effortOptions
    current: ask.effort
    onPicked: function(v) {
      ask.effort = v
      if (v !== "") Util.execArgv([ask.taskbar.omarchyDir + "/agents", "effort", ask.agent, v])
      question.forceActiveFocus()
    }
  }
}
