import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "taskbar-icons.js" as TaskbarIcons
import "TaskbarMatch.js" as TaskbarMatch
import "IconColors.js" as IconColors
import "MediaWindow.js" as MediaWindow
import "TaskbarStatus.js" as TaskbarStatus

// Taskbar built from Hyprland's own window list, so each entry knows its
// workspace. Windows with the same icon share one entry; the dots under it are
// its windows (the focused one wide and in the accent colour). Pinned programs
// (right-click > Pin to taskbar) stay on the bar when closed.
//
// Status, top-right of an entry (accent colour): an unread count from the
// title (Telegram, Teams), or a dot when a window wants you (Hyprland's urgent hint, or a
// Claude/Codex session that finished while you were elsewhere). Hovering an
// entry marks the workspaces its windows are on in Omarchy's workspace numbers.
//
// Click focuses a window; a group whose windows share a workspace jumps there
// (clicking it again steps through them), a spread-out group opens its picker
// (live thumbnails; drag one onto a workspace number to move that window);
// double-click maximizes a window or tiles a group on its own workspace;
// scrolling over a group steps through its windows; dragging an icon along
// the taskbar moves it to that spot (the order is kept in
// taskbar-order.json), and dropping it on a workspace number moves the
// window(s) there (press and hold first to move the whole taskbar instead);
// right-click opens a menu (incl. "Always open on workspace" and "Hide title
// bar"); middle-click or Shift+click opens a new window. Dragging any window
// onto a workspace number moves it there too (dragevents plugin).
// Super+Tab opens TaskbarSwitcher.qml. Actions run
// ~/.config/omarchy/taskbar-action. Icons come from taskbar-icons.js, coloured
// at runtime so they follow the theme. Minimized windows (moved to
// special:scratchpad by ~/.config/omarchy/window-minimize) render dimmed.
BarWidget {
  id: root

  readonly property var toplevels: Hyprland.toplevels.values
  // Where the scripts and state files the taskbar uses live.
  readonly property string omarchyDir: Quickshell.env("HOME") + "/.config/omarchy"
  readonly property int maxLabelWidth: Number(pref("maxLabelWidth", 120))
  readonly property bool showLabels: pref("showLabels", false) === true
  readonly property bool snapPreview: pref("snapPreview", true) !== false
  // Super+Space > Setup > Taskbar (~/.config/omarchy/taskbar-setting).
  readonly property bool showBadges: pref("showBadges", true) !== false
  readonly property bool flashAttention: pref("flashAttention", true) !== false
  readonly property bool hoverWorkspacesEnabled: pref("hoverWorkspaces", true) !== false
  readonly property bool audioMarks: pref("audioMarks", true) !== false
  // Minimize/restore outline and app open/close pixel effects.
  readonly property bool motionEffects: pref("motionEffects", true) !== false
  // spectrum | wave | embers | ripple (Equalizer.qml)
  readonly property string equalizerStyle: String(pref("equalizerStyle", "spectrum"))
  readonly property string minimizedWorkspace: "special:scratchpad"
  readonly property string restoreScript: root.omarchyDir + "/window-restore"
  readonly property string actionScript: root.omarchyDir + "/taskbar-action"
  readonly property string pinsPath: root.omarchyDir + "/taskbar-pins.json"
  readonly property color foreground: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  // Options live in taskbar-settings.json (~/.config/omarchy/taskbar-setting),
  // watched here and applied live. Not shell.json: any change there makes
  // Omarchy rebuild this whole widget, settings window and all. Anything not
  // in the file falls back to the widget's shell.json entry, then the default.
  property var prefs: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/taskbar-settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      pinKeyCheck.restart()
      try { root.prefs = JSON.parse(text()) || {} } catch (e) { }
    }
  }
  function pref(key, fallback) {
    var value = prefs[key]
    if (value === undefined || value === null) return setting(key, fallback)
    if (value === "true") return true
    if (value === "false") return false
    return value
  }

  // Taskbar settings (TaskbarSettings.qml / ~/.config/omarchy/taskbar-setting).
  readonly property real iconScale: Math.max(0.35, Math.min(0.8, Number(pref("iconScale", 0.55))))
  readonly property int iconSpacing: Math.max(0, Math.min(16, Number(pref("iconSpacing", 4))))
  readonly property bool showDots: pref("showDots", true) !== false
  readonly property bool groupWindows: pref("groupWindows", true) !== false
  // What clicking a group does: smart (one workspace: jump there; spread out:
  // previews) | previews (always the picker) | recent (the one used last).
  readonly property string groupClick: String(pref("groupClick", "smart"))
  // Taskbar & Desktop > Windows. (gatherLayout and newWindowPlace are read by
  // taskbar-action.)
  readonly property string doubleClickGroup: String(pref("doubleClickGroup", "tile"))     // tile | here | none
  readonly property string doubleClickWindow: String(pref("doubleClickWindow", "maximize")) // maximize | none
  readonly property bool clickActiveMinimizes: pref("clickActive", "none") === "minimize"
  readonly property int hoverDelay: Math.max(150, Math.min(1500, Number(pref("hoverDelay", 450))))
  readonly property int previewSize: Math.max(130, Math.min(320, Number(pref("previewSize", 190))))
  readonly property bool scrollCycles: pref("scrollCycle", true) !== false
  // Apps (entry keys) that come to you instead of you going to them: a click
  // focuses their window here, or brings the one used last here; double-click
  // brings all of them here (laid out evenly); a preview thumbnail brings that
  // window here; a new window opens here. Never another workspace. Files by
  // default; right-click an icon > Bring to current workspace, or Taskbar &
  // Desktop > Windows.
  readonly property var hereApps: {
    var list = pref("hereApps", ["folder"])
    return Array.isArray(list) ? list : ["folder"]
  }

  readonly property int iconSize: Math.round(barSize * iconScale * (showLabels ? 0.91 : 1))
  readonly property int pickerThumbWidth: Style.space(previewSize)
  // Motion: one short scale for every animation here, so it all feels the
  // same. Fades/hover = fast, things that move or grow = move.
  readonly property int motionFast: 80
  readonly property int motionMove: 130
  // Window address -> program in the foreground of the terminal it hosts
  // (nvim, lazygit, claude, ...), from ~/.config/omarchy/window-programs.
  property var programByAddress: ({})
  property string programsText: ""

  // Matching rules: TaskbarMatch.js (shared with the Super menu and now playing).
  readonly property var programIcons: TaskbarMatch.programIcons

  // Window classes -> icon, first match wins. Anything unmatched shows "app".
  // Your own icons and which windows get them, kept apart from the built-in
  // set so updates don't touch them (the taskbar-icons skill's icon-set
  // writes it): ~/.config/omarchy/taskbar-icons.json
  //   {"icons": {"name": "<svg body>"}, "programs": {"htop": "name"},
  //    "classes": [["^regex$", "name"]]}
  // Checked before the built-in rules. Read once at startup: restart the
  // shell after changing it.
  property var userPrograms: ({})
  property var userClasses: []
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/taskbar-icons.json"
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text()) || {}
        if (data.icons) TaskbarIcons.addIcons(data.icons)
        var classes = (data.classes || []).map(function(c) {
          try { return [new RegExp(c[0], "i"), String(c[1])] } catch (e) { return null }
        }).filter(function(c) { return c !== null })
        TaskbarMatch.setUser(data.programs || {}, classes)
        root.userPrograms = data.programs || {}
        root.userClasses = classes
      } catch (e) { }
    }
  }

  readonly property var classIcons: TaskbarMatch.classIcons

  // Names for tooltips and pins; anything else uses its window class.
  readonly property var appNames: ({
    claude: "Claude Code", codex: "Codex", telegram: "Telegram", teams: "Microsoft Teams",
    chrome: "Chromium", edge: "Microsoft Edge", whatsapp: "WhatsApp", discord: "Discord", youtube: "YouTube", youtubemusic: "YouTube Music",
    vscode: "Visual Studio Code", steam: "Steam", folder: "Files", ghostty: "Terminal",
    terminal: "Terminal", neovim: "Neovim", spotify: "Spotify", chatgpt: "ChatGPT",
    tensaku: "Tensaku", rustdesk: "RustDesk",
    grok: "Grok", gemini: "Gemini", opencode: "OpenCode", copilot: "GitHub Copilot", cursor: "Cursor",
    crush: "Crush", pi: "Pi", omp: "Oh My Pi", hermes: "Hermes", muse: "Muse Code", openclaw: "OpenClaw"
  })

  visible: !vertical && groups.length > 0
  implicitWidth: visible ? tasks.implicitWidth : 0
  implicitHeight: barSize

  function hexAddress(toplevel) {
    var address = String(toplevel.address || "")
    return address.indexOf("0x") === 0 ? address : "0x" + address
  }

  // ------------------------------------------------------------------ pins

  // Pinned programs, kept by taskbar-action in taskbar-pins.json as
  // [{key, icon, name, url | command + cwd}].
  property var pins: []

  // A pin's key is the icon its app had when pinned. When the app gets a new
  // icon (an update gives btop its own), the pin would stop joining its own
  // windows: rename it, and everything else stored under that key
  // (taskbar-action rekey). Once the launcher entries are loaded.
  property var pinKeysChecked: ({})
  Timer {
    id: pinKeyCheck
    interval: 3000
    onTriggered: root.checkPinKeys()
  }
  function checkPinKeys() {
    for (var i = 0; i < pins.length; i++) {
      var pin = pins[i]
      if (!pin || !pin.key || !pin.desktop || String(pin.key).indexOf(":") !== -1) continue
      var entry = DesktopEntries.byId(String(pin.desktop).replace(/\.desktop$/, ""))
      var live = TaskbarMatch.forEntry(entry)
      var pair = pin.key + ">" + live
      if (!live || live === pin.key || pinKeysChecked[pair]) continue
      pinKeysChecked[pair] = true
      Util.execArgv([omarchyDir + "/taskbar-action", "rekey", pin.key, live])
    }
  }

  FileView {
    path: root.pinsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text())
        root.pins = Array.isArray(list) ? list : []
      } catch (e) {
        root.pins = []
      }
    }
    onLoadFailed: root.pins = []
  }

  // Your drag-and-drop order of entries, by key, kept in taskbar-order.json.
  // Entries that aren't in it (a program you haven't placed) go at the end in
  // their natural order.
  readonly property string orderPath: root.omarchyDir + "/taskbar-order.json"
  property var order: []

  FileView {
    id: orderFile
    path: root.orderPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var list = []
      try { list = JSON.parse(text()) } catch (e) {}
      if (!Array.isArray(list)) list = []
      // Our own write comes back through the watcher; don't regroup twice.
      if (JSON.stringify(list) !== JSON.stringify(root.order)) root.order = list
    }
    onLoadFailed: root.order = []
  }

  // Programs that always open on one workspace (right-click > Always open on
  // workspace), kept by taskbar-action in taskbar-workspaces.json as
  // [{key, name, classes, workspace}]; taskbar-action turns them into
  // Hyprland window rules (hypr/workspace-pins.lua).
  readonly property string workspacePinsPath: root.omarchyDir + "/taskbar-workspaces.json"
  property var workspacePins: []

  FileView {
    path: root.workspacePinsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text())
        root.workspacePins = Array.isArray(list) ? list : []
      } catch (e) {
        root.workspacePins = []
      }
    }
    onLoadFailed: root.workspacePins = []
  }

  function workspacePinOf(key) {
    for (var i = 0; i < workspacePins.length; i++) if (workspacePins[i].key === key) return workspacePins[i]
    return null
  }

  // Window classes that stand for many programs (every terminal program runs
  // in one): a rule for them would catch everything, so no workspace pins.
  // (Claude and Codex from Super+C C / Super+V V have classes of their own.)
  readonly property var sharedClasses: /^(com\.mitchellh\.ghostty|org\.omarchy\.(?!claude$|codex$)|TUI\.|Alacritty|kitty|foot)/i

  function classesOf(group) {
    var list = []
    for (var i = 0; i < group.windows.length; i++) {
      var windowClass = classOf(group.windows[i])
      if (windowClass && list.indexOf(windowClass) === -1) list.push(windowClass)
    }
    return list
  }

  function canPinToWorkspace(group) {
    if (workspacePinOf(group.key)) return true
    var classes = classesOf(group)
    if (classes.length === 0) return false
    for (var i = 0; i < classes.length; i++) if (sharedClasses.test(classes[i])) return false
    return true
  }

  // Chip clicked in "Always open on workspace": pin there, or unpin when it's
  // the workspace it's already pinned to.
  function pinToWorkspace(group, workspace) {
    close()
    var pin = workspacePinOf(group.key)
    if (pin && pin.workspace === workspace) {
      Util.execArgv([actionScript, "wsunpin", group.key])
      return
    }
    var classes = classesOf(group)
    if (pin) classes = classes.concat((pin.classes || []).filter(function(c) { return classes.indexOf(c) === -1 }))
    Util.execArgv([actionScript, "wspin", group.key, String(workspace), group.name, JSON.stringify(classes)]
      .concat(group.windows.map(function(w) { return hexAddress(w) })))
  }

  // Apps whose title bar hyprbars leaves off (they draw their own), kept by
  // taskbar-action in titlebar-off.json as [{key, name, classes}].
  property var titlebarOff: []

  FileView {
    path: root.omarchyDir + "/titlebar-off.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var list = JSON.parse(text())
        root.titlebarOff = Array.isArray(list) ? list : []
      } catch (e) {
        root.titlebarOff = []
      }
    }
    onLoadFailed: root.titlebarOff = []
  }

  // Whether every window class of the group is in the no-title-bar list.
  function titlebarHidden(group) {
    var classes = classesOf(group)
    if (classes.length === 0) return false
    for (var i = 0; i < classes.length; i++) {
      var found = false
      for (var j = 0; j < titlebarOff.length && !found; j++) found = (titlebarOff[j].classes || []).indexOf(classes[i]) !== -1
      if (!found) return false
    }
    return true
  }

  function setTitlebar(group, show) {
    var classes = JSON.stringify(classesOf(group))
    if (show) Util.execArgv([actionScript, "titlebar", "on", classes])
    else Util.execArgv([actionScript, "titlebar", "off", group.key, group.name, classes])
  }

  function pinGroup(group) {
    if (group.windows.length > 0) Util.execArgv([actionScript, "pin", group.key, group.icon, group.name, hexAddress(group.windows[0])])
  }

  function unpinGroup(group) {
    Util.execArgv([actionScript, "unpin", group.key])
  }

  function launchGroup(group) {
    Util.execArgv([actionScript, "launch", group.key])
  }

  // ---------------------------------------------------------------- groups

  // Pinned entries first, in pin order, then everything else. Windows that
  // share an icon share an entry (three Claude terminals are one Claude
  // entry). The generic "app" and "browser" icons stand for many different
  // programs, so those still split by window class.
  readonly property var groups: {
    var list = []
    var byKey = {}
    for (var p = 0; p < pins.length; p++) {
      var pin = pins[p]
      if (!pin || !pin.key || byKey[pin.key]) continue
      byKey[pin.key] = { key: pin.key, icon: pin.icon || "app", appIcon: appIconFor("", pin.desktop), name: pin.name || pin.key, pinned: true, windows: [] }
      list.push(byKey[pin.key])
    }
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var windowClass = classOf(toplevel)
      var icon = iconName(hexAddress(toplevel), windowClass)
      var key = icon === "app" || icon === "browser" ? icon + ":" + windowClass : icon
      // Not grouping: every window after the first of a program gets its own
      // entry (keyed after it, so it sits next to it).
      if (!groupWindows && byKey[key] && byKey[key].windows.length > 0) key = key + "#" + hexAddress(toplevel)
      if (!byKey[key]) {
        byKey[key] = { key: key, icon: icon, appIcon: appIconFor(windowClass, ""), name: appNames[icon] || windowClass || "Application", pinned: false, windows: [] }
        list.push(byKey[key])
      }
      byKey[key].windows.push(toplevel)
    }
    if (order.length === 0) return list
    var rank = {}
    for (var r = 0; r < order.length; r++) rank[order[r]] = r
    return list
      .map(function(group, index) { return { group: group, index: index } })
      .sort(function(a, b) {
        // A separate window's entry ranks just after its program's.
        var ra = rank[String(a.group.key).split("#")[0]]
        var rb = rank[String(b.group.key).split("#")[0]]
        if (ra !== undefined && ra === rb) return a.index - b.index
        return (ra === undefined ? 1e6 + a.index : ra) - (rb === undefined ? 1e6 + b.index : rb)
      })
      .map(function(entry) { return entry.group })
  }

  // ---------------------------------------------------------------- status

  function classOf(toplevel) {
    return toplevel && toplevel.lastIpcObject ? String(toplevel.lastIpcObject.class || "") : ""
  }

  function programOf(toplevel) {
    return toplevel ? (programByAddress[hexAddress(toplevel)] || "") : ""
  }

  function agentOf(toplevel) {
    return toplevel ? TaskbarStatus.agentState(toplevel.title, programOf(toplevel)) : ""
  }

  function unreadOf(toplevel) {
    return toplevel ? TaskbarStatus.unreadCount(toplevel.title, classOf(toplevel)) : 0
  }

  function wantsYou(toplevel) {
    return toplevel ? attention[hexAddress(toplevel)] === true : false
  }

  function workspaceLabel(id) {
    return id === 10 ? "0" : String(id)
  }

  function placeOf(toplevel) {
    if (isMinimized(toplevel)) return "Minimized"
    var ws = toplevel && toplevel.workspace
    if (!ws || ws.id < 0) return ""
    return "Workspace " + workspaceLabel(ws.id)
  }

  // Everything a WindowCard shows about one window.
  function windowInfo(toplevel) {
    return {
      icon: iconName(hexAddress(toplevel), classOf(toplevel)),
      appIcon: appIcons ? appIconFor(classOf(toplevel), "") : "",
      iconColor: lineColor(iconName(hexAddress(toplevel), classOf(toplevel)), ""),
      minimized: isMinimized(toplevel),
      place: placeOf(toplevel),
      agent: agentOf(toplevel),
      attention: wantsYou(toplevel),
      unread: unreadOf(toplevel)
    }
  }

  // Windows that want you, by address: Hyprland's urgent hint (a chat message,
  // a terminal bell) or an agent that finished while you were elsewhere.
  // Cleared when the window is focused.
  property var attention: ({})
  // Last agent state seen per address, to notice working -> idle.
  property var agentStates: ({})

  function setAttention(address, on) {
    if ((attention[address] === true) === on) return
    var next = Object.assign({}, attention)
    if (on) next[address] = true
    else delete next[address]
    attention = next
  }

  function isActiveAddress(address) {
    var active = Hyprland.activeToplevel
    return active ? hexAddress(active) === address : false
  }

  function noteTitle(address, title) {
    var state = TaskbarStatus.agentState(title, programByAddress[address] || "")
    var before = agentStates[address] || ""
    if (state === before) return
    var next = Object.assign({}, agentStates)
    next[address] = state
    agentStates = next
    if (before === "working" && state === "idle" && !isActiveAddress(address)) setAttention(address, true)
  }

  // ------------------------------------------------------------- switching

  // Most recently focused first, for Alt+Tab.
  property var mru: []

  function noteFocus(address) {
    var next = mru.filter(function(a) { return a !== address })
    next.unshift(address)
    mru = next.slice(0, 64)
  }

  function forget(address) {
    mru = mru.filter(function(a) { return a !== address })
    setAttention(address, false)
  }

  function switcherWindows() {
    var rank = {}
    for (var i = 0; i < mru.length; i++) rank[mru[i]] = i
    var list = []
    for (var j = 0; j < toplevels.length; j++) list.push(toplevels[j])
    return list.sort(function(a, b) {
      var ra = rank[hexAddress(a)]
      var rb = rank[hexAddress(b)]
      return (ra === undefined ? 1000 : ra) - (rb === undefined ? 1000 : rb)
    })
  }

  // Keyboard switching: let Hyprland move the pointer onto the window.
  function switchTo(toplevel) {
    if (bar && toplevel) bar.run(restoreScript + " --address " + hexAddress(toplevel))
  }

  // Taskbar clicks and scrolling: focus (restoring a minimized window) but
  // leave the pointer on the taskbar.
  function focusWindow(toplevel) {
    if (toplevel) Util.execArgv([actionScript, "focus", hexAddress(toplevel)])
  }

  function closeWindow(toplevel) {
    if (toplevel) Util.execArgv([actionScript, "close", hexAddress(toplevel)])
  }

  // Scroll over a group: step through its windows (minimized ones only when
  // the whole group is minimized).
  function cycle(task, step) {
    var windows = task.windows.filter(function(w) { return !isMinimized(w) })
    if (windows.length === 0) windows = task.windows
    if (windows.length === 0) return
    var current = task.scrollTarget || task.activeWindow
    var index = windows.indexOf(current)
    var next = index < 0 ? (step > 0 ? 0 : windows.length - 1) : (index + step + windows.length) % windows.length
    task.scrollTarget = windows[next]
    focusWindow(windows[next])
  }

  TaskbarSwitcher {
    id: switcher
    taskbar: root
  }

  IpcHandler {
    target: "taskbar"

    function switcherNext(): void { switcher.move(1) }
    function switcherPrev(): void { switcher.move(-1) }
    function switcherCancel(): void { switcher.close() }
    // Mark a window as wanting you (0x-address), e.g. from a hook; it clears
    // when the window is focused.
    function attention(address: string): void {
      if (address && !root.isActiveAddress(address)) root.setAttention(address, true)
    }
    // Hyprland's Shift+click bind (hypr/desktop/bindings.lua) calls this, since the
    // bar never sees modifier keys itself.
    function shiftClick(): void { root.noteShiftClick() }
    // The workspace number under a point in layout coordinates, or 0. Used by
    // ~/.config/omarchy/snap-tile-edge when a dragged window is dropped.
    function workspaceAtPoint(x: int, y: int): int {
      var hit = root.workspaceAtGlobal(x, y)
      return hit ? hit.id : 0
    }
    // ~/.config/omarchy/hotcorner: the ripple, and whether a window drag is
    // under way (a corner reached mid-drag is ignored).
    function hotCorner(corner: string): void { desktopFx.ripple(corner) }
    // Double-tap Super / Caps Lock (hypr/desktop/bindings.lua): the super menu.
    function superMenu(): void { superMenu.toggle() }
    // Super+Space > Setup > Taskbar / Hot Corners: the settings window, on a
    // tab (taskbar | windows | desktop | icons | media |
    // screenshots | agents; older names like corners still work).
    function settings(tab: string): void { taskbarSettings.open(tab) }
    // The same without keyboard focus, for a look (screenshots, tests).
    function settingsPreview(tab: string): void { taskbarSettings.preview(tab) }
    function settingsClose(): void { taskbarSettings.close() }
    // Print Screen (~/.config/omarchy/screenshot): the screenshot card.
    // ~/.config/omarchy/lock: show the lock card before locking; it goes away
    // by itself on unlock (or if the lock doesn't happen).
    function lockCard(): void { root.showLockCard() }
    function screenshotTaken(path: string, app: string, title: string): void { root.screenshot(path, app, title, 0, 0, 0, 0, -1, -1) }
    // The captured area (global) and the pointer where the selection ended.
    function screenshotRegion(path: string, app: string, title: string, x: int, y: int, w: int, h: int, cx: int, cy: int): void {
      root.screenshot(path, app, title, x, y, w, h, cx, cy)
    }
    function isDragging(): bool { return root.windowDragging }
    // Files' right-click "Ask …" (~/.local/share/nautilus-python/extensions):
    // the ask card with these files (one path per line) and that agent picked.
    function askFiles(agent: string, paths: string): void {
      var list = String(paths).split("\n").filter(function(p) { return p !== "" })
      if (list.length > 0) askCard.showFiles(agent, list)
    }
    // Super+Alt+A: the ask card with the selected text (the primary
    // selection, or the clipboard's text when nothing is selected).
    function askSelection(): void { askCard.showSelection() }
    function reloadAgents(): void { root.reloadAgents() }
    // Esc in the screenshot editor while its ask panel/bar shows
    // (omarchy_screenshot_escape in hypr/desktop/bindings.lua): fold it away.
    function screenshotEscape(): void { editorDock.collapse() }
  }

  // ------------------------------------------------------------ shift-click

  // Shift+click = new window, like middle-click. Hyprland's bind reports the
  // Shift press (on the press, a few ms apart from our own click handling), so
  // whichever of the two arrives second does the work.
  property real shiftAt: 0
  property real shiftDoneAt: 0
  property Item hoveredTask: null

  function noteShiftClick() {
    var now = Date.now()
    // The bind can report the release too; one click opens one window.
    if (now - shiftDoneAt < 800) return
    var task = hoveredTask
    if (!task || !task.running) return
    if (now - task.lastClickAt < 700) task.newWindow()
    else shiftAt = now
  }

  function shiftPending() {
    return Date.now() - shiftAt < 700
  }

  // ---------------------------------------------------------- window drags

  // Dragging any window (title bar, Super+drag, middle-drag, or an app's own
  // tab strip, as reported by the dragevents plugin): rings mark the
  // workspace numbers, and a drop on one moves the window there.
  property bool windowDragging: false
  // Only tiles snap (snap-tile-edge leaves floating windows alone), so only
  // they get the snap preview.
  property bool dragTiled: false

  function setWindowDragging(on) {
    windowDragging = on
    if (on) {
      windowDragSafety.restart()
    } else {
      windowDragSafety.stop()
      desktopFx.zone = "none"
      dropItem = null
    }
  }

  // windowdragzone>>ZONE,X,Y,W,H
  function windowDragZone(data) {
    var parts = String(data).split(",")
    if (!windowDragging || !dragTiled || parts.length < 5) {
      desktopFx.zone = "none"
      return
    }
    desktopFx.area = Qt.rect(Number(parts[1]), Number(parts[2]), Number(parts[3]), Number(parts[4]))
    desktopFx.zone = parts[0]
    if (parts[0] !== "top") dropItem = null
  }

  // windowdragpos>>X,Y (pointer over the bar): light the number under it.
  function windowDragPos(data) {
    var parts = String(data).split(",")
    if (!windowDragging || parts.length < 2) return
    var hit = workspaceAtGlobal(Number(parts[0]), Number(parts[1]))
    dropItem = hit ? hit.item : null
  }

  SuperMenu {
    id: superMenu
    taskbar: root
  }

  TaskbarSettings {
    id: taskbarSettings
    taskbar: root
  }

  // After a screenshot (setting screenshotMode): "editor" = open it in the
  // screenshot editor with EditorDock attached; "preview" = our own preview
  // window (ScreenshotPreview.qml), also used if the editor doesn't open.
  readonly property string screenshotMode: String(pref("screenshotMode", "editor"))
  // How the screenshot's ask controls look: "panel" (the ask layout: question
  // first; ScreenshotPreview, and EditorDock beside the editor), "bar" (a row
  // of buttons: under the editor, under the preview's picture) or "button"
  // (just an Ask button that opens the panel).
  readonly property string screenshotAsk: String(pref("screenshotAsk", "panel"))
  property var lastShot: null
  function screenshot(path, app, title, x, y, w, h, cx, cy) {
    lastShot = { path: path, area: Qt.rect(x, y, w, h) }
    if (screenshotMode === "editor") editorDock.start(path, app, title, Qt.rect(x, y, w, h))
    else screenshotPreview.show(path, app, title, Qt.rect(x, y, w, h))
  }

  EditorDock {
    id: editorDock
    taskbar: root
    onFailed: function(path, app, title) {
      var area = root.lastShot && root.lastShot.path === path ? root.lastShot.area : Qt.rect(0, 0, 0, 0)
      screenshotPreview.show(path, app, title, area)
    }
  }

  AskCard {
    id: askCard
    taskbar: root
  }

  ScreenshotPreview {
    id: screenshotPreview
    taskbar: root
    onEditRequested: function(path, app, title) { editorDock.start(path, app, title, Qt.rect(0, 0, 0, 0)) }
  }

  // ------------------------------------------------------------ lock card

  // Up until Omarchy's lock says it's unlocked again (checked a few times a
  // second while the card is up), or 4 s if the lock never happened.
  property bool lockSeen: false
  property real lockCardAt: 0

  function showLockCard() {
    lockSeen = false
    lockCardAt = Date.now()
    desktopFx.lockCard = true
    lockPoll.start()
  }

  function hideLockCard() {
    desktopFx.lockCard = false
    lockPoll.stop()
  }

  Timer {
    id: lockPoll
    interval: 250
    repeat: true
    onTriggered: if (!lockCheck.running) lockCheck.running = true
  }

  Process {
    id: lockCheck
    command: ["omarchy-shell", "lock", "isLocked"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var locked = text.trim() === "true"
        if (locked) root.lockSeen = true
        else if (root.lockSeen || Date.now() - root.lockCardAt > 4000) root.hideLockCard()
      }
    }
  }

  function outlineCapture(area) {
    desktopFx.outlineCapture(area)
  }

  function releaseCapture() {
    desktopFx.releaseCapture()
  }

  function flyCapture(source, from, to, fit) {
    desktopFx.flyCapture(source, from, to, fit)
  }

  Connections {
    target: desktopFx
    function onCaptureLanded() { if (screenshotPreview.shown) screenshotPreview.captureLanded() }
  }

  // For the super menu's "Frequent": count each switch to a different app,
  // by its launcher (desktop) entry.
  property string lastUsedApp: ""

  function noteAppUse(address) {
    var toplevel = null
    for (var i = 0; i < toplevels.length; i++) if (hexAddress(toplevels[i]) === address) toplevel = toplevels[i]
    var windowClass = classOf(toplevel)
    if (!windowClass) return
    var entry = DesktopEntries.heuristicLookup(windowClass)
    if (!entry || entry.id === lastUsedApp) return
    lastUsedApp = entry.id
    superMenu.noteUse(entry.id)
  }

  DesktopFx {
    id: desktopFx
    taskbar: root
    // Over a workspace number the drop moves the window instead: no preview.
    previewEnabled: root.snapPreview && root.dropItem === null
  }

  Timer {
    id: windowDragSafety
    interval: 30000
    onTriggered: root.windowDragging = false
  }

  // windowdragend>>ADDRESS,X,Y,MOVED
  function windowDropped(data) {
    setWindowDragging(false)
    var parts = String(data).split(",")
    if (parts.length < 4) return
    var address = "0x" + parts[0]
    var x = Number(parts[1])
    var y = Number(parts[2])
    var hit = workspaceAtGlobal(x, y)
    if (!hit) {
      // Not on a number: screen-edge snapping (top = maximize, sides = half),
      // unless it was a click that never really moved.
      if (parts[3] === "1") Util.execArgv([snapScript, "--no-taskbar"])
      return
    }
    var toplevel = null
    for (var i = 0; i < toplevels.length; i++) if (hexAddress(toplevels[i]) === address) toplevel = toplevels[i]
    var group = { key: "window:" + address, icon: iconName(address, classOf(toplevel)), appIcon: appIconFor(classOf(toplevel), ""), windows: [toplevel || { address: address }] }
    var win = root.QsWindow.window
    var from = win ? root.mapFromItem(win.contentItem, x - win.screen.x, y - win.screen.y) : Qt.point(x, y)
    var size = Math.min(hit.item.width, hit.item.height)
    var center = glyphCenter(hit.item)
    dropFx.play(group, hit.id, from, Qt.rect(center.x - size / 2, center.y - size / 2, size, size))
  }

  // The workspace number under a point in layout (global) coordinates. The
  // bar is a layer surface at its screen's edge.
  function workspaceAtGlobal(x, y) {
    var win = root.QsWindow.window
    if (!win || !win.contentItem) return null
    var left = win.screen ? win.screen.x : 0
    var top = win.screen ? win.screen.y : 0
    if (win.margins) {
      left += win.margins.left || 0
      top += win.margins.top || 0
    }
    var p = root.mapFromItem(win.contentItem, x - left, y - top)
    return workspaceAt(root, p.x, p.y)
  }

  readonly property string snapScript: root.omarchyDir + "/snap-tile-edge"

  // -------------------------------------------------------------- popup

  // One popup, two modes: "picker" shows a group's windows as cards (left
  // click), and "menu" is the right-click menu. See PopupCard at the bottom.
  property bool popupOpen: false
  property string popupMode: "picker"
  property string popupKey: ""
  property Item popupAnchor: null
  readonly property var popupGroup: {
    for (var i = 0; i < groups.length; i++) if (groups[i].key === popupKey) return groups[i]
    return null
  }
  onPopupGroupChanged: {
    if (popupOpen && (!popupGroup || popupGroup.windows.length === 0
                      || (popupMode === "picker" && !hoverPreview && popupGroup.windows.length < 2))) close()
  }
  readonly property var menuItems: popupMode === "menu" && popupGroup ? buildMenu(popupGroup) : []

  function close() {
    popupOpen = false
    hoverPreview = false
  }

  function togglePopup(key, anchor, mode) {
    // Clicking an icon whose hover preview is showing keeps it open, as the
    // regular picker (it no longer closes when the pointer leaves).
    if (popupOpen && hoverPreview && popupKey === key && mode === "picker") {
      hoverPreview = false
      return
    }
    if (popupOpen && popupKey === key && popupMode === mode) {
      close()
      return
    }
    hoverPreview = false
    // Menu labels read floating/fullscreen from lastIpcObject; refresh it.
    if (mode === "menu") Hyprland.refreshToplevels()
    popupKey = key
    popupMode = mode
    popupAnchor = anchor
    popup.anchor.updateAnchor()
    Qt.callLater(function() { popup.anchor.updateAnchor() })
    popupOpen = true
  }

  // ------------------------------------------------------------------ audio

  // Which apps are playing sound, for the speaker mark on their entries and
  // per-app mute. Streams come from PipeWire; each is traced to its window by
  // process ancestry (~/.config/omarchy/audio-owners). Following Omarchy's own
  // audio panel: nothing reads a stream's properties until it's bound
  // (PwObjectTracker), and the UI works off a settled snapshot rather than
  // the live PipeWire model (rebuilding from removal signals has crashed it).
  readonly property var playbackStreams: {
    var nodes = Pipewire.nodes.values || []
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isStream && n.isSink === true) list.push(n)
    }
    return list
  }

  PwObjectTracker { objects: root.audioMarks ? root.playbackStreams : [] }

  // Window address -> { muted } for windows with a playback stream.
  property var audioByAddress: ({})
  property var audioOwners: ({})
  property var streamMuted: ({})
  property string audioPids: ""

  onPlaybackStreamsChanged: audioSnapshot.restart()

  Timer {
    id: audioSnapshot
    interval: 600
    onTriggered: root.snapshotAudio()
  }

  // Mute can change elsewhere (Omarchy's audio panel); look again now and then
  // while anything is playing.
  Timer {
    interval: 4000
    repeat: true
    running: root.audioMarks && root.playbackStreams.length > 0
    onTriggered: audioSnapshot.restart()
  }

  function streamPid(n) {
    if (!n || !n.ready || !n.audio || !n.properties) return ""
    return String(n.properties["application.process.id"] || "")
  }

  function snapshotAudio() {
    if (!audioMarks) {
      audioByAddress = {}
      return
    }
    var pids = []
    var muted = {}
    for (var i = 0; i < playbackStreams.length; i++) {
      var n = playbackStreams[i]
      var pid = streamPid(n)
      if (!pid) continue
      if (pids.indexOf(pid) === -1) pids.push(pid)
      muted[pid] = (muted[pid] === undefined ? true : muted[pid]) && n.audio.muted
    }
    streamMuted = muted
    pids.sort()
    var key = pids.join(" ")
    if (key === audioPids) {
      rebuildAudio()
      return
    }
    audioPids = key
    if (pids.length === 0) {
      audioOwners = {}
      rebuildAudio()
    } else if (!audioOwnersScan.running) {
      audioOwnersScan.command = [omarchyDir + "/audio-owners"].concat(pids)
      audioOwnersScan.running = true
    } else {
      audioPids = ""  // rescan when this one finishes
    }
  }

  Process {
    id: audioOwnersScan
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.audioOwners = JSON.parse(text) } catch (e) { root.audioOwners = {} }
        root.rebuildAudio()
        if (root.audioPids === "") audioSnapshot.restart()
      }
    }
  }

  // A browser and its web apps share one process, so its sound traces to
  // whichever of their windows came first. When several windows share the
  // process, the one its media player is showing (MediaWindow.bestWindow:
  // the window whose title names the track) gets it instead.
  function audioWindow(address) {
    var owner = null
    for (var i = 0; i < toplevels.length; i++) if (hexAddress(toplevels[i]) === address) owner = toplevels[i]
    var ipc = owner && owner.lastIpcObject ? owner.lastIpcObject : null
    if (!ipc || !ipc.pid) return address
    var shared = toplevels.filter(function(t) { return t.lastIpcObject && t.lastIpcObject.pid === ipc.pid })
    if (shared.length < 2) return address
    var players = Mpris.players.values || []
    for (var p = 0; p < players.length; p++) {
      var m = /instance_?(\d+)$/.exec(String(players[p].dbusName || ""))
      if (!m || Number(m[1]) !== ipc.pid || !players[p].isPlaying) continue
      var win = MediaWindow.bestWindow(players[p], shared)
      if (win) return hexAddress(win)
    }
    return address
  }

  function rebuildAudio() {
    var map = {}
    for (var pid in audioOwners) {
      if (streamMuted[pid] === undefined) continue
      var address = audioWindow(audioOwners[pid])
      if (!map[address]) map[address] = { muted: true }
      map[address].muted = map[address].muted && streamMuted[pid]
    }
    audioByAddress = map
  }

  // { playing, muted } for a group's windows.
  function audioOf(windows) {
    var playing = false
    var muted = true
    for (var i = 0; i < windows.length; i++) {
      var state = audioByAddress[hexAddress(windows[i])]
      if (!state) continue
      playing = true
      muted = muted && state.muted
    }
    return { playing: playing, muted: playing && muted }
  }

  // Mute (or unmute, if all of it is muted) everything these windows play.
  function toggleMute(windows) {
    var addresses = windows.map(function(w) { return hexAddress(w) })
    var mute = !audioOf(windows).muted
    for (var i = 0; i < playbackStreams.length; i++) {
      var n = playbackStreams[i]
      var pid = streamPid(n)
      if (pid && addresses.indexOf(audioOwners[pid]) !== -1) n.audio.muted = mute
    }
    audioSnapshot.restart()
  }

  // ---------------------------------------------- minimize/restore morph

  // The rectangle (global/layout coordinates) of a window, from Hyprland's
  // last report, or null.
  function windowRect(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject
    if (!ipc || !ipc.at || !ipc.size) return null
    return Qt.rect(ipc.at[0], ipc.at[1], ipc.size[0], ipc.size[1])
  }

  // The taskbar entry holding a window, as a global rectangle around its icon.
  function entryRect(toplevel) {
    var entries = taskEntries()
    var win = root.QsWindow.window
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].modelData.windows.indexOf(toplevel) === -1) continue
      var e = entries[i]
      var p = e.mapToItem(null, (e.width - iconSize) / 2, (e.height - iconSize) / 2)
      var ox = win && win.screen ? win.screen.x : 0
      var oy = win && win.screen ? win.screen.y : 0
      return Qt.rect(p.x + ox, p.y + oy, iconSize, iconSize)
    }
    return null
  }

  function toplevelByAddress(address) {
    for (var i = 0; i < toplevels.length; i++) if (hexAddress(toplevels[i]) === address) return toplevels[i]
    return null
  }

  // movewindowv2>>ADDRESS,WORKSPACEID,WORKSPACENAME
  function noteWindowMove(data) {
    var parts = String(data).split(",")
    if (parts.length < 3 || !motionEffects) return
    var toplevel = toplevelByAddress("0x" + parts[0])
    if (!toplevel) return
    var toName = parts.slice(2).join(",")
    var wasMinimized = isMinimized(toplevel)
    if (toName === minimizedWorkspace && !wasMinimized) {
      var from = windowRect(toplevel)
      var to = entryRect(toplevel)
      if (from && to) desktopFx.morph(from, to)
    } else if (wasMinimized && toName !== minimizedWorkspace) {
      // Where it lands is only known after the refresh.
      pendingRestore = toplevel
      restoreMorph.restart()
    }
  }

  property var pendingRestore: null
  Timer {
    id: restoreMorph
    interval: 90
    onTriggered: {
      var toplevel = root.pendingRestore
      root.pendingRestore = null
      var from = root.entryRect(toplevel)
      var to = root.windowRect(toplevel)
      if (from && to) desktopFx.morph(from, to)
    }
  }

  // ------------------------------------------------- open/close pixel fx

  // Entries that appear after startup assemble out of pixels; entries whose
  // program closed dissolve (a ghost at their last spot). The Repeater
  // rebuilds every entry whenever the groups change, so "new" and "gone" are
  // decided by key, against the keys seen last time.
  property bool entriesReady: false
  property var knownKeys: ({})
  property var lastEntryX: ({})
  property var ghosts: []
  property int ghostSerial: 0

  Timer {
    interval: 2500
    running: true
    onTriggered: {
      root.syncKnownKeys()
      root.entriesReady = true
    }
  }

  onGroupsChanged: Qt.callLater(syncKnownKeys)

  function syncKnownKeys() {
    var next = {}
    for (var i = 0; i < groups.length; i++) next[groups[i].key] = { icon: groups[i].icon, running: groups[i].windows.length > 0 }
    if (entriesReady && motionEffects) {
      var added = []
      for (var key in knownKeys) {
        // Gone from the bar entirely (pinned programs stay; they just dim).
        // "app:" is a brand-new window whose class isn't known yet; it turns
        // into its real entry a moment later, so it doesn't dissolve.
        if (!next[key] && key !== "app:" && lastEntryX[key] !== undefined) {
          ghostSerial++
          added.push({ serial: ghostSerial, icon: knownKeys[key].icon, x: lastEntryX[key] })
        }
      }
      if (added.length > 0) ghosts = ghosts.concat(added)
    }
    knownKeys = next
  }

  function dropGhost(serial) {
    ghosts = ghosts.filter(function(g) { return g.serial !== serial })
  }

  // --------------------------------------------------------- hover previews

  // Rest the pointer on a running entry and its windows show as live cards
  // (the picker, in "hover" mode: no focus grab, closes when the pointer has
  // left both the entry and the cards). Setting: hoverPreviews.
  property bool hoverPreview: false
  property Item previewCandidate: null
  readonly property bool hoverPreviewsEnabled: pref("hoverPreviews", true) !== false

  Timer {
    id: previewOpenDelay
    interval: root.hoverDelay
    onTriggered: {
      var task = root.previewCandidate
      if (!task || !task.running || root.dragGroup || root.rearrangeArmed) return
      if (root.popupOpen && !root.hoverPreview) return
      if (root.bar) root.bar.hideTooltip(task)
      root.togglePopup(task.modelData.key, task, "picker")
      root.hoverPreview = true
    }
  }

  Timer {
    id: previewCloseDelay
    interval: 280
    onTriggered: {
      // Never while one of its cards is being dragged (that closed the
      // preview mid-drag, destroying the card and stranding the drag).
      if (!root.hoverPreview || popup.containsMouse || root.dragGroup) return
      if (root.hoveredTask && root.hoveredTask.modelData.key === root.popupKey) return
      root.close()
    }
  }

  function previewEnter(task) {
    previewCloseDelay.stop()
    if (!hoverPreviewsEnabled || !task.running) return
    previewCandidate = task
    // Already previewing another entry: move over at once, like Windows.
    if (hoverPreview && popupKey !== task.modelData.key) {
      previewOpenDelay.stop()
      previewOpenDelay.triggered()
    } else if (!popupOpen) {
      previewOpenDelay.restart()
    }
  }

  function previewLeave(task) {
    if (previewCandidate === task) previewCandidate = null
    previewOpenDelay.stop()
    if (hoverPreview) previewCloseDelay.restart()
  }

  Connections {
    target: popup
    function onContainsMouseChanged() {
      if (!popup.containsMouse && root.hoverPreview) previewCloseDelay.restart()
    }
  }

  function addresses(windows) {
    return windows.map(function(w) { return hexAddress(w) }).join(" ")
  }

  // Runs ~/.config/omarchy/taskbar-action <action> <address>...
  function runAction(action, windows, ordered) {
    close()
    // Gathering (tile, here, move): the one used last goes first, so it gets
    // the big spot and keeps focus (taskbar-action gather).
    if (!ordered && /^(tile|here|move)\b/.test(action)) windows = byRecent(windows)
    if (bar && windows.length > 0) bar.run(actionScript + " " + action + " " + addresses(windows))
  }

  function byRecent(windows, order) {
    var list = order && order.length ? order : mru
    var ranked = windows.map(function(w, i) {
      var rank = list.indexOf(hexAddress(w))
      return { w: w, rank: rank < 0 ? 1e6 + i : rank }
    })
    ranked.sort(function(a, b) { return a.rank - b.rank })
    return ranked.map(function(r) { return r.w })
  }

  function runMenuItem(item, group) {
    close()
    if (item.action === "pin") pinGroup(group)
    else if (item.action === "unpin") unpinGroup(group)
    else if (item.action === "launch") launchGroup(group)
    else if (item.action === "mute" || item.action === "unmute") toggleMute(group.windows)
    else if (item.action === "settings") taskbarSettings.open("taskbar")
    else if (item.action === "here-on") setOpensHere(group, true)
    else if (item.action === "here-off") setOpensHere(group, false)
    else if (item.action === "titlebar-on") setTitlebar(group, true)
    else if (item.action === "titlebar-off") setTitlebar(group, false)
    else runAction(item.action, item.windows)
  }

  // Codicon glyphs from the bar's Nerd Font.
  readonly property var glyphs: ({
    new: "\uea60", minimize: "\ueaba", restore: "\ueabb", maximize: "\ueab9",
    float: "", here: "", tile: "", close: "",
    pin: "", unpin: "", launch: "",
    "titlebar-on": "\ueb7f", "titlebar-off": "\ueb7f",
    mute: "\udb81\udd81", unmute: "\udb81\udd7e",
    settings: "\ueb51",
    "here-on": "\ueb44", "here-off": "\ueb44"
  })

  // The workspace id all the windows are on, or -1 if they're spread out.
  function sharedWorkspace(windows) {
    var id = -1
    for (var i = 0; i < windows.length; i++) {
      var ws = windows[i].workspace
      if (!ws || isMinimized(windows[i])) return -1
      if (id !== -1 && ws.id !== id) return -1
      id = ws.id
    }
    return id
  }

  // Whether any of the windows is somewhere other than the workspace you're
  // looking at (another workspace, or minimized).
  function awayFromHere(windows) {
    var here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    for (var i = 0; i < windows.length; i++) {
      if (isMinimized(windows[i]) || !windows[i].workspace || windows[i].workspace.id !== here) return true
    }
    return false
  }

  function buildMenu(group) {
    var windows = group.windows
    var n = windows.length
    var items
    if (n === 0) {
      // A pinned program that isn't running.
      items = [
        { kind: "header", label: group.name },
        { action: "launch", label: "Open" }
      ]
      if (workspacePinOf(group.key)) items.push(workspacePinItem(group))
      items.push({ kind: "separator" })
      items.push({ action: "unpin", label: "Unpin from taskbar" })
    } else {
      var minimized = 0
      for (var i = 0; i < n; i++) {
        if (isMinimized(windows[i])) minimized++
      }
      var ipc = n === 1 && windows[0].lastIpcObject ? windows[0].lastIpcObject : {}
      items = [{ kind: "header", label: n > 1 ? group.name + "  ·  " + n + " windows" : TaskbarStatus.cleanTitle(title(windows[0])) }]
      items.push({ action: "new", label: "New window" })
      var sound = audioOf(windows)
      if (sound.playing) items.push({ action: sound.muted ? "unmute" : "mute", label: sound.muted ? "Unmute" : "Mute" })
      if (n > 1) items.push({ action: "tile", label: "Tile together" })
      if (minimized < n) items.push({ action: "minimize", label: n > 1 ? "Minimize all" : "Minimize" })
      if (minimized > 0) items.push({ action: "restore", label: n > 1 ? "Restore all" : "Restore" })
      if (n === 1 && minimized === 0) {
        items.push({ action: "maximize", glyphKey: ipc.fullscreen ? "restore" : "maximize",
          label: ipc.fullscreen ? "Restore size" : "Maximize" })
        items.push({ action: "float", label: ipc.floating ? "Tile window" : "Float window" })
      }
      if (awayFromHere(windows)) items.push({ action: "here", label: n > 1 ? "Bring all here" : "Bring here" })
      items.push({ kind: "workspaces", label: n > 1 ? "Move all to workspace" : "Move to workspace",
        windows: windows, current: sharedWorkspace(windows) })
      if (canPinToWorkspace(group)) items.push(workspacePinItem(group))
      // Same limits as pinning: one class per program, not a shared terminal.
      if (classesOf(group).length > 0 && canPinToWorkspace(group))
        items.push(titlebarHidden(group) ? { action: "titlebar-on", label: "Show title bar" }
                                         : { action: "titlebar-off", label: "Hide title bar (app draws its own)" })
      items.push(group.pinned ? { action: "unpin", label: "Unpin from taskbar" } : { action: "pin", label: "Pin to taskbar" })
      items.push(opensHere(group) ? { action: "here-off", label: "Brings to current workspace ✓" }
                                  : { action: "here-on", label: "Bring to current workspace" })
      items.push({ action: "settings", label: "Taskbar settings…" })
      items.push({ kind: "separator" })
      items.push({ action: "close", danger: true, label: n > 1 ? "Close all " + n + " windows" : "Close window" })
    }
    for (var j = 0; j < items.length; j++) {
      if (!items[j].action) continue
      items[j].windows = items[j].action === "new" ? newWindowArgs(windows) : windows
      items[j].glyph = glyphs[items[j].glyphKey || items[j].action]
    }
    return items
  }

  // "Always open on workspace" chips; the pinned one is filled, and clicking
  // it again unpins.
  function workspacePinItem(group) {
    var pin = workspacePinOf(group.key)
    return { kind: "workspaces", mode: "pin", windows: group.windows, current: pin ? pin.workspace : -1,
      label: pin ? "Always opens on workspace " + workspaceLabel(pin.workspace) : "Always open on workspace" }
  }

  // --------------------------------------------------------- drag and drop

  // Drag and drop onto the workspace numbers. The numbers belong to Omarchy's
  // omarchy.workspaces widget, so the drop target is found by hit-testing the
  // bar for one of its buttons (each carries its workspace id as modelData).
  // Set while a taskbar icon is pressed and held: drags then rearrange the bar.
  property bool rearrangeArmed: false
  property bool suppressClick: false
  onRearrangeArmedChanged: if (rearrangeArmed) suppressClick = true

  property var dragGroup: null
  property point dragPos: Qt.point(0, 0)
  property int dropWorkspace: -1
  property Item dropItem: null
  // Dragging along the taskbar reorders it: the slot (entry index) the
  // dragged entry would land in, or -1.
  property int reorderIndex: -1

  function startDrag(group) {
    dragGroup = group
    dropWorkspace = -1
    dropItem = null
  }

  function dragMove(from, x, y) {
    dragMoveTo(from.mapToItem(root, x, y))
  }

  // point is in this widget's coordinates.
  function dragMoveTo(point) {
    dragPos = point
    var hit = workspaceAt(root, point.x, point.y)
    dropWorkspace = hit ? hit.id : -1
    dropItem = hit ? hit.item : null
    reorderIndex = hit ? -1 : reorderIndexAt(dragPos)
  }

  // A picker card being dragged: the picker is its own popup window, placed at
  // its anchor rect in the bar's window, so map through that. (While the
  // button is held the popup keeps getting the pointer, even over the bar.)
  function fromPopup(item, x, y) {
    var p = item.mapToItem(null, x, y)
    var bx = popup.anchor.rect.x + p.x
    var by = popup.anchor.rect.y + p.y
    var win = root.QsWindow.window
    return win && win.contentItem ? root.mapFromItem(win.contentItem, bx, by) : Qt.point(bx, by)
  }

  function startWindowDrag(toplevel) {
    startDrag({ key: "window:" + hexAddress(toplevel), icon: iconName(hexAddress(toplevel), classOf(toplevel)), appIcon: appIconFor(classOf(toplevel), ""),
      name: title(toplevel), windows: [toplevel] })
  }

  // The taskbar's entries left to right (the Row also holds the Repeater).
  function taskEntries() {
    var list = []
    for (var i = 0; i < tasks.children.length; i++) {
      var child = tasks.children[i]
      if (child.visible && child.modelData && child.modelData.key !== undefined) list.push(child)
    }
    return list.sort(function(a, b) { return a.x - b.x })
  }

  // Where the dragged entry would land, as an index into taskEntries(), or -1
  // when the pointer has left the taskbar or the spot wouldn't change anything.
  function reorderIndexAt(point) {
    if (!dragGroup) return -1
    var p = tasks.mapFromItem(root, point.x, point.y)
    if (p.y < -Style.space(8) || p.y > tasks.height + Style.space(40)) return -1
    if (p.x < -Style.space(24) || p.x > tasks.width + Style.space(24)) return -1
    var entries = taskEntries()
    var index = 0
    var from = -1
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].modelData.key === dragGroup.key) from = i
      if (p.x > entries[i].x + entries[i].width / 2) index = i + 1
    }
    if (from < 0 || index === from || index === from + 1) return -1
    return index
  }

  // Put an entry in a new slot and remember the whole order.
  function moveEntry(key, slot) {
    var keys = taskEntries().map(function(e) { return e.modelData.key })
    var from = keys.indexOf(key)
    if (from < 0) return
    keys.splice(from, 1)
    keys.splice(slot > from ? slot - 1 : slot, 0, key)
    // Keep the places of programs that aren't open right now.
    var next = keys.concat(order.filter(function(k) { return keys.indexOf(k) < 0 }))
    order = next
    orderFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  // Drops on whatever the last dragMove found under the cursor: the icon
  // shrinks into the workspace number, the number pulses, and the windows move.
  function endDrag() {
    var group = dragGroup
    var target = dropWorkspace
    var targetItem = dropItem
    var from = dragPos
    var slot = reorderIndex
    cancelDrag()
    if (!group) return
    if (slot >= 0) {
      moveEntry(group.key, slot)
      return
    }
    if (group.windows.length === 0 || target <= 0 || !targetItem) return
    var size = Math.min(targetItem.width, targetItem.height)
    var center = glyphCenter(targetItem)
    dropFx.play(group, target, from, Qt.rect(center.x - size / 2, center.y - size / 2, size, size))
  }

  function cancelDrag() {
    var wasWindow = dragGroup && String(dragGroup.key).indexOf("window:") === 0
    dragGroup = null
    // A picker/preview card dropped somewhere that isn't a workspace: let a
    // hover preview close again once the pointer is off it.
    if (wasWindow && hoverPreview) previewCloseDelay.restart()
    dropWorkspace = -1
    dropItem = null
    reorderIndex = -1
  }

  // Depth-first search for the first item that passes test().
  function findItem(item, test, depth) {
    if (!item || depth > 64) return null
    if (test(item)) return item
    var kids = item.children
    for (var i = 0; i < kids.length; i++) {
      var found = findItem(kids[i], test, depth + 1)
      if (found) return found
    }
    return null
  }

  property Item workspacesWidget: null
  // Workspace ids to mark while an entry is hovered.
  property var hoverWorkspaces: []

  function findWorkspacesWidget() {
    if (!workspacesWidget || !workspacesWidget.parent) {
      var top = root
      while (top.parent) top = top.parent
      workspacesWidget = findItem(top, function(item) { return item.moduleName === "omarchy.workspaces" }, 0)
    }
    return workspacesWidget
  }

  // The workspaces widget's button for one workspace id.
  function workspaceButton(id) {
    var widget = findWorkspacesWidget()
    if (!widget) return null
    return findItem(widget, function(item) {
      return item !== widget && item.modelData === id && item.visible
    }, 0)
  }

  // Where a workspace number's digit actually sits, in this widget's
  // coordinates. The button centres its text box, but digits sit high in that
  // box (it leaves room below the baseline), so centre on the glyph's ink.
  FontMetrics { id: glyphMetrics }

  function glyphCenter(button) {
    var label = findItem(button, function(item) {
      return item !== button && item.text === button.text && item.baselineOffset !== undefined
    }, 0)
    if (!label) return button.mapToItem(root, button.width / 2, button.height / 2)
    glyphMetrics.font = label.font
    var ink = glyphMetrics.tightBoundingRect(label.text)
    var textLeft = (label.width - label.contentWidth) / 2
    return label.mapToItem(root, textLeft + ink.x + ink.width / 2, label.baselineOffset + ink.y + ink.height / 2)
  }

  function workspaceAt(from, x, y) {
    if (!findWorkspacesWidget()) return null
    var hit = null
    findItem(workspacesWidget, function(item) {
      if (item === workspacesWidget || typeof item.modelData !== "number" || !item.visible) return false
      var p = from.mapToItem(item, x, y)
      if (p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height) hit = { id: item.modelData, item: item }
      return hit !== null
    }, 0)
    return hit
  }

  // Same numbers the workspaces widget shows: 1-5 plus any others in use.
  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }

  function isMinimized(toplevel) {
    return !!(toplevel && toplevel.workspace && toplevel.workspace.name === minimizedWorkspace)
  }

  function title(toplevel) {
    return toplevel && toplevel.title ? toplevel.title : "Application"
  }

  // The window an entry acts for: the focused one, else the first that isn't
  // minimized, else the first.
  function primaryOf(windows) {
    for (var i = 0; i < windows.length; i++) {
      if (windows[i] === Hyprland.activeToplevel && !isMinimized(windows[i])) return windows[i]
    }
    for (var j = 0; j < windows.length; j++) if (!isMinimized(windows[j])) return windows[j]
    return windows.length > 0 ? windows[0] : null
  }

  // The one of these windows you used last (Super+Tab order).
  // Open Claude Code / Codex sessions: their own window class (Super+C C /
  // V V), or a terminal whose foreground program is the agent. For the
  // screenshot card's "Send to".
  // Open sessions of an agent (its own window class org.omarchy.<id>, or a
  // terminal running it). See ~/.config/omarchy/agents.
  function agentSessions(kind) {
    var list = []
    var cls = "org.omarchy." + String(kind).replace(/-/g, "_")
    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i]
      if (classOf(t) === cls || programOf(t) === kind)
        list.push({ address: hexAddress(t), title: TaskbarStatus.cleanTitle(title(t)), toplevel: t })
    }
    return list
  }

  // The installed coding agents, primaries first: [{id, name, primary}]
  // (~/.config/omarchy/agents list). Re-read when the settings window opens.
  property var agents: [{ id: "claude", name: "Claude", primary: true }, { id: "codex", name: "Codex", primary: true }]
  function reloadAgents() { if (!agentsProc.running) agentsProc.running = true }
  Process {
    id: agentsProc
    command: [root.omarchyDir + "/agents", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var list = JSON.parse(this.text)
          if (Array.isArray(list) && list.length > 0) root.agents = list
        } catch (e) { }
      }
    }
  }
  function agentName(id) {
    for (var i = 0; i < agents.length; i++) if (agents[i].id === id) return agents[i].name
    return id
  }

  function opensHere(group) {
    return !!group && hereApps.indexOf(group.key) !== -1
  }

  // The taskbar entry key a window groups under (as in `groups`).
  function groupKeyOf(toplevel) {
    var windowClass = classOf(toplevel)
    var icon = iconName(hexAddress(toplevel), windowClass)
    return icon === "app" || icon === "browser" ? icon + ":" + windowClass : icon
  }

  // The windows (not minimized) on the workspace you're looking at.
  function windowsHere(windows) {
    var here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    return windows.filter(function(w) { return !isMinimized(w) && w.workspace && w.workspace.id === here })
  }

  function setOpensHere(group, on) {
    var list = hereApps.filter(function(k) { return k !== group.key })
    if (on) list.push(group.key)
    Util.execArgv([omarchyDir + "/taskbar-setting", "set", "hereApps", JSON.stringify(list)])
  }

  function recentOf(windows) {
    var best = null
    var bestRank = 1e9
    for (var i = 0; i < windows.length; i++) {
      var rank = mru.indexOf(hexAddress(windows[i]))
      if (rank < 0) rank = 1e6 + i
      if (rank < bestRank) {
        best = windows[i]
        bestRank = rank
      }
    }
    return best
  }

  // "new" copies the first window's program and opens on the workspace that
  // holds all the windows (taskbar-action), so pass the whole group,
  // primary first.
  function newWindowArgs(windows) {
    var primary = primaryOf(windows)
    return primary ? [primary].concat(windows.filter(function(w) { return w !== primary })) : []
  }

  // Taskbar & Desktop > Icons > Taskbar and switcher: "line" (ours) or
  // "app" (each app's own colour icon; line where it has none).
  readonly property bool appIcons: pref("iconsTaskbar", "line") === "app"

  // An app's own icon (its launcher entry's), as an image URL, or "".
  function appIconFor(windowClass, desktopId) {
    var entry = null
    if (desktopId) entry = DesktopEntries.byId(String(desktopId).replace(/\.desktop$/, ""))
    if (!entry && windowClass) {
      // A web app (chrome-/msedge-/brave-<site>__...): the launcher that opens that site.
      var site = /^(?:chrome|msedge|brave|chromium)-([^_]+)__/i.exec(windowClass)
      if (site) {
        var apps = DesktopEntries.applications.values
        for (var i = 0; i < apps.length && !entry; i++) {
          if (String(apps[i].execString || "").indexOf("://" + site[1]) !== -1
              || String(apps[i].execString || "").indexOf("://www." + site[1]) !== -1) entry = apps[i]
        }
      }
      if (!entry) entry = DesktopEntries.heuristicLookup(windowClass)
    }
    return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
  }

  // The image for an icon: the app's own in "app" mode (when it has one),
  // else the line icon, in `color` or its colour (Icons > Line icon colours).
  function iconSource(name, appIcon, color) {
    return appIcons && appIcon ? appIcon : TaskbarIcons.svg(name, lineColor(name, color))
  }

  // Omarchy's app launcher (Super+Space) with line icons (Icons > App
  // launcher): a line icon file for every app that has one, named after the
  // app's own icon, in a folder the launcher's icon index reads first
  // (~/.config/omarchy/launcher-icons). Rewritten when the setting, the
  // colours, the theme or the installed apps change.
  readonly property bool launcherLineIcons: pref("iconsLauncher", "app") === "line"
  onLauncherLineIconsChanged: launcherIconsTimer.restart()
  onLauncherColorModeChanged: if (launcherLineIcons) launcherIconsTimer.restart()
  onIconColorsRevisionChanged: if (launcherLineIcons) launcherIconsTimer.restart()
  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { if (root.launcherLineIcons) launcherIconsTimer.restart() }
  }
  Timer {
    id: launcherIconsTimer
    interval: 2000
    onTriggered: root.writeLauncherIcons()
  }
  FileView {
    id: launcherIconsFile
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-launcher-icons.json"
    printErrors: false
    onSaved: Util.execArgv([root.omarchyDir + "/launcher-icons", "write", path])
  }
  function writeLauncherIcons() {
    if (!launcherLineIcons) {
      Util.execArgv([omarchyDir + "/launcher-icons", "off"])
      return
    }
    var apps = DesktopEntries.applications.values || []
    var fallback = String(Color.menu.text)
    var out = {}
    for (var i = 0; i < apps.length; i++) {
      var icon = String(apps[i].icon || "")
      // An icon given as a path is used as is by the launcher; only names can be replaced.
      if (!icon || icon.charAt(0) === "/" || out[icon] !== undefined) continue
      // Generic freedesktop names (applications-system, utilities-terminal...)
      // are shared by unrelated apps: leave those alone.
      if (/^(applications|utilities|preferences|system|accessories|help|user|x|text|image|audio|video|network|input|media|document|folder|emblem)-/.test(icon)) continue
      var name = TaskbarMatch.forEntry(apps[i])
      if (name) out[icon] = TaskbarIcons.markup(name, lineColor(name, fallback, launcherColorMode))
    }
    launcherIconsFile.setText(JSON.stringify(out))
  }

  // Line icon colours: "mono" (the theme's, as each place draws), "brand"
  // (each app's own) or "palette" (that, moved onto the theme). IconColors.js.
  // Set per place (Icons tab): iconColors<Place>, else the older single
  // iconColors, else "mono".
  function colorModeFor(place) {
    return String(pref("iconColors" + place, pref("iconColors", "mono")))
  }
  readonly property string iconColorMode: colorModeFor("Taskbar")
  readonly property string launcherColorMode: colorModeFor("Launcher")
  property int iconColorsRevision: 0
  function lineColor(name, fallback, mode) {
    var revision = iconColorsRevision
    return IconColors.colorFor(name, mode || iconColorMode, String(fallback))
  }
  FileView {
    path: root.omarchyDir + "/bar/modules/icon-colors.json"
    blockLoading: true
    printErrors: false
    onLoaded: {
      try { IconColors.setBrand(JSON.parse(text())) } catch (e) { }
      root.iconColorsRevision += 1
    }
  }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    blockLoading: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      IconColors.setPalette(text())
      root.iconColorsRevision += 1
    }
  }

  // The line icon for a launcher entry (the Super menu's line mode).
  function lineIconForEntry(entry) {
    var dependsOnUserRules = userPrograms && userClasses
    return TaskbarMatch.forEntry(entry)
  }

  function iconName(address, windowClass) {
    var dependsOnUserRules = userPrograms && userClasses
    return TaskbarMatch.forWindow(programByAddress[address] || "", windowClass)
  }

  // ---------------------------------------------------------------- events

  Component.onCompleted: {
    launcherIconsTimer.restart()
    reloadAgents()
    Hyprland.refreshToplevels()
    programScan.running = true
    if (Hyprland.activeToplevel) noteFocus(hexAddress(Hyprland.activeToplevel))
  }

  Process {
    id: programScan
    command: [root.omarchyDir + "/window-programs"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Only replace the map when it changed: a new map regroups the
        // taskbar, which rebuilds every entry mid-click or mid-drag.
        if (text === root.programsText) return
        root.programsText = text
        try { root.programByAddress = JSON.parse(text) } catch (e) {}
      }
    }
  }

  // Programs start and quit inside an existing window, which retitles it, so
  // rescan shortly after any window opens or closes, and at most every few
  // seconds on title changes (Claude's spinner retitles its window constantly).
  Timer {
    id: programScanDelay
    interval: 600
    onTriggered: programScan.running = true
  }

  // Each window's title without its leading symbols (see windowtitlev2).
  property var titleWords: ({})

  Timer {
    id: programScanThrottle
    interval: 3000
    onTriggered: programScan.running = true
  }

  // Keep each window's workspace current when minimize/restore moves it, fetch
  // a new window's class (it isn't known until the next refresh), and follow
  // focus, urgency and agent titles. Event data is the address without "0x".
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      var data = String(event.data || "")
      // Minimize/restore animation: read where the window is before the
      // refresh below replaces it.
      if (name === "movewindowv2") root.noteWindowMove(data)
      if (name === "movewindow" || name === "movewindowv2" || name === "openwindow") Hyprland.refreshToplevels()
      if (name === "openwindow" || name === "closewindow") programScanDelay.restart()

      // Window drags, from the dragevents plugin (see titlebars-load).
      if (name === "windowdragstart") {
        root.dragTiled = String(data).split(",")[1] === "1"
        root.setWindowDragging(true)
      } else if (name === "windowdragzone") {
        root.windowDragZone(data)
      } else if (name === "windowdragpos") {
        root.windowDragPos(data)
      } else if (name === "windowdragend") {
        root.windowDropped(data)
      } else if (name === "urgent" && data) {
        if (!root.isActiveAddress("0x" + data)) root.setAttention("0x" + data, true)
      } else if (name === "activewindowv2" && data && data !== ",") {
        root.setAttention("0x" + data, false)
        root.noteFocus("0x" + data)
        root.noteAppUse("0x" + data)
      } else if (name === "closewindow" && data) {
        root.forget("0x" + data)
      } else if (name === "windowtitlev2") {
        var comma = data.indexOf(",")
        if (comma > 0) {
          var address = "0x" + data.slice(0, comma)
          var title = data.slice(comma + 1)
          root.noteTitle(address, title)
          // A new program in a terminal retitles it; a spinner only changes
          // the symbols in front. Rescan (a process list, a few ms of CPU)
          // only when the words change, not a few times a second while an
          // agent works.
          var words = title.replace(/^[^A-Za-z0-9]+/, "")
          if (root.titleWords[address] !== words) {
            root.titleWords[address] = words
            if (!programScanThrottle.running) programScanThrottle.start()
          }
        }
      }
    }
  }

  // --------------------------------------------------------------- entries

  Row {
    id: tasks
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(root.showLabels ? 6 : root.iconSpacing)

    Repeater {
      model: root.groups

      Item {
        id: task
        required property var modelData
        readonly property var windows: modelData.windows
        readonly property int count: windows.length
        readonly property bool running: count > 0
        readonly property var activeWindow: {
          for (var i = 0; i < windows.length; i++) {
            if (windows[i] === Hyprland.activeToplevel && !root.isMinimized(windows[i])) return windows[i]
          }
          return null
        }
        readonly property bool active: activeWindow !== null
        readonly property bool minimized: {
          if (!running) return false
          for (var i = 0; i < windows.length; i++) if (!root.isMinimized(windows[i])) return false
          return true
        }
        // The window a single click acts on and whose title the entry shows.
        readonly property var primary: root.primaryOf(windows)
        readonly property int unread: {
          var total = 0
          for (var i = 0; i < windows.length; i++) total += root.unreadOf(windows[i])
          return total
        }
        readonly property bool needsYou: {
          for (var i = 0; i < windows.length; i++) if (root.wantsYou(windows[i])) return true
          return false
        }
        // The workspace this entry's windows are on when none is on the one
        // you're looking at and they're all together; 0 otherwise.
        readonly property int elsewhere: {
          var focused = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
          var id = 0
          for (var i = 0; i < windows.length; i++) {
            var ws = windows[i].workspace
            if (root.isMinimized(windows[i]) || !ws || ws.id < 0) continue
            if (ws.id === focused) return 0
            if (id !== 0 && id !== ws.id) return 0
            id = ws.id
          }
          return id
        }
        // Every workspace this entry has a (non-minimized) window on.
        readonly property var workspaceIds: {
          var ids = []
          for (var i = 0; i < windows.length; i++) {
            var ws = windows[i].workspace
            if (root.isMinimized(windows[i]) || !ws || ws.id <= 0 || ids.indexOf(ws.id) !== -1) continue
            ids.push(ws.id)
          }
          return ids
        }
        readonly property var audio: root.audioOf(windows)
        readonly property bool hovered: mouse.containsMouse
        readonly property string label: primary ? TaskbarStatus.cleanTitle(root.title(primary)) : modelData.name
        readonly property string tooltip: {
          if (!running) return modelData.name
          var text = count > 1 ? label + "  (" + count + " windows)" : label
          if (minimized) text += "  (minimized)"
          else if (elsewhere > 0) text += "  (workspace " + root.workspaceLabel(elsewhere) + ")"
          return text
        }
        // Scrolling steps from the last window it focused, not the (slightly
        // stale) active window, so fast scrolling doesn't repeat itself.
        property var scrollTarget: null
        // A double-click arrives on the second press, with the button still
        // down. Its action (tile / maximize) focuses windows, and Hyprland then
        // warps the pointer off the bar before the release, which stranded the
        // press and armed the hold-to-rearrange mode. So it waits for the
        // release (see the DragHandler), or a second at most.
        property bool pendingDouble: false
        // When this entry was last clicked (for Shift+click, see noteShiftClick).
        property real lastClickAt: 0

        // A click acts at once (no waiting to see if it's a double-click; a
        // double-click's maximize/tile just follows it).
        // One window: focus it. A group on one workspace: go there and focus
        // the one used last, or step to the next if you're already on one of
        // them. A group spread over workspaces (or minimized): the picker.
        function singleAction() {
          // "Bring to current workspace" apps (Files): their window here (a
          // click again steps through the ones here), else the one used last
          // comes here (from another workspace, or minimized), else a new one.
          if (root.opensHere(modelData)) {
            root.close()
            var here = root.windowsHere(windows)
            if (here.length === 0 && windows.length > 0) {
              root.runAction("here", [root.recentOf(windows)])
            } else if (here.length === 0) {
              root.runAction("newhere", root.newWindowArgs(windows))
            } else if (activeWindow && here.indexOf(activeWindow) !== -1) {
              if (here.length > 1) root.focusWindow(here[(here.indexOf(activeWindow) + 1) % here.length])
            } else {
              root.focusWindow(root.recentOf(here))
            }
            return
          }
          if (count > 1) {
            if (root.groupClick === "recent") {
              root.close()
              root.focusWindow(root.recentOf(windows))
              return
            }
            if (root.groupClick === "previews" || root.sharedWorkspace(windows) === -1) {
              root.togglePopup(modelData.key, task, "picker")
              return
            }
            root.close()
            if (active) root.cycle(task, 1)
            else root.focusWindow(root.recentOf(windows))
          } else {
            root.close()
            // Option clickActive "minimize": clicking the app you're in
            // minimizes it (Super+Up or another click brings it back).
            if (root.clickActiveMinimizes && primary === Hyprland.activeToplevel && !minimized) root.runAction("minimize", [primary])
            else root.focusWindow(primary)
          }
        }

        function newWindow() {
          root.shiftAt = 0
          root.shiftDoneAt = Date.now()
          root.runAction(root.opensHere(modelData) ? "newhere" : "new", root.newWindowArgs(windows))
        }

        property var mruAtClick: []

        function doubleAction() {
          pendingDouble = false
          releaseFallback.stop()
          // The window you were using before the double-click leads the tile
          // (biggest spot, focused).
          // "Bring to current workspace" apps: all of them come here.
          if (count > 1 && root.opensHere(modelData)) {
            root.runAction("here", root.byRecent(windows, mruAtClick), true)
          } else if (count > 1) {
            if (root.doubleClickGroup === "tile" || root.doubleClickGroup === "here")
              root.runAction(root.doubleClickGroup, root.byRecent(windows, mruAtClick), true)
          } else if (root.doubleClickWindow === "maximize") {
            root.runAction("maximize", [primary])
          }
        }

        Timer {
          id: releaseFallback
          interval: 1000
          onTriggered: if (task.pendingDouble) task.doubleAction()
        }
        property real wheelAccum: 0
        // A pinned program that was just clicked, until its window shows up.
        property bool launching: false

        // A window whose class isn't known yet (for a moment after it opens)
        // stays hidden until it becomes its real entry.
        visible: modelData.key !== "app:"

        // Icon-only buttons are a little wider than tall, like Windows'.
        width: root.showLabels
          ? Math.min(root.maxLabelWidth, content.implicitWidth + Style.space(3))
          : Math.max(Math.round(height * 1.25), root.iconSize + Style.space(8))
        height: root.barSize - Style.space(1)
        opacity: root.dragGroup && root.dragGroup.key === modelData.key ? 0.4 : (minimized ? 0.35 : 1)

        Behavior on opacity { NumberAnimation { duration: root.motionFast; easing.type: Easing.OutCubic } }

        onActiveWindowChanged: scrollTarget = null

        Timer {
          running: task.launching
          interval: 8000
          onTriggered: task.launching = false
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: root.foreground
          opacity: task.hovered || (root.popupOpen && root.popupKey === task.modelData.key)
            ? 0.12 : (task.active ? 0.07 : 0)

          Behavior on opacity { NumberAnimation { duration: root.motionFast; easing.type: Easing.OutCubic } }
        }

        // "Wants you": the entry glows in the accent colour, pulsing a few times
        // like a Windows taskbar flash, then stays tinted until you look.
        Rectangle {
          id: flash
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Color.accent
          opacity: 0

          function update() {
            if (task.needsYou && root.flashAttention) {
              fadeOut.stop()
              pulse.restart()
            } else {
              pulse.stop()
              fadeOut.restart()
            }
          }

          Component.onCompleted: if (task.needsYou && root.flashAttention) opacity = 0.16

          Connections {
            target: task
            function onNeedsYouChanged() { flash.update() }
          }

          SequentialAnimation {
            id: pulse
            SequentialAnimation {
              loops: 3
              NumberAnimation { target: flash; property: "opacity"; to: 0.34; duration: 200; easing.type: Easing.OutCubic }
              NumberAnimation { target: flash; property: "opacity"; to: 0.06; duration: 240; easing.type: Easing.InOutQuad }
            }
            NumberAnimation { target: flash; property: "opacity"; to: 0.16; duration: root.motionMove }
          }

          NumberAnimation { id: fadeOut; target: flash; property: "opacity"; to: 0; duration: root.motionMove }
        }

        // Playing sound: a pixel equalizer filling the button behind the icon
        // (Equalizer.qml; style from the equalizerStyle setting), in the accent
        // at low opacity. Muted: one flat, faint row. Right-click to mute.
        Equalizer {
          id: equalizer
          readonly property int cellSize: Math.max(2, Math.round(root.barSize * 0.075))
          pixel: cellSize
          gap: 1
          columns: Math.max(5, Math.floor((task.width - Style.space(4)) / (cellSize + 1)))
          rows: Math.max(4, Math.floor((task.height - Style.space(5)) / (cellSize + 1)))
          playing: root.audioMarks && task.audio.playing
          silent: task.audio.muted
          style: root.equalizerStyle
          visible: playing
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(3)
          opacity: silent ? 0.16 : 0.28

          Behavior on opacity { NumberAnimation { duration: root.motionMove } }
        }

        // Knockout halo in the bar's background behind the icon, so the icon's
        // lines stay crisp over the equalizer.
        Image {
          visible: equalizer.visible
          x: content.x + taskIcon.x
          y: content.y + taskIcon.y
          width: taskIcon.width
          height: taskIcon.height
          sourceSize.width: taskIcon.sourceSize.width
          sourceSize.height: taskIcon.sourceSize.height
          source: visible && !(root.appIcons && task.modelData.appIcon) ? TaskbarIcons.halo(task.modelData.icon, String(Color.bar.background), 5) : ""
          smooth: true
        }

        Row {
          id: content
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: root.showLabels ? parent.left : undefined
          anchors.leftMargin: Style.space(1.5)
          anchors.horizontalCenter: root.showLabels ? undefined : parent.horizontalCenter
          spacing: Style.space(1)

          Image {
            id: taskIcon
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize
            sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
            sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
            source: root.iconSource(task.modelData.icon, task.modelData.appIcon, String(task.active ? Color.accent : root.foreground))
            opacity: task.active ? 1 : 0.75
            smooth: true

            // A small press-and-spring when clicked.
            SequentialAnimation {
              id: clickSpring
              NumberAnimation { target: taskIcon; property: "scale"; to: 0.84; duration: 70; easing.type: Easing.OutQuad }
              NumberAnimation { target: taskIcon; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }

            // Breathes while a pinned program is starting.
            SequentialAnimation on scale {
              running: task.launching
              loops: Animation.Infinite
              NumberAnimation { to: 0.88; duration: 300; easing.type: Easing.InOutQuad }
              NumberAnimation { to: 1; duration: 300; easing.type: Easing.InOutQuad }
              onRunningChanged: if (!running) taskIcon.scale = 1
            }
          }

          Text {
            id: taskLabel
            visible: root.showLabels
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxLabelWidth - root.iconSize - Style.space(4))
            text: task.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.foreground
            opacity: task.active ? 1 : 0.75
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: task.minimized
          }
        }

        StatusBadge {
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: Style.space(1)
          anchors.rightMargin: Style.space(1)
          visible: root.showBadges
          unread: task.unread
          attention: task.needsYou
          fontFamily: root.fontFamily
          size: Math.round(root.iconSize * 0.42)
        }

        // One dot per window (up to four): the focused window's dot is wide and
        // takes the accent, minimized windows' dots are faint. A pinned program
        // that isn't running has none.
        Row {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 2

          Repeater {
            model: root.showDots ? Math.min(task.count, 4) : 0

            Rectangle {
              required property int index
              readonly property var win: task.windows[index]
              readonly property bool focused: win === Hyprland.activeToplevel && !root.isMinimized(win)

              width: focused ? Math.round(task.width * 0.4) : 4
              height: 2
              radius: 1
              color: focused ? Color.accent : root.foreground
              opacity: focused ? 1 : (root.isMinimized(win) ? 0.25 : 0.55)

              Behavior on width { NumberAnimation { duration: root.motionMove; easing.type: Easing.OutCubic } }
            }
          }
        }

        // Click: see singleAction(). Double-click: maximize a lone window / tile
        // a group on its own workspace. Drag onto a workspace number: move the
        // window(s) there. Right: menu. Middle or Shift+click: new window of
        // the same program.
        // (Focusing makes Hyprland warp the pointer onto the window;
        // taskbar-action focus puts it straight back, within a few ms, so a
        // double-click's second click still lands here.)

        // Drag onto a workspace number. The bar lays a module-reorder MouseArea
        // over every widget, so a MouseArea here never sees the press; a
        // DragHandler still does, and with a lower threshold than the bar's
        // (~5px) it takes the drag over before the bar starts moving the widget.
        // Press and hold first (holdTimer) and it steps aside, so the bar's own
        // drag rearranges the widget instead. (A modifier like Ctrl+drag can't
        // work: the bar never has keyboard focus, so it never sees modifiers.)
        DragHandler {
          id: dragHandler
          target: null
          acceptedButtons: Qt.LeftButton
          dragThreshold: 3
          // Armed: forbidden from taking the drag, but it keeps its passive grab,
          // so it still sees the release while the bar's drag moves the widget.
          grabPermissions: root.rearrangeArmed ? PointerHandler.TakeOverForbidden
            : (PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
               | PointerHandler.ApprovesTakeOverByAnything)
          onGrabChanged: function(transition, point) {
            if (transition === PointerDevice.GrabPassive) previewOpenDelay.stop()
            if (transition === PointerDevice.GrabPassive) {
              // A new press: forget any hold that ended in a drag (no click came).
              root.suppressClick = false
              holdTimer.restart()
            } else if (transition === PointerDevice.UngrabPassive || transition === PointerDevice.CancelGrabPassive
                       || transition === PointerDevice.UngrabExclusive || transition === PointerDevice.CancelGrabExclusive) {
              holdTimer.stop()
              root.rearrangeArmed = false
              if (task.pendingDouble) task.doubleAction()
            }
          }
          onActiveChanged: {
            if (active) holdTimer.stop()
            if (active) {
              root.close()
              if (root.bar) root.bar.hideTooltip(task)
              root.startDrag(task.modelData)
              root.dragMove(task, centroid.position.x, centroid.position.y)
            } else if (!active) {
              root.endDrag()
            }
          }
          onCentroidChanged: if (active) root.dragMove(task, centroid.position.x, centroid.position.y)
        }

        // Held still for a moment: arm rearranging (see DragHandler above).
        Timer {
          id: holdTimer
          interval: 450
          onTriggered: {
            // Only a real hold: the pointer is still here and this press isn't
            // the second half of a double-click.
            if (!mouse.containsMouse || task.pendingDouble) return
            root.rearrangeArmed = true
            if (root.bar) root.bar.hideTooltip(task)
          }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: Qt.PointingHandCursor

          onClicked: function(event) {
            // The release that ends a press-and-hold isn't a click.
            if (root.suppressClick && event.button === Qt.LeftButton) {
              root.suppressClick = false
              return
            }
            if (!root.bar) return
            root.bar.hideTooltip(task)
            if (!task.launching) clickSpring.restart()
            if (event.button === Qt.RightButton) {
              root.togglePopup(task.modelData.key, task, "menu")
            } else if (!task.running) {
              // A pinned program that isn't running: start it.
              task.launching = true
              root.launchGroup(task.modelData)
            } else if (event.button === Qt.MiddleButton || root.shiftPending()) {
              task.newWindow()
            } else {
              task.lastClickAt = Date.now()
              // A double-click starts with this click, which may already
              // switch windows; the tile then goes by the order from before it.
              task.mruAtClick = root.mru.slice()
              task.singleAction()
            }
          }
          // The bar's reorder layer turns the second click into a propagated
          // double-click rather than a second onClicked.
          onDoubleClicked: function(event) {
            if (event.button !== Qt.LeftButton || !task.running || root.suppressClick) return
            // Shift+double-click: the first click already opened a window.
            if (Date.now() - root.shiftDoneAt < 800) return
            holdTimer.stop()
            task.pendingDouble = true
            releaseFallback.restart()
          }
          // One step per wheel notch; touchpads add up to the same.
          onWheel: function(wheel) {
            wheel.accepted = true
            if (!task.running || !root.scrollCycles) return
            task.wheelAccum += wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
            while (Math.abs(task.wheelAccum) >= 120) {
              var step = task.wheelAccum > 0 ? -1 : 1
              task.wheelAccum += step * 120
              root.cycle(task, step)
            }
          }
          onEntered: {
            root.hoveredTask = task
            root.previewEnter(task)
            root.hoverWorkspaces = task.workspaceIds
            if (root.bar && !root.popupOpen && !root.dragGroup) root.bar.showTooltip(task, task.tooltip)
          }
          onExited: {
            holdTimer.stop()
            root.previewLeave(task)
            if (root.hoveredTask === task) root.hoveredTask = null
            root.hoverWorkspaces = []
            if (root.bar) root.bar.hideTooltip(task)
          }
        }

        // Remember where this entry sits, for its dissolve when it closes.
        onXChanged: root.lastEntryX[modelData.key] = x
        Component.onCompleted: {
          root.lastEntryX[modelData.key] = x
          if (root.entriesReady && root.motionEffects && !root.knownKeys[modelData.key] && modelData.key !== "app:") assemble.start()
        }

        // A new program's entry assembles out of pixels.
        PixelCover {
          id: assembleCover
          x: content.x + taskIcon.x
          y: content.y + taskIcon.y
          width: taskIcon.width
          height: taskIcon.height
          cell: Math.max(2, Math.round(root.iconSize / 8))
          visible: assemble.running
          z: 5
        }
        NumberAnimation {
          id: assemble
          target: assembleCover
          property: "progress"
          from: -0.1
          to: 1.1
          duration: 360
          easing.type: Easing.OutQuad
        }

        // Entries are rebuilt when windows come and go; don't leave a highlight
        // behind if that happens under the pointer.
        Component.onDestruction: {
          if (mouse.containsMouse) root.hoverWorkspaces = []
          if (root.hoveredTask === task) root.hoveredTask = null
        }
      }
    }
  }

  // Closed programs: their icon dissolves into pixels where it was, drifting
  // up a little as it goes.
  Repeater {
    model: root.ghosts

    Item {
      id: ghost
      required property var modelData
      readonly property real entryWidth: root.showLabels ? root.iconSize : Math.round((root.barSize - Style.space(1)) * 1.25)
      x: tasks.x + modelData.x + (entryWidth - root.iconSize) / 2
      y: (root.height - root.iconSize) / 2 - lift
      width: root.iconSize
      height: root.iconSize
      z: 97
      property real lift: 0

      Image {
        anchors.fill: parent
        sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
        sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
        source: TaskbarIcons.svg(ghost.modelData.icon, String(root.foreground))
        opacity: 0.75
      }

      PixelCover {
        id: dissolve
        anchors.fill: parent
        covering: true
        cell: Math.max(2, Math.round(root.iconSize / 8))
        coverColor: Color.bar.background
      }

      SequentialAnimation {
        running: true
        ParallelAnimation {
          NumberAnimation { target: dissolve; property: "progress"; from: -0.1; to: 1.1; duration: 380; easing.type: Easing.InQuad }
          NumberAnimation { target: ghost; property: "lift"; from: 0; to: 5; duration: 380; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: root.dropGhost(ghost.modelData.serial) }
      }
    }
  }

  // Hovering an entry: a soft accent circle behind each workspace number its
  // windows are on, in Omarchy's workspaces widget (drawn from here; the bar
  // doesn't clip).
  Repeater {
    model: root.dragGroup || !root.hoverWorkspacesEnabled ? [] : root.hoverWorkspaces

    Rectangle {
      required property int modelData
      // Looked up once (not as a binding: the lookup caches the widget).
      property Item target: null
      property point center: Qt.point(0, 0)
      readonly property real size: target ? Math.min(target.width, target.height) * 0.72 : 0

      visible: target !== null
      z: 98
      x: center.x - size / 2
      y: center.y - size / 2
      width: size
      height: size
      radius: size / 2
      color: Color.accent

      Component.onCompleted: {
        target = root.workspaceButton(modelData)
        if (target) center = root.glyphCenter(target)
      }

      NumberAnimation on opacity { from: 0; to: 0.3; duration: root.motionFast; easing.type: Easing.OutCubic }
    }
  }

  // A window is being dragged by its title bar: faint rings around the
  // workspace numbers say they take drops.
  Repeater {
    model: root.windowDragging ? root.workspaceIds() : []

    Rectangle {
      required property int modelData
      property Item target: null
      property point center: Qt.point(0, 0)
      readonly property real size: target ? Math.min(target.width, target.height) * 0.8 : 0

      visible: target !== null
      z: 98
      x: center.x - size / 2
      y: center.y - size / 2
      width: size
      height: size
      radius: size / 2
      color: "transparent"
      border.color: Color.accent
      border.width: 1.5

      Component.onCompleted: {
        target = root.workspaceButton(modelData)
        if (target) center = root.glyphCenter(target)
      }

      NumberAnimation on opacity { from: 0; to: 0.7; duration: root.motionFast; easing.type: Easing.OutCubic }
    }
  }

  // Press-and-hold feedback: the taskbar is outlined while it can be moved.
  Rectangle {
    visible: root.rearrangeArmed
    z: 99
    x: tasks.x - 2
    y: tasks.y - 2
    width: tasks.width + 4
    height: tasks.height + 4
    radius: Style.cornerRadius
    color: "transparent"
    border.color: Color.accent
    border.width: 2
  }

  // Reorder feedback: an accent line where the dragged entry would land.
  Rectangle {
    readonly property var entries: root.reorderIndex >= 0 ? root.taskEntries() : []
    readonly property real lineX: {
      if (entries.length === 0) return 0
      var gap = tasks.spacing / 2
      if (root.reorderIndex < entries.length) return tasks.x + entries[root.reorderIndex].x - gap
      var last = entries[entries.length - 1]
      return tasks.x + last.x + last.width + gap
    }

    visible: root.reorderIndex >= 0
    z: 100
    x: Math.round(lineX - width / 2)
    y: Math.round((root.height - height) / 2)
    width: 2
    height: Math.round(root.barSize * 0.6)
    radius: 1
    color: Color.accent
  }

  // Drag feedback: a ring around the workspace number under the cursor and the
  // icon following the cursor. Both draw outside this widget; the bar doesn't clip.
  Rectangle {
    readonly property rect area: root.dropItem
      ? root.dropItem.mapToItem(root, 0, 0, root.dropItem.width, root.dropItem.height)
      : Qt.rect(0, 0, 0, 0)
    visible: root.dropItem !== null
    z: 100
    x: area.x
    y: area.y
    width: area.width
    height: area.height
    radius: Style.cornerRadius
    color: "transparent"
    border.color: Color.accent
    border.width: 2
  }

  Image {
    visible: root.dragGroup !== null
    z: 101
    width: root.iconSize
    height: root.iconSize
    x: root.dragPos.x - width / 2
    y: root.dragPos.y - height / 2
    sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
    sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
    source: root.dragGroup ? root.iconSource(root.dragGroup.icon, root.dragGroup.appIcon, String(Color.accent)) : ""
    opacity: 0.85
  }

  // Drop animation. The move runs when the icon lands, so the workspace switch
  // happens with the pulse.
  Item {
    id: dropFx
    property var group: null
    property int workspace: -1
    property rect area: Qt.rect(0, 0, 0, 0)

    function play(group, workspace, from, area) {
      dropAnimation.stop()
      dropFx.group = group
      dropFx.workspace = workspace
      dropFx.area = area
      flyer.x = from.x - flyer.width / 2
      flyer.y = from.y - flyer.height / 2
      flyer.scale = 1
      flyer.opacity = 0.85
      pulse.scale = 0.5
      pulse.opacity = 0
      flyX.to = area.x + area.width / 2 - flyer.width / 2
      flyY.to = area.y + area.height / 2 - flyer.height / 2
      dropAnimation.start()
    }

    function land() {
      if (dropFx.group && dropFx.workspace > 0) root.runAction("move " + dropFx.workspace, dropFx.group.windows)
    }

    z: 102
    anchors.fill: parent
    visible: dropAnimation.running

    Image {
      id: flyer
      width: root.iconSize
      height: root.iconSize
      sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
      sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
      source: dropFx.group ? root.iconSource(dropFx.group.icon, dropFx.group.appIcon, String(Color.accent)) : ""
    }

    // A soft accent circle behind the number, sized to stay inside the bar.
    Rectangle {
      id: pulse
      readonly property real size: Math.min(dropFx.area.width, dropFx.area.height) * 0.7
      x: dropFx.area.x + (dropFx.area.width - size) / 2
      y: dropFx.area.y + (dropFx.area.height - size) / 2
      width: size
      height: size
      radius: size / 2
      color: Color.accent
      opacity: 0
    }

    SequentialAnimation {
      id: dropAnimation

      ParallelAnimation {
        NumberAnimation { id: flyX; target: flyer; property: "x"; duration: root.motionMove; easing.type: Easing.InCubic }
        NumberAnimation { id: flyY; target: flyer; property: "y"; duration: root.motionMove; easing.type: Easing.InCubic }
        NumberAnimation { target: flyer; property: "scale"; to: 0.35; duration: root.motionMove; easing.type: Easing.InCubic }
        NumberAnimation { target: flyer; property: "opacity"; to: 0.4; duration: root.motionMove }
      }
      ScriptAction { script: dropFx.land() }
      ParallelAnimation {
        NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: root.motionFast }
        NumberAnimation { target: pulse; property: "opacity"; from: 0.45; to: 0; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: pulse; property: "scale"; from: 0.6; to: 1.2; duration: 280; easing.type: Easing.OutCubic }
      }
    }
  }

  // ----------------------------------------------------------- popup card

  // Picker (a group's windows as live cards) or right-click menu.
  PopupCard {
    id: popup

    readonly property int cardWidth: root.pickerThumbWidth + Style.space(6) * 2
    readonly property int pickerColumns: Math.max(1, Math.min(root.popupGroup ? root.popupGroup.windows.length : 1, 3))
    readonly property int pickerWidth: pickerColumns * cardWidth + (pickerColumns - 1) * Style.space(8)
    readonly property int insets: popup.padding * 2 + Border.left(popup.borderSpec) + Border.right(popup.borderSpec)

    anchorItem: root.popupAnchor || root
    triggerMode: root.hoverPreview ? "hover" : "click"
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(root.popupMode === "menu" ? Style.space(260) : pickerWidth + insets)
    contentHeight: popup.fittedContentHeight(root.popupMode === "menu" ? menuColumn.implicitHeight : pickerCards.implicitHeight)

    Flow {
      id: pickerCards
      visible: root.popupMode === "picker"
      width: parent.width
      spacing: Style.space(8)

      Repeater {
        model: root.popupMode === "picker" && root.popupGroup ? root.popupGroup.windows : []

        WindowCard {
          id: pickerCard
          required property var modelData
          readonly property var info: root.windowInfo(modelData)

          toplevel: modelData
          thumbWidth: root.pickerThumbWidth
          icon: info.icon
          appIcon: info.appIcon
          iconColor: info.iconColor
          active: !info.minimized && modelData === Hyprland.activeToplevel
          minimized: info.minimized
          place: info.place
          agent: info.agent
          attention: info.attention
          unread: info.unread
          live: root.popupOpen
          textColor: Color.popups.text
          fontFamily: root.fontFamily
          // "Bring to current workspace" apps: the window comes here.
          onActivated: {
            var bring = root.opensHere(root.popupGroup)
            root.close()
            if (bring) root.runAction("here", [modelData])
            else root.focusWindow(modelData)
          }
          onCloseRequested: root.closeWindow(modelData)
          // Drag a card onto a workspace number to move that window there.
          draggable: true
          onDragStarted: root.startWindowDrag(modelData)
          onDragMoved: function(x, y) { root.dragMoveTo(root.fromPopup(pickerCard, x, y)) }
          onDragEnded: root.endDrag()
        }
      }
    }

    Column {
      id: menuColumn
      visible: root.popupMode === "menu"
      width: parent.width
      spacing: Style.space(1)

      Repeater {
        model: root.menuItems

        Item {
          id: item
          required property var modelData
          readonly property bool clickable: !!modelData.action

          width: menuColumn.width
          height: modelData.kind === "separator" ? Style.space(9)
            : modelData.kind === "workspaces" ? chipsColumn.implicitHeight + Style.space(8)
            : Style.spacing.popupRowHeight

          Rectangle {
            visible: item.modelData.kind === "separator"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            height: 1
            color: Color.popups.text
            opacity: 0.15
          }

          Rectangle {
            visible: item.clickable
            anchors.fill: parent
            radius: Style.cornerRadius
            color: item.modelData.danger ? Color.urgent : Color.popups.text
            opacity: itemMouse.containsMouse ? (item.modelData.danger ? 0.35 : 0.12) : 0
          }

          Row {
            visible: item.modelData.kind !== "separator" && item.modelData.kind !== "workspaces"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(10)

            Text {
              visible: item.clickable
              anchors.verticalCenter: parent.verticalCenter
              width: Style.font.iconLarge
              horizontalAlignment: Text.AlignHCenter
              text: item.modelData.glyph || ""
              color: item.modelData.danger ? Color.urgent : Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - (item.clickable ? Style.font.iconLarge + parent.spacing : 0)
              text: item.modelData.label || ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: item.modelData.danger ? Color.urgent : Color.popups.text
              opacity: item.clickable ? 1 : 0.6
              font.family: root.fontFamily
              font.pixelSize: item.clickable ? Style.font.body : Style.font.bodySmall
              font.bold: !item.clickable
            }
          }

          // "Move to workspace": one chip per workspace, plus "+" for an empty one.
          // The workspace the windows are already on is dimmed; the focused one
          // is outlined.
          Column {
            id: chipsColumn
            visible: item.modelData.kind === "workspaces"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              text: item.modelData.label || ""
              color: Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Flow {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                // Moving offers "+" (an empty workspace); pinning names a
                // number, and lists the pinned one even if it's not in use.
                model: {
                  if (item.modelData.kind !== "workspaces") return []
                  var ids = root.workspaceIds()
                  if (item.modelData.mode !== "pin") return ids.concat(["empty"])
                  var pinned = item.modelData.current
                  if (pinned > 0 && ids.indexOf(pinned) === -1) ids = ids.concat([pinned]).sort(function(a, b) { return a - b })
                  return ids
                }

                Rectangle {
                  id: chip
                  required property var modelData
                  readonly property bool isEmpty: modelData === "empty"
                  readonly property bool pinMode: item.modelData.mode === "pin"
                  readonly property bool here: !isEmpty && modelData === item.modelData.current
                  readonly property bool focused: !isEmpty && Hyprland.focusedWorkspace !== null
                    && Hyprland.focusedWorkspace.id === modelData
                  // Moving: the current workspace is dimmed and inert. Pinning:
                  // the pinned one is filled, and clicking it unpins (shows ×).
                  readonly property bool filled: pinMode ? here || chipMouse.containsMouse : chipMouse.containsMouse && !here

                  width: Style.space(26)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  color: filled ? Color.accent : "transparent"
                  border.width: 1
                  border.color: focused || (pinMode && here) ? Color.accent : Color.popups.text
                  opacity: here && !pinMode ? 0.3 : (chipMouse.containsMouse || focused || here ? 1 : 0.6)

                  Text {
                    anchors.centerIn: parent
                    text: chip.isEmpty ? "+"
                      : (chip.pinMode && chip.here && chipMouse.containsMouse ? "\u00d7" : root.workspaceLabel(chip.modelData))
                    color: chip.filled ? Color.background : Color.popups.text
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    enabled: chip.pinMode || !chip.here
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (chip.pinMode) root.pinToWorkspace(root.popupGroup, chip.modelData)
                      else root.runAction("move " + chip.modelData, item.modelData.windows)
                    }
                  }
                }
              }
            }
          }

          MouseArea {
            id: itemMouse
            visible: item.clickable
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.runMenuItem(item.modelData, root.popupGroup)
          }
        }
      }
    }
  }
}
