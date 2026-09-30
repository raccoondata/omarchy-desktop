import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import qs.services
import "MediaWindow.js" as MediaWindow
import "taskbar-icons.js" as TaskbarIcons

// Super menu: double-tap Super (or Caps Lock, which is Super here) for your
// common apps in a grid, drawn like Omarchy's own menu.
//
//   Pinned    ~/.config/omarchy/supermenu.json {"pinned": [desktop ids]};
//             right-click a tile to pin or unpin it
//   Frequent  the apps you use most lately that aren't pinned, from
//             ~/.local/state/omarchy/app-usage.json (the taskbar counts every
//             switch to an app, and launches from here)
//   Search    just type: all apps, Omarchy's own launcher search
//   Ask       always there under the search line: "Ask [Claude] [Codex] …".
//             Nothing typed: click one for a new session. Typed: click one,
//             or Ctrl+Enter for the first (Enter too when no app matches), to
//             start a session with what you typed (~/.config/omarchy/agents,
//             ask-agent prompt)
//
// Now playing: while music (or any player) has a track loaded, a strip above
// the footer with its art, title and artist, progress, and previous / play /
// next; clicking the art or title goes to the app (MediaWindow.js, as the
// bar's now-playing widget).
// A footer holds the system actions (lock, suspend | log out, restart, shut
// down, restart into Windows); the session-ending ones take two clicks.
// Arrows move, Enter opens, Esc (or another Super double-tap) closes. An app
// that's already open is switched to (its most recently used window, restored
// if minimized); Shift+Enter or Shift+click opens a new window regardless.
// Editing: drag pinned apps (or Ctrl+Arrow) to rearrange; the +/- button on a
// tile, right-click, or Ctrl+P pins/unpins (search for any app to pin it);
// Delete unpins the selected pinned app.
// Apps come from an instance of Omarchy's AppLibrary service, so icons, hidden
// entries and launching (uwsm-app + gtk-launch) match its launcher.
Item {
  id: menu

  required property var taskbar
  // Omarchy's own app library service (bar widgets aren't handed the shell's
  // instance; only "menu" plugins are), so the same list, icons and launching.
  readonly property var library: appLibrary

  AppLibrary { id: appLibrary }

  property bool opened: false
  property string query: ""
  property int selected: 0
  property var pinnedIds: []
  property var usage: ({})

  readonly property int columns: 6
  readonly property int tileWidth: Style.space(112)
  readonly property int tileHeight: Style.space(100)
  readonly property int iconSize: Style.space(46)
  readonly property int maxFrequent: 6
  readonly property real gridWidth: columns * tileWidth + (columns - 1) * Style.space(6)
  readonly property string configPath: taskbar.omarchyDir + "/supermenu.json"
  readonly property string usagePath: Quickshell.env("HOME") + "/.local/state/omarchy/app-usage.json"

  // ------------------------------------------------------------------ data

  FileView {
    id: configFile
    path: menu.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(text())
        menu.pinnedIds = Array.isArray(data.pinned) ? data.pinned : []
      } catch (e) {
        menu.pinnedIds = []
      }
    }
  }

  FileView {
    id: usageFile
    path: menu.usagePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try { menu.usage = JSON.parse(text()) || {} } catch (e) { menu.usage = {} }
    }
  }

  // Written a little after the last change, not on every switch.
  Timer {
    id: saveUsage
    interval: 5000
    onTriggered: usageFile.setText(JSON.stringify(menu.usage) + "\n")
  }

  // One more use of an app (desktop id). The taskbar calls this on focus
  // changes; launching from here counts too.
  function noteUse(id) {
    if (!id) return
    var next = Object.assign({}, usage)
    var entry = next[id] || { count: 0, last: 0 }
    next[id] = { count: entry.count + 1, last: Date.now() }
    usage = next
    saveUsage.restart()
  }

  // Recent use counts for more: each day since the last use halves it.
  function score(id) {
    var entry = usage[id]
    if (!entry) return 0
    var days = (Date.now() - entry.last) / 86400000
    return entry.count * Math.pow(0.5, days)
  }

  // The library's search returns rows {entry, score, ...}; keep the entries.
  function entriesFor(q) {
    return library ? library.sortedEntries(q).map(function(row) { return row.entry }) : []
  }

  readonly property var allEntries: opened ? entriesFor("") : []

  function entryById(id) {
    for (var i = 0; i < allEntries.length; i++) if (allEntries[i].id === id) return allEntries[i]
    return null
  }

  readonly property var pinnedEntries: {
    var list = []
    for (var i = 0; i < pinnedIds.length; i++) {
      var entry = entryById(pinnedIds[i])
      if (entry) list.push(entry)
    }
    return list
  }

  readonly property var frequentEntries: {
    var candidates = []
    for (var id in usage) {
      if (pinnedIds.indexOf(id) !== -1) continue
      var entry = entryById(id)
      if (entry) candidates.push({ entry: entry, score: score(id) })
    }
    candidates.sort(function(a, b) { return b.score - a.score })
    return candidates.slice(0, maxFrequent).map(function(c) { return c.entry })
  }

  readonly property var searchEntries: query.length > 0 ? entriesFor(query).slice(0, columns * 3) : []

  // Everything the arrow keys walk through, in order.
  readonly property var tiles: query.length > 0 ? searchEntries : pinnedEntries.concat(frequentEntries)

  function savePinned(ids) {
    pinnedIds = ids
    configFile.setText(JSON.stringify({ pinned: ids }, null, 2) + "\n")
  }

  function isPinned(entry) {
    return !!entry && pinnedIds.indexOf(entry.id) !== -1
  }

  function togglePin(entry) {
    if (!entry) return
    var ids = pinnedIds.slice()
    var at = ids.indexOf(entry.id)
    if (at === -1) ids.push(entry.id)
    else ids.splice(at, 1)
    savePinned(ids)
  }

  // Pinned tiles by position (the grid shows pinnedEntries, which skips ids
  // with no app behind them; moves work on those positions).
  function movePinned(from, to) {
    var shown = pinnedEntries.map(function(e) { return e.id })
    if (from < 0 || from >= shown.length || to < 0 || to >= shown.length || from === to) return
    var id = shown.splice(from, 1)[0]
    shown.splice(to, 0, id)
    // Keep any pinned ids whose app is missing (uninstalled for now) at the end.
    savePinned(shown.concat(pinnedIds.filter(function(p) { return shown.indexOf(p) === -1 })))
    selected = to
  }

  // Dragging a pinned tile: where it came from, where it would land, and the
  // pointer (in the panel) for the floating copy.
  property int dragIndex: -1
  property int dropIndex: -1
  property point dragPoint: Qt.point(0, 0)
  readonly property var dragEntry: dragIndex >= 0 && dragIndex < pinnedEntries.length ? pinnedEntries[dragIndex] : null

  function endDrag() {
    if (dragIndex >= 0 && dropIndex >= 0) movePinned(dragIndex, dropIndex)
    dragIndex = -1
    dropIndex = -1
  }

  // ----------------------------------------------------------------- ask
  readonly property var askAgents: taskbar.agents.length <= 5 ? taskbar.agents : taskbar.agents.slice(0, 5)
  function agentIcon(id) {
    var name = id === "cursor-agent" ? "cursor" : id
    return TaskbarIcons.icons[name] ? name : "terminal"
  }
  function ask(agentId) {
    var q = query.trim()
    var id = agentId || (askAgents.length ? askAgents[0].id : "claude")
    // Nothing typed: just a new session.
    if (q === "") Util.execArgv([taskbar.omarchyDir + "/agents", "launch", id])
    else Util.execArgv([taskbar.omarchyDir + "/ask-agent", "prompt", id, q])
    close()
  }

  // --------------------------------------------------------- now playing
  // The player that's playing (not playerctld's stand-in), else one with a
  // track loaded.
  readonly property var mediaPlayer: {
    var list = Mpris.players ? Mpris.players.values : []
    var loaded = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p || String(p.dbusName || "").indexOf("playerctld") !== -1) continue
      if (!(p.trackTitle || p.trackArtist)) continue
      if (p.isPlaying) return p
      if (!loaded) loaded = p
    }
    return loaded
  }
  readonly property real mediaLength: mediaPlayer && mediaPlayer.lengthSupported ? Number(mediaPlayer.length) || 0 : 0
  readonly property real mediaProgress: mediaLength > 0 && mediaPlayer.positionSupported
    ? Math.max(0, Math.min(1, Number(mediaPlayer.position) / mediaLength)) : 0
  // MPRIS doesn't push the position as it plays; ask for it while open.
  Timer {
    running: menu.opened && !!menu.mediaPlayer && menu.mediaPlayer.isPlaying
    interval: 500
    repeat: true
    triggeredOnStart: true
    onTriggered: if (menu.mediaPlayer) menu.mediaPlayer.positionChanged()
  }
  function mediaToggle() {
    var p = mediaPlayer
    if (!p) return
    if (p.canTogglePlaying) p.togglePlaying()
    else if (p.isPlaying) p.pause()
    else p.play()
  }
  // Scrolling over it does what scrolling over the bar's now-playing widget
  // does (Taskbar & Desktop > Now Playing > Scrolling over it): the app's
  // volume (its PipeWire stream, else the player's own), the track, or nothing.
  readonly property var mediaStreams: {
    var list = []
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) if (nodes[i] && nodes[i].isStream && nodes[i].isSink) list.push(nodes[i])
    return list
  }
  PwObjectTracker { objects: menu.opened ? menu.mediaStreams : [] }
  readonly property var mediaStream: MediaWindow.playerStream(mediaPlayer, mediaStreams)
  readonly property bool mediaMuted: !!mediaStream && !!mediaStream.audio && mediaStream.audio.muted
  readonly property real mediaVolume: mediaStream && mediaStream.audio ? mediaStream.audio.volume
    : (mediaPlayer && mediaPlayer.volumeSupported ? Number(mediaPlayer.volume) || 0 : 0)
  property bool mediaShowingVolume: false
  Timer { id: mediaVolumeFlash; interval: 1500; onTriggered: menu.mediaShowingVolume = false }
  function mediaScroll(up) {
    var p = mediaPlayer
    if (!p) return
    var mode = String(taskbar.pref("nowPlayingScroll", "volume"))
    if (mode === "off") return
    if (mode === "track") {
      if (up && p.canGoPrevious) p.previous()
      else if (!up && p.canGoNext) p.next()
      return
    }
    var v = Math.max(0, Math.min(1, mediaVolume + (up ? 0.05 : -0.05)))
    if (mediaStream && mediaStream.audio) {
      mediaStream.audio.volume = v
      if (v > 0 && mediaStream.audio.muted) mediaStream.audio.muted = false
    } else if (p.volumeSupported && p.canControl) {
      p.volume = v
    } else {
      return
    }
    mediaShowingVolume = true
    mediaVolumeFlash.restart()
  }

  function mediaRaise() {
    var p = mediaPlayer
    close()
    Hyprland.refreshToplevels()
    var win = MediaWindow.bestWindow(p, Hyprland.toplevels.values)
    if (win) Util.execArgv([taskbar.omarchyDir + "/taskbar-action", "focus", MediaWindow.hexAddress(win)])
  }

  // ----------------------------------------------------------- open/close

  function toggle() {
    if (opened) close()
    else open()
  }

  function open() {
    if (!library) return
    library.refreshIcons()
    usageFile.reload()
    query = ""
    selected = 0
    opened = true
  }

  function close() {
    opened = false
    query = ""
    armedAction = ""
    hoveredAction = ""
  }

  // Open windows that belong to an app (by launcher entry), via the same
  // class -> entry lookup the usage counting uses.
  // A window belongs to the entry if its class is the entry's startup class or
  // id, or the class -> entry lookup lands on it. (Several entries can claim
  // one class, e.g. microsoft-edge and com.microsoft.Edge.)
  function windowsOf(entry) {
    var list = []
    var toplevels = taskbar.toplevels
    var startup = String(entry.startupClass || "").toLowerCase()
    var id = String(entry.id || "").toLowerCase()
    for (var i = 0; i < toplevels.length; i++) {
      var windowClass = taskbar.classOf(toplevels[i])
      var lower = windowClass.toLowerCase()
      var match = lower !== "" && (lower === startup || lower === id)
      if (!match) {
        var found = DesktopEntries.heuristicLookup(windowClass)
        match = !!found && found.id === entry.id
      }
      if (match) list.push(toplevels[i])
    }
    return list
  }

  function launch(entry, forceNew) {
    if (!entry || !library) return
    close()
    noteUse(entry.id)
    var all = windowsOf(entry)
    // Apps set to open on the current workspace (Files): their window here,
    // or a new one here, never a jump to another workspace.
    if (all.length > 0 && taskbar.hereApps.indexOf(taskbar.groupKeyOf(all[0])) !== -1) {
      var here = forceNew ? [] : taskbar.windowsHere(all)
      if (here.length > 0) taskbar.switchTo(taskbar.recentOf(here))
      else taskbar.runAction("newhere", [all[0]])
      return
    }
    var windows = forceNew ? [] : all
    if (windows.length > 0) taskbar.switchTo(taskbar.recentOf(windows))
    else library.launch(entry.id, library.entryName(entry))
  }

  function moveSelection(dx, dy) {
    var count = tiles.length
    if (count === 0) return
    var next = selected + dx + dy * columns
    // Up/down between the pinned and frequent grids: keep the column.
    if (query.length === 0 && dy !== 0) {
      var pinnedRows = Math.ceil(pinnedEntries.length / columns)
      var column = (selected < pinnedEntries.length ? selected : selected - pinnedEntries.length) % columns
      var row = selected < pinnedEntries.length ? Math.floor(selected / columns) : pinnedRows + Math.floor((selected - pinnedEntries.length) / columns)
      var rows = pinnedRows + Math.ceil(frequentEntries.length / columns)
      row = Math.max(0, Math.min(rows - 1, row + dy))
      next = row < pinnedRows ? Math.min(pinnedEntries.length - 1, row * columns + column)
                              : Math.min(count - 1, pinnedEntries.length + (row - pinnedRows) * columns + column)
    }
    selected = Math.max(0, Math.min(count - 1, next))
  }

  // --------------------------------------------------------- system actions

  // Same commands as Omarchy's own system menu.
  readonly property var systemActions: [
      { label: "Lock", verb: "lock", icon: "\uf023", command: menu.taskbar.omarchyDir + "/lock", group: 0 },
      { label: "Suspend", verb: "suspend", icon: "\udb81\udcb2", command: "systemctl suspend", group: 0, hidden: menu.suspendOff },
      { label: "Log Out", verb: "log out", icon: "\udb80\udf43", command: "omarchy-system-logout", group: 1, confirm: true },
      { label: "Restart", verb: "restart", icon: "\udb81\udf09", command: "omarchy-system-reboot", group: 1, confirm: true },
      { label: "Shut Down", verb: "shut down", icon: "\udb81\udc25", command: "omarchy-system-shutdown", group: 1, confirm: true },
      { label: "Restart into Windows", verb: "restart into Windows", icon: "\uf17a", command: menu.taskbar.omarchyDir + "/reboot-to-windows", group: 1, confirm: true, hidden: !menu.hasWindows }
  ].filter(function(a) { return !a.hidden })

  // Only on a PC with Windows to boot (reboot-to-windows --check).
  property bool hasWindows: false
  Process {
    id: windowsCheck
    command: [menu.taskbar.omarchyDir + "/reboot-to-windows", "--check"]
    onExited: function(code) { menu.hasWindows = code === 0 }
    Component.onCompleted: running = true
  }

  // Taskbar & Desktop > Icons > Super menu: the app's own icon ("app", the
  // default) or the desktop's line icon ("line"; apps without one keep
  // their own).
  readonly property bool lineIcons: menu.taskbar.pref("iconsSuperMenu", "app") === "line"
  function tileIcon(entry) {
    var name = lineIcons ? menu.taskbar.lineIconForEntry(entry) : ""
    return name ? TaskbarIcons.svg(name, String(Color.menu.text)) : menu.library.iconSource(entry ? entry.icon : "")
  }

  // Omarchy's "suspend off" toggle hides Suspend, as in its own menu.
  property bool suspendOff: false
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/suspend-off"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: menu.suspendOff = true
    onLoadFailed: menu.suspendOff = false
  }

  // Actions that end the session take two clicks: the first arms the button
  // (theme's urgent colour, "Click again to …"), the second runs it.
  property string armedAction: ""
  property string hoveredAction: ""
  Timer {
    id: disarm
    interval: 2500
    onTriggered: menu.armedAction = ""
  }

  function runSystem(action) {
    if (action.confirm && armedAction !== action.label) {
      armedAction = action.label
      disarm.restart()
      return
    }
    armedAction = ""
    close()
    Util.execDetached(action.command)
  }

  readonly property string userName: Quickshell.env("USER") || ""
  property string hostName: ""
  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: menu.hostName = text().trim()
  }

  // What the footer's left side says: the armed or hovered action, else you.
  readonly property string footerText: {
    for (var i = 0; i < systemActions.length; i++) {
      if (systemActions[i].label === armedAction) return "Click again to " + systemActions[i].verb
    }
    for (var j = 0; j < systemActions.length; j++) {
      if (systemActions[j].label === hoveredAction) return systemActions[j].label
    }
    return userName + (hostName ? "  ·  " + hostName : "")
  }

  // ------------------------------------------------------------------- ui

  PanelWindow {
    id: panel

    screen: menu.taskbar.QsWindow.window ? menu.taskbar.QsWindow.window.screen : null
    visible: menu.opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-super-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: menu.close()
    }

    BorderSurface {
      id: card

      width: menu.gridWidth + contentLeftInset + contentRightInset
      height: content.implicitHeight + contentTopInset + contentBottomInset
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.18) + rise
      opacity: 0

      // Opening: the card rises into place as it fades in.
      property real rise: 0
      ParallelAnimation {
        id: entrance
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: menu.taskbar.motionMove; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "rise"; from: 12; to: 0; duration: 180; easing.type: Easing.OutCubic }
      }
      Connections {
        target: menu
        function onOpenedChanged() { if (menu.opened) entrance.restart() }
      }
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keys
        anchors.fill: parent
        focus: menu.opened

        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          var current = menu.tiles[menu.selected]
          var inPinned = menu.query.length === 0 && menu.selected < menu.pinnedEntries.length
          if (ctrl && inPinned && (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                                   || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            var step = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1
                     : event.key === Qt.Key_Up ? -menu.columns : menu.columns
            menu.movePinned(menu.selected, Math.max(0, Math.min(menu.pinnedEntries.length - 1, menu.selected + step)))
          } else if (ctrl && event.key === Qt.Key_P) {
            menu.togglePin(current)
          } else if (event.key === Qt.Key_Delete && menu.isPinned(current)) {
            menu.togglePin(current)
            menu.selected = Math.max(0, Math.min(menu.selected, menu.tiles.length - 1))
          } else if (event.key === Qt.Key_Escape) {
            menu.close()
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                     && menu.query.trim() !== "" && (ctrl || menu.searchEntries.length === 0)) {
            // Ctrl+Enter, or Enter with no app matching: ask the first agent.
            menu.ask("")
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            menu.launch(menu.tiles[menu.selected], (event.modifiers & Qt.ShiftModifier) !== 0)
          } else if (event.key === Qt.Key_Left) {
            menu.moveSelection(-1, 0)
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            menu.moveSelection(1, 0)
          } else if (event.key === Qt.Key_Up) {
            menu.moveSelection(0, -1)
          } else if (event.key === Qt.Key_Down) {
            menu.moveSelection(0, 1)
          } else if (event.key === Qt.Key_Backspace) {
            menu.query = menu.query.slice(0, -1)
            menu.selected = 0
          } else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) {
            menu.query += event.text
            menu.selected = 0
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        id: content
        x: card.contentLeftInset
        y: card.contentTopInset
        width: menu.gridWidth
        spacing: Style.space(10)

        // Search line, like Omarchy's menu header.
        Text {
          width: parent.width
          text: menu.query.length > 0 ? menu.query : "Apps or a question…"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Color.menu.text
          opacity: menu.query.length > 0 ? 1 : 0.58
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
        }

        // Ask an agent: a new session, or about what you've typed.
        Item {
          visible: menu.askAgents.length > 0
          width: parent.width
          height: askChips.implicitHeight
          ChoiceChips {
            id: askChips
            anchors.left: parent.left
            anchors.right: askHint.left
            anchors.rightMargin: Style.space(12)
            label: "Ask"
            options: menu.askAgents.map(function(a) { return { value: a.id, label: a.name, icon: menu.agentIcon(a.id) } })
            current: menu.askAgents.length ? menu.askAgents[0].id : ""
            onPicked: function(v) { menu.ask(v) }
          }
          Text {
            id: askHint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: menu.query.trim() === "" ? "type a question, or click for a new session"
              : menu.searchEntries.length === 0 ? "Enter to ask" : "Ctrl+Enter to ask"
            color: Color.menu.text
            opacity: 0.45
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Color.menu.text
          opacity: 0.12
        }

        SuperMenuSection {
          owner: menu
          title: menu.query.length > 0 ? "Results" : "Pinned"
          entries: menu.query.length > 0 ? menu.searchEntries : menu.pinnedEntries
          offset: 0
          reorderable: menu.query.length === 0
          empty: menu.query.length > 0 ? "No apps match" : "Right-click an app below to pin it"
        }

        SuperMenuSection {
          owner: menu
          visible: menu.query.length === 0 && menu.frequentEntries.length > 0
          title: "Frequent"
          entries: menu.frequentEntries
          offset: menu.pinnedEntries.length
        }

        // Now playing.
        Rectangle {
          visible: nowPlaying.visible
          width: parent.width
          height: 1
          color: Color.menu.text
          opacity: 0.12
        }
        Item {
          id: nowPlaying
          readonly property var p: menu.mediaPlayer
          visible: menu.query.length === 0 && p !== null
          width: parent.width
          height: Style.space(52)

          Rectangle {
            id: npArt
            width: height
            height: parent.height
            radius: Math.min(Style.cornerRadius, 4)
            color: Util.alpha(Color.menu.text, 0.08)
            clip: true
            Image {
              id: npImage
              anchors.fill: parent
              source: nowPlaying.p ? String(nowPlaying.p.trackArtUrl || "") : ""
              sourceSize.width: 104
              sourceSize.height: 104
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }
            Text {
              anchors.centerIn: parent
              visible: npImage.status !== Image.Ready
              text: "󰝚"
              color: Color.menu.text
              opacity: 0.6
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
            }
          }
          Column {
            anchors.left: npArt.right
            anchors.leftMargin: Style.space(12)
            anchors.right: npControls.left
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            Text {
              width: parent.width
              text: nowPlaying.p ? String(nowPlaying.p.trackTitle || "") : ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              width: parent.width
              text: menu.mediaShowingVolume
                ? (menu.mediaMuted ? "Muted" : "Volume " + Math.round(menu.mediaVolume * 100) + "%")
                : nowPlaying.p ? [String(nowPlaying.p.trackArtist || ""), String(nowPlaying.p.identity || "")].filter(function(x) { return x !== "" }).join("  ·  ") : ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: Color.menu.text
              opacity: 0.55
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
            }
            Item {
              visible: menu.mediaLength > 0 || menu.mediaShowingVolume
              width: parent.width
              height: Math.max(2, Style.space(2))
              Rectangle { anchors.fill: parent; color: Color.menu.text; opacity: 0.14 }
              Rectangle {
                width: parent.width * (menu.mediaShowingVolume ? (menu.mediaMuted ? 0 : Math.min(1, menu.mediaVolume)) : menu.mediaProgress)
                height: parent.height
                color: Color.accent
                opacity: nowPlaying.p && nowPlaying.p.isPlaying ? 0.9 : 0.5
                Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.Linear } }
              }
            }
          }
          // Scrolling anywhere on it: as on the bar's widget.
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) { if (wheel.angleDelta.y !== 0) menu.mediaScroll(wheel.angleDelta.y > 0) }
          }
          // Art and words: go to the app.
          MouseArea {
            anchors.left: npArt.left
            anchors.right: npControls.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.mediaRaise()
          }

          Row {
            id: npControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Repeater {
              model: [
                { id: "previous", glyph: "󰒮" },
                { id: "toggle", glyph: "" },
                { id: "next", glyph: "󰒭" }
              ]
              Rectangle {
                id: npButton
                required property var modelData
                readonly property bool primary: modelData.id === "toggle"
                readonly property bool usable: !nowPlaying.p ? false
                  : modelData.id === "previous" ? nowPlaying.p.canGoPrevious
                  : modelData.id === "next" ? nowPlaying.p.canGoNext : true
                width: Style.space(primary ? 40 : 34)
                height: width
                radius: Style.cornerRadius
                color: primary ? Color.accent : (npMouse.containsMouse ? Util.alpha(Color.menu.text, 0.1) : "transparent")
                opacity: usable ? 1 : 0.35
                scale: npMouse.pressed ? 0.92 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Text {
                  anchors.centerIn: parent
                  text: npButton.primary ? (nowPlaying.p && nowPlaying.p.isPlaying ? "󰏤" : "󰐊") : npButton.modelData.glyph
                  color: npButton.primary ? Color.menu.background : Color.menu.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: npButton.primary ? Style.font.iconLarge : Style.font.title
                }
                MouseArea {
                  id: npMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: npButton.usable
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var p = nowPlaying.p
                    if (npButton.modelData.id === "previous") p.previous()
                    else if (npButton.modelData.id === "next") p.next()
                    else menu.mediaToggle()
                  }
                }
              }
            }
          }
        }

        Rectangle {
          visible: menu.query.length === 0
          width: parent.width
          height: 1
          color: Color.menu.text
          opacity: 0.12
        }

        // Footer: you (or the action under the pointer) on the left, the
        // system actions as square buttons on the right.
        Item {
          visible: menu.query.length === 0
          width: parent.width
          height: Style.space(38)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: actionButtons.left
            anchors.rightMargin: Style.space(12)
            text: menu.footerText
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: menu.armedAction !== "" ? Color.urgent : Color.menu.text
            opacity: menu.armedAction !== "" || menu.hoveredAction !== "" ? 1 : 0.55
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body

            Behavior on opacity { NumberAnimation { duration: menu.taskbar.motionFast } }
          }

          Row {
            id: actionButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Repeater {
              model: menu.systemActions

              Row {
                id: slot
                required property var modelData
                required property int index
                readonly property bool newGroup: index > 0 && menu.systemActions[index - 1].group !== modelData.group
                spacing: Style.space(6)

                // A hairline between the "stay" and "leave" groups.
                Rectangle {
                  visible: slot.newGroup
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: Style.space(20)
                  color: Color.menu.text
                  opacity: 0.15
                }

                Rectangle {
                  id: button
                  readonly property bool hovered: buttonMouse.containsMouse
                  readonly property bool armed: menu.armedAction === slot.modelData.label

                  width: Style.space(34)
                  height: width
                  radius: Style.cornerRadius
                  color: armed ? Util.alpha(Color.urgent, 0.18)
                       : hovered ? Color.menu.selectedBackground : "transparent"
                  border.width: 1
                  border.color: armed ? Color.urgent : Util.alpha(Color.menu.text, hovered ? 0.35 : 0.14)

                  Behavior on color { ColorAnimation { duration: menu.taskbar.motionFast } }
                  Behavior on border.color { ColorAnimation { duration: menu.taskbar.motionFast } }

                  Text {
                    anchors.centerIn: parent
                    text: slot.modelData.icon
                    color: button.armed ? Color.urgent : (button.hovered ? Color.menu.selectedText : Color.menu.text)
                    opacity: button.armed || button.hovered ? 1 : 0.8
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body + 2
                  }

                  MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: menu.hoveredAction = slot.modelData.label
                    onExited: if (menu.hoveredAction === slot.modelData.label) menu.hoveredAction = ""
                    onClicked: menu.runSystem(slot.modelData)
                  }
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: menu.query.length > 0
            ? "Enter opens (Shift: new window) · Ctrl+Enter asks an agent · + or Ctrl+P pins · Esc closes"
            : "Drag or Ctrl+Arrows to rearrange · +/− or Ctrl+P to pin · Shift: new window · type to find more"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignHCenter
          color: Color.menu.text
          opacity: 0.38
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // The tile being dragged, following the pointer.
    Image {
      visible: menu.dragEntry !== null
      z: 10
      width: menu.iconSize
      height: menu.iconSize
      x: menu.dragPoint.x - width / 2
      y: menu.dragPoint.y - height / 2
      sourceSize.width: Math.round(menu.iconSize * Screen.devicePixelRatio)
      sourceSize.height: Math.round(menu.iconSize * Screen.devicePixelRatio)
      source: menu.dragEntry ? menu.tileIcon(menu.dragEntry) : ""
      opacity: 0.9
    }
  }
}
