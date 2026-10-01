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
import "AudioLevels.js" as AudioLevels
import "taskbar-icons.js" as TaskbarIcons
import "Visuals.js" as Visuals

// Super menu: double-tap Super (or Caps Lock, which is Super here) for your
// common apps in a grid, drawn like Omarchy's own menu.
//
//   Pinned    ~/.config/omarchy/supermenu.json {"pinned": [desktop ids]};
//             right-click a tile to pin or unpin it
//   Frequent  the apps you use most lately that aren't pinned, from
//             ~/.local/state/omarchy/app-usage.json (the taskbar counts every
//             switch to an app, and launches from here). Optional (setting
//             superMenuFrequent); × on a tile, or Delete, keeps that app out
//             of it ("hiddenFrequent" in supermenu.json)
//   Search    just type: all apps, Omarchy's own launcher search; under the
//             apps, rows for maths, folders (zoxide's best matches: Enter,
//             Shift+Enter, Ctrl+Enter do what settings say), settings,
//             Omarchy menu actions, asking an agent, the web
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
  onQueryChanged: folderSearch.restart()

  // ------------------------------------------------------------- folders
  // zoxide's best matches for what's typed (the folders you cd into most),
  // as rows under the apps. Looked up a moment after typing stops; nothing
  // without zoxide. Opening one tells zoxide, so the menu teaches it too.
  property var folderResults: []
  property string folderQuery: ""
  Timer {
    id: folderSearch
    interval: 120
    onTriggered: {
      var q = menu.query.trim()
      if (q.length < 2) { menu.folderResults = []; return }
      folderProc.forQuery = q
      folderProc.command = ["zoxide", "query", "--list", "--"].concat(q.split(/\s+/))
      folderProc.running = true
    }
  }
  Process {
    id: folderProc
    property string forQuery: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var home = Quickshell.env("HOME")
        var paths = this.text.split("\n").filter(function(p) { return p !== "" && p !== home }).slice(0, 3)
        menu.folderQuery = folderProc.forQuery
        menu.folderResults = paths.map(function(p) {
          var cut = p.lastIndexOf("/")
          var parent = p.slice(0, cut) || "/"
          return { kind: "folder", glyph: "", label: p.slice(cut + 1), path: p,
                   detail: parent.indexOf(home) === 0 ? "~" + parent.slice(home.length) : parent }
        })
      }
    }
  }

  // What Enter / Shift+Enter / Ctrl+Enter (or click, with the same keys) do
  // on a folder row (settings superMenuFolderEnter/Shift/Ctrl).
  readonly property var folderActionNames: ({ files: "Files", terminal: "Terminal", agent: "Agent", editor: "Editor", copy: "Copy path" })
  function folderAction(how) {
    var key = how === "ctrl" ? "superMenuFolderCtrl" : how === "shift" ? "superMenuFolderShift" : "superMenuFolderEnter"
    var fallback = how === "ctrl" ? "agent" : how === "shift" ? "terminal" : "files"
    var v = String(taskbar.pref(key, fallback))
    return folderActionNames[v] ? v : fallback
  }
  function folderActionLabel(how) {
    var a = folderAction(how)
    return a === "agent" && askAgents.length ? askAgents[0].name : folderActionNames[a]
  }
  readonly property string folderHint: "Enter: " + folderActionLabel("enter") + " · Shift+Enter: " + folderActionLabel("shift")
    + " · Ctrl+Enter: " + folderActionLabel("ctrl")
  function openFolderRow(r, how) {
    var a = folderAction(how)
    Util.execArgv(["zoxide", "add", "--", r.path])
    if (a === "files") Util.execArgv(["uwsm-app", "--", "nautilus", "--new-window", r.path])
    else if (a === "terminal") Util.execArgv(["setsid", "uwsm-app", "--", "xdg-terminal-exec", "--dir=" + r.path])
    else if (a === "agent") Util.execArgv([taskbar.omarchyDir + "/agents", "launch", askAgents.length ? askAgents[0].id : "claude", "--cwd", r.path])
    else if (a === "editor") Util.execArgv(["omarchy-launch-editor", r.path])
    else if (a === "copy") Util.execArgv(["wl-copy", r.path])
    close()
  }
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
        menu.hiddenFrequent = Array.isArray(data.hiddenFrequent) ? data.hiddenFrequent : []
      } catch (e) {
        menu.pinnedIds = []
        menu.hiddenFrequent = []
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
    if (!showFrequent) return []
    var candidates = []
    for (var id in usage) {
      if (pinnedIds.indexOf(id) !== -1 || hiddenFrequent.indexOf(id) !== -1) continue
      var entry = entryById(id)
      if (entry) candidates.push({ entry: entry, score: score(id) })
    }
    candidates.sort(function(a, b) { return b.score - a.score })
    return candidates.slice(0, maxFrequent).map(function(c) { return c.entry })
  }

  readonly property var searchEntries: query.length > 0 ? entriesFor(query).slice(0, columns * 3) : []

  // Everything the arrow keys walk through, in order.
  readonly property var tiles: query.length > 0 ? searchEntries : pinnedEntries.concat(frequentEntries)

  function saveConfig() {
    configFile.setText(JSON.stringify({ pinned: pinnedIds, hiddenFrequent: hiddenFrequent }, null, 2) + "\n")
  }

  function savePinned(ids) {
    pinnedIds = ids
    saveConfig()
  }

  // Frequent: on unless turned off in settings; apps taken out of it stay out
  // (until "show them again" in settings) but can still be found and pinned.
  readonly property bool showFrequent: taskbar.pref("superMenuFrequent", true) !== false && taskbar.pref("superMenuFrequent", true) !== "false"
  property var hiddenFrequent: []

  function hideFrequent(entry) {
    if (!entry || hiddenFrequent.indexOf(entry.id) !== -1) return
    hiddenFrequent = hiddenFrequent.concat([entry.id])
    saveConfig()
    selected = Math.max(0, Math.min(selected, tiles.length - 1))
  }

  function unhideFrequent() {
    hiddenFrequent = []
    saveConfig()
  }

  function isFrequent(entry) {
    return !!entry && query.length === 0 && frequentEntries.indexOf(entry) !== -1
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

  // Resting the pointer on a tile: its description in the hint line.
  property string hoverDetail: ""

  // ------------------------------------------------------- search extras
  //
  // Besides apps, a search also offers (rows under the app results, in this
  // order): a calculation ("24*7"), the desktop's settings tabs, Omarchy's
  // menu actions ("theme", "restart wifi"; those shown only on a condition
  // are left out), asking an agent, and the web.
  property var menuActions: []
  FileView {
    id: omarchyMenuDefaults
    path: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/default/omarchy/omarchy-menu.jsonc"
    printErrors: false
    onLoaded: menu.loadMenuActions()
  }
  FileView {
    id: omarchyMenuUser
    path: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: menu.loadMenuActions()
  }
  function parseJsonc(text) {
    try {
      var v = JSON.parse(String(text || "").replace(/^\s*\/\/[^\n]*(\n|$)/gm, "").replace(/,(\s*[}\]])/g, "$1"))
      return v && v.items ? v.items : (v || {})
    } catch (e) { return {} }
  }
  // Lower case, letters and digits only, so "wi-fi" matches "wifi".
  function searchable(text) {
    return String(text).toLowerCase().replace(/[^a-z0-9 ]+/g, "")
  }
  function loadMenuActions() {
    var items = {}
    var base = parseJsonc(omarchyMenuDefaults.text())
    var mine = parseJsonc(omarchyMenuUser.text())
    for (var k in base) items[k] = base[k]
    for (var k2 in mine) {
      var merged = {}
      for (var a in (items[k2] || {})) merged[a] = items[k2][a]
      for (var b in mine[k2]) merged[b] = mine[k2][b]
      items[k2] = merged
    }
    var out = []
    for (var id in items) {
      var it = items[id]
      if (!it || !it.action || it.when || it.provider) continue
      var parts = id.split(".")
      var trail = []
      var titles = []
      for (var i = 1; i < parts.length; i++) {
        var parent = items[parts.slice(0, i).join(".")]
        if (parent && parent.label) trail.push(String(parent.label))
        // A submenu's heading, e.g. Update > Hardware says "Restart".
        if (parent && parent.title) titles.push(String(parent.title))
      }
      var aliases = Array.isArray(it.aliases) ? it.aliases.join(" ") : String(it.aliases || "")
      out.push({ label: String(it.label || id), glyph: String(it.icon || ""), font: String(it.iconFont || ""),
                 detail: trail.join(" › ") || "Omarchy menu", action: String(it.action),
                 words: menu.searchable(trail.join(" ") + " " + titles.join(" ") + " " + (it.label || "") + " " + (it.description || "") + " " + aliases) })
    }
    menuActions = out
  }

  readonly property var settingsTargets: [
    { tab: "taskbar", label: "Taskbar settings", words: "taskbar icons group grouping click previews thumbnails dots badges order" },
    { tab: "windows", label: "Window settings", words: "windows gather placing title bars titlebars come to you" },
    { tab: "desktop", label: "Desktop settings", words: "desktop hot corners bar height motion effects snap mouse scroll speed super menu folders" },
    { tab: "icons", label: "Icon settings", words: "icons line coloured colored colours colors launcher original" },
    { tab: "media", label: "Media settings", words: "media now playing music equalizer visualizer album art effect glitch" },
    { tab: "screenshots", label: "Screenshot settings", words: "screenshots screenshot print screen editor tensaku" },
    { tab: "agents", label: "Agent settings", words: "agents agent claude codex ai" }
  ]

  // "24*7", "2^10", "(3+4)/2": the result, else null.
  function calc(q) {
    var s = String(q).trim()
    if (!/^[\d\s.+\-*\/%^()x×÷,]+$/.test(s) || !/\d/.test(s) || !/[+\-*\/%^x×÷]/.test(s.replace(/^\s*-/, ""))) return null
    s = s.replace(/[x×]/g, "*").replace(/÷/g, "/").replace(/\^/g, "**").replace(/,/g, "")
    try {
      var v = Function('"use strict"; return (' + s + ")")()
      return typeof v === "number" && isFinite(v) ? Number(v.toPrecision(12)) : null
    } catch (e) { return null }
  }

  readonly property var extraResults: {
    var q = query.trim()
    if (!q) return []
    var out = []
    var words = searchable(q).split(/\s+/).filter(function(w) { return w !== "" })
    var matches = function(text) { return words.every(function(w) { return text.indexOf(w) !== -1 }) }
    var value = calc(q)
    if (value !== null) out.push({ kind: "calc", glyph: "=", label: String(value), detail: "Enter copies it" })
    if (folderQuery === q) out = out.concat(folderResults)
    if (q.length >= 2) {
      settingsTargets.filter(function(t) { return matches(searchable(t.label + " " + t.words)) }).slice(0, 2)
        .forEach(function(t) { out.push({ kind: "settings", glyph: "\uf013", label: t.label, detail: "Taskbar & Desktop", tab: t.tab }) })
      menuActions.filter(function(a) { return matches(a.words) }).slice(0, 4)
        .forEach(function(a) { out.push({ kind: "action", glyph: a.glyph, font: a.font, label: a.label, detail: a.detail, action: a.action }) })
    }
    if (askAgents.length > 0) out.push({ kind: "ask", glyph: "\uf27a", label: "Ask " + askAgents[0].name, detail: "\u201c" + q + "\u201d", agent: askAgents[0].id })
    out.push({ kind: "web", glyph: "\uf002", label: "Search the web", detail: "\u201c" + q + "\u201d" })
    return out
  }

  // how: "enter", "shift" or "ctrl" (the key or click modifiers).
  function runExtra(r, how) {
    if (!r) return
    if (r.kind === "folder") { openFolderRow(r, how || "enter"); return }
    var q = query.trim()
    if (r.kind === "ask") { ask(r.agent); return }
    if (r.kind === "calc") Util.execArgv(["wl-copy", r.label])
    else if (r.kind === "settings") Util.execArgv(["omarchy-shell", "-q", "taskbar", "settings", r.tab])
    else if (r.kind === "action") Util.execDetached(r.action)
    else if (r.kind === "web") Qt.openUrlExternally("https://www.google.com/search?q=" + encodeURIComponent(q))
    close()
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

  // Opened for a look only (superMenuPreview IPC, for screenshots and
  // tests): no keyboard focus, so it can't take anyone's typing.
  property bool previewOnly: false
  function preview(text) {
    previewOnly = true
    open()
    query = text || ""
  }

  function close() {
    previewOnly = false
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
    var extras = query.length > 0 ? extraResults.length : 0
    // In the rows under the results: up/down (or left/right) one at a time;
    // up from the first goes back to the results.
    if (extras > 0 && (selected >= count || (dy > 0 && selected + dy * columns >= count && Math.floor(selected / columns) === Math.floor((count - 1) / columns)))) {
      var n = selected >= count ? selected + (dy !== 0 ? dy : dx) : count
      if (n < count) n = Math.max(0, count - 1)
      selected = Math.max(0, Math.min(count + extras - 1, n))
      return
    }
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

  // The playing app's name: a browser web app's own ("YouTube Music"), not
  // the browser's, which hosts its player (as now playing does).
  function playerAppName(p) {
    var site = MediaWindow.webAppSite(MediaWindow.bestWindow(p, Hyprland.toplevels.values))
    var entry = MediaWindow.webAppEntry(site, DesktopEntries.applications.values)
    return entry ? String(entry.name) : String(p.identity || "")
  }

  // Taskbar & Desktop > Icons > Super menu: the app's own icon ("app", the
  // default) or the desktop's line icon ("line"; apps without one keep
  // their own).
  readonly property bool lineIcons: menu.taskbar.pref("iconsSuperMenu", "app") === "line"
  function tileIcon(entry) {
    var name = lineIcons ? menu.taskbar.lineIconForEntry(entry) : ""
    if (name) return TaskbarIcons.svg(name, menu.taskbar.lineColor(name, Color.menu.text, menu.taskbar.colorModeFor("SuperMenu")))
    // The app's own icon, skipping the launcher's line icons (Icons > App
    // launcher puts them where Omarchy's icon index looks first).
    var icon = entry ? String(entry.icon || "") : ""
    var indexed = menu.library.iconIndex ? String(menu.library.iconIndex[icon] || "") : ""
    if (indexed.indexOf("/omarchy-desktop-launcher-") !== -1) {
      var themed = Quickshell.iconPath(icon, true)
      if (themed) return themed
    }
    return menu.library.iconSource(icon)
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
    return ""
  }

  // Folders in the footer (Desktop settings > Super menu), opened in Files;
  // "settings" is this desktop's settings window.
  readonly property var folderChoices: [
    { key: "home", label: "Home", glyph: "\uf015", dir: "" },
    { key: "downloads", label: "Downloads", glyph: "\uf019", dir: "XDG_DOWNLOAD_DIR" },
    { key: "documents", label: "Documents", glyph: "\uf15c", dir: "XDG_DOCUMENTS_DIR" },
    { key: "pictures", label: "Pictures", glyph: "\uf03e", dir: "XDG_PICTURES_DIR" },
    { key: "music", label: "Music", glyph: "\uf001", dir: "XDG_MUSIC_DIR" },
    { key: "videos", label: "Videos", glyph: "\uf008", dir: "XDG_VIDEOS_DIR" },
    { key: "settings", label: "Taskbar & Desktop settings", glyph: "\uf013", dir: "" }
  ]
  readonly property var footerFolders: {
    var keys = menu.taskbar.pref("superMenuFolders", ["home", "downloads", "documents", "pictures", "settings"])
    if (!Array.isArray(keys)) keys = []
    return folderChoices.filter(function(f) { return keys.indexOf(f.key) !== -1 })
  }
  property var userDirs: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/user-dirs.dirs"
    printErrors: false
    onLoaded: {
      var dirs = {}
      var re = /^(XDG_\w+_DIR)="(.*)"$/gm
      var m
      while ((m = re.exec(text())) !== null) dirs[m[1]] = m[2].replace("$HOME", Quickshell.env("HOME"))
      menu.userDirs = dirs
    }
  }
  function openFolder(f) {
    if (f.key === "settings") Util.execArgv(["omarchy-shell", "-q", "taskbar", "settings", "taskbar"])
    else {
      var path = f.dir ? (userDirs[f.dir] || Quickshell.env("HOME")) : Quickshell.env("HOME")
      Util.execArgv(["uwsm-app", "--", "nautilus", "--new-window", path])
    }
    close()
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
    WlrLayershell.keyboardFocus: menu.opened && !menu.previewOnly ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
          } else if (event.key === Qt.Key_Delete && menu.isFrequent(current)) {
            menu.hideFrequent(current)
          } else if (event.key === Qt.Key_Escape) {
            menu.close()
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && menu.selected >= menu.tiles.length
                     && menu.extraResults[menu.selected - menu.tiles.length]
                     && menu.extraResults[menu.selected - menu.tiles.length].kind === "folder") {
            // A folder row: its Enter / Shift+Enter / Ctrl+Enter actions.
            menu.runExtra(menu.extraResults[menu.selected - menu.tiles.length],
                          ctrl ? "ctrl" : (event.modifiers & Qt.ShiftModifier) ? "shift" : "enter")
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && ctrl && menu.query.trim() !== "") {
            // Ctrl+Enter: ask the first agent.
            menu.ask("")
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (menu.selected >= menu.tiles.length) menu.runExtra(menu.extraResults[menu.selected - menu.tiles.length])
            else menu.launch(menu.tiles[menu.selected], (event.modifiers & Qt.ShiftModifier) !== 0)
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
              : "Ctrl+Enter to ask"
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
          empty: menu.query.length > 0 ? (menu.extraResults.length > 0 ? "" : "No apps match") : "Right-click an app below to pin it"
        }

        // Besides apps: calculation, settings, Omarchy's actions, ask, web.
        Column {
          visible: menu.query.length > 0 && menu.extraResults.length > 0
          width: parent.width
          spacing: Style.space(2)
          Repeater {
            model: menu.query.length > 0 ? menu.extraResults : []
            Rectangle {
              id: extraRow
              required property var modelData
              required property int index
              readonly property bool current: menu.selected === menu.tiles.length + index
              width: parent.width
              height: Style.space(34)
              radius: Style.cornerRadius
              color: current ? Color.menu.selectedBackground : (extraMouse.containsMouse ? Util.alpha(Color.menu.text, 0.05) : "transparent")
              Text {
                id: extraGlyph
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(26)
                horizontalAlignment: Text.AlignHCenter
                text: extraRow.modelData.glyph
                color: extraRow.current ? Color.menu.selectedText : Color.menu.text
                opacity: 0.85
                font.family: extraRow.modelData.font || Style.font.menuFamily
                font.pixelSize: Style.font.body + 2
              }
              Text {
                id: extraLabel
                anchors.left: extraGlyph.right
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.5)
                text: extraRow.modelData.label
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: extraRow.current ? Color.menu.selectedText : Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                font.bold: extraRow.modelData.kind === "calc"
              }
              Text {
                anchors.left: extraLabel.right
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: extraRow.modelData.detail
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: Color.menu.text
                opacity: 0.45
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                id: extraMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: menu.selected = menu.tiles.length + extraRow.index
                onClicked: function(mouse) {
                  menu.runExtra(extraRow.modelData, (mouse.modifiers & Qt.ControlModifier) ? "ctrl"
                                : (mouse.modifiers & Qt.ShiftModifier) ? "shift" : "enter")
                }
              }
            }
          }
        }

        SuperMenuSection {
          owner: menu
          visible: menu.query.length === 0 && menu.frequentEntries.length > 0
          title: "Frequent"
          entries: menu.frequentEntries
          offset: menu.pinnedEntries.length
          removable: true
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
              opacity: npFx.visible ? 0 : 1
            }
            ShaderEffect {
              id: npFx
              anchors.fill: npImage
              visible: nowPlaying.fxChoice !== "off" && npImage.status === Image.Ready && !menu.taskbar.mediaSaving
              property variant source: npImage
              property real tick: 0
              readonly property real mode: Math.max(0, nowPlaying.fxModes.indexOf(nowPlaying.fxChoice))
              readonly property real aspect: 1
property real live: 0
              property real beatLevel: 0
              property real pump: 0
              property real loudness: 0
              property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)
              property vector4d bandsB: Qt.vector4d(0, 0, 0, 0)
              property vector4d bandsC: Qt.vector4d(0, 0, 0, 0)
              property vector4d bandsD: Qt.vector4d(0, 0, 0, 0)
              property int seenFrame: -1
              fragmentShader: Qt.resolvedUrl("shaders/artfx.frag.qsb")
              Timer {
                running: npFx.visible && menu.opened && nowPlaying.p !== null && nowPlaying.p.isPlaying
                interval: 66
                repeat: true
                onTriggered: {
                  AudioLevels.feed(npFx)
                  npFx.tick += 1
                }
              }
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
          // Media settings > Super menu: an equalizer and an art effect here
          // (GPU, only while the menu is open and it's playing).
          readonly property string eqChoice: String(menu.taskbar.pref("superMenuEq", "same"))
          readonly property string fxChoice: String(menu.taskbar.pref("superMenuArtFx", "off"))
          readonly property var fxModes: Visuals.values(Visuals.artEffects)
          Equalizer {
            id: npEq
            anchors.right: npControls.left
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            visible: nowPlaying.eqChoice !== "off"
            columns: 8
            rows: 5
            pixel: Math.max(3, Style.space(3))
            gap: 1
            playing: menu.opened && nowPlaying.p !== null && nowPlaying.p.isPlaying && visible
            silent: !(nowPlaying.p && nowPlaying.p.isPlaying)
            saving: menu.taskbar.mediaSaving
            style: nowPlaying.eqChoice === "same" ? menu.taskbar.equalizerStyle : nowPlaying.eqChoice
          }
          Column {
            anchors.left: npArt.right
            anchors.leftMargin: Style.space(12)
            anchors.right: npEq.visible ? npEq.left : npControls.left
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
                : nowPlaying.p ? [String(nowPlaying.p.trackArtist || ""), menu.playerAppName(nowPlaying.p)].filter(function(x) { return x !== "" }).join("  ·  ") : ""
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

          // Folders (and settings), as square buttons like the system ones.
          Row {
            id: folderButtons
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Repeater {
              model: menu.footerFolders
              Rectangle {
                id: folderButton
                required property var modelData
                readonly property bool hovered: folderMouse.containsMouse
                width: Style.space(34)
                height: width
                radius: Style.cornerRadius
                color: hovered ? Color.menu.selectedBackground : "transparent"
                border.width: 1
                border.color: Util.alpha(Color.menu.text, hovered ? 0.35 : 0.14)
                Text {
                  anchors.centerIn: parent
                  text: folderButton.modelData.glyph
                  color: folderButton.hovered ? Color.menu.selectedText : Color.menu.text
                  opacity: folderButton.hovered ? 1 : 0.8
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body + 2
                }
                MouseArea {
                  id: folderMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: menu.hoveredAction = folderButton.modelData.label
                  onExited: if (menu.hoveredAction === folderButton.modelData.label) menu.hoveredAction = ""
                  onClicked: menu.openFolder(folderButton.modelData)
                }
              }
            }
          }

          Text {
            anchors.left: folderButtons.right
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: actionButtons.left
            anchors.rightMargin: Style.space(12)
            text: menu.hoveredAction !== "" && menu.armedAction === "" && menu.systemActions.every(function(a) { return a.label !== menu.hoveredAction })
              ? menu.hoveredAction : menu.footerText
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
          readonly property var selectedExtra: menu.selected >= menu.tiles.length ? menu.extraResults[menu.selected - menu.tiles.length] : null
          text: menu.hoverDetail !== "" ? menu.hoverDetail
            : selectedExtra && selectedExtra.kind === "folder" ? menu.folderHint
            : menu.query.length > 0
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
