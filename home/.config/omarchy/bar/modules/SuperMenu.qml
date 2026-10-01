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
//             right-click a tile for pin / unpin / move to a group
//   Folders   pin one from search (right-click a folder row, or Ctrl+P): a
//             tile like an app's, in Pinned or a group ("folder:<path>" among
//             the ids); its right-click menu sets what Click / Shift+click /
//             Ctrl+click (or Enter with those) do for that folder alone
//             ("folderActions" in supermenu.json; else the folder settings)
//   Groups    named blocks for tasks, anywhere on the grid with Pinned
//             ("groups": [{name, apps, x, y, cells}], "pinnedLayout"). Each
//             tile stays in the cell it's dropped in ("cells": {id: [column,
//             row]}), and a block is just what its tiles cover: drop on an
//             empty cell to move there, on a tile to swap, just past a
//             block's right, bottom or left edge to grow it, in open space
//             for a new group. A block that grows into one below pushes it
//             down; a group left empty goes. Drag a title to move a block;
//             ⋯ renames or deletes a group (its apps go back to Pinned) and
//             shades it (any block): a soft fill in one of the theme's colours,
//             saved by name ("shade": "blue"), so a new theme recolours it
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
  // as rows under the apps, each marked if it's in a git repo (with its
  // branch). Looked up a moment after typing stops; nothing without zoxide.
  // Opening one tells zoxide, so the menu teaches it too.
  property var folderResults: []
  property string folderQuery: ""
  Timer {
    id: folderSearch
    interval: 120
    onTriggered: {
      var q = menu.query.trim()
      if (q.length < 2) { menu.folderResults = []; return }
      folderProc.forQuery = q
      // path<TAB>branch<TAB>kind (~/.config/omarchy/folder-search).
      folderProc.command = [taskbar.omarchyDir + "/folder-search"].concat(q.split(/\s+/))
      folderProc.running = true
    }
  }
  Process {
    id: folderProc
    property string forQuery: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = this.text.split("\n").filter(function(l) { return l !== "" })
        menu.folderQuery = folderProc.forQuery
        menu.folderResults = lines.map(function(line) { return menu.folderRow(line) })
      }
    }
  }

  // A folder-search line as a folder: its search row (kind "folder") and,
  // with its id "folder:<path>", what a pinned tile of it shows.
  function folderRow(line) {
    var home = Quickshell.env("HOME")
    var f = line.split("\t")
    var p = f[0], branch = f[1] || "", kind = f[2] || "", repos = parseInt(f[3], 10) || 0
    var cut = p.lastIndexOf("/")
    var parent = p.slice(0, cut) || "/"
    var where = parent.indexOf(home) === 0 ? "~" + parent.slice(home.length) : parent
    // The project's icon, else git's if it's a repo, else a folder of
    // repos', else a folder; a repo's branch (or how many repos it holds)
    // follows the place.
    return { kind: "folder", folder: true, id: "folder:" + p, name: p.slice(cut + 1), label: p.slice(cut + 1), path: p,
             git: branch !== "", repos: repos, project: kind, missing: f[3] === "missing",
             glyph: menu.projectGlyphs[kind] || (branch !== "" ? "" : repos > 0 ? "" : ""),
             detail: branch !== "" ? where + "     " + (branch === "-" ? "detached" : branch)
                   : repos > 0 ? where + "    " + repos + (repos === 1 ? " repo" : " repos") : where }
  }

  // Pinned folders: what each is (repo, project, ...), looked up when the
  // menu opens. Until then (or if it's gone) a plain folder.
  property var folderInfo: ({})
  readonly property var pinnedFolderPaths: groupedIds.filter(function(id) { return id.indexOf("folder:") === 0 })
    .map(function(id) { return id.slice(7) })
  function refreshFolderInfo() {
    if (pinnedFolderPaths.length === 0 || folderInfoProc.running) return
    folderInfoProc.command = [taskbar.omarchyDir + "/folder-search", "--info"].concat(pinnedFolderPaths)
    folderInfoProc.running = true
  }
  onPinnedFolderPathsChanged: if (opened) refreshFolderInfo()
  Process {
    id: folderInfoProc
    stdout: StdioCollector {
      onStreamFinished: {
        var next = {}
        this.text.split("\n").forEach(function(line) {
          if (line === "") return
          var row = menu.folderRow(line)
          next[row.path] = row
        })
        menu.folderInfo = next
      }
    }
  }
  function folderEntry(path) {
    return folderInfo[path] || folderRow(path + "\t\t\t0")
  }

  // An app's name, or a folder's.
  function entryName(e) {
    if (!e) return ""
    if (e.folder) return e.name
    return library ? library.entryName(e) : String(e.name || "")
  }


  // What Enter / Shift+Enter / Ctrl+Enter (or click, with the same keys) do
  // on a folder row (settings superMenuFolderEnter/Shift/Ctrl).
  // Nerd Font icons for folder-search's project kinds.
  readonly property var projectGlyphs: ({ python: "\ue73c", rust: "\ue7a8", go: "\ue627", typescript: "\ue628", node: "\ue718",
    deno: "\ue718", ruby: "\ue739", php: "\ue73d", java: "\ue738", dotnet: "\udb80\udf1b", elixir: "\ue62d", dart: "\ue798",
    cpp: "\ue61d", nix: "\uf313", docker: "\uf308" })

  // "smart": the agent in a git repo or a folder of repos, Files elsewhere.
  readonly property var folderActionNames: ({ smart: "Smart", files: "Files", terminal: "Terminal", agent: "Agent", editor: "Editor", copy: "Copy path" })
  // The action for a key on a folder: its own (a pinned folder's, set from
  // its right-click menu), else the folder settings'; smart resolved by
  // whether it's a repo (or holds some).
  property var folderActions: ({})
  function globalFolderAction(how) {
    var key = how === "ctrl" ? "superMenuFolderCtrl" : how === "shift" ? "superMenuFolderShift" : "superMenuFolderEnter"
    var fallback = how === "ctrl" ? "files" : how === "shift" ? "terminal" : "smart"
    var v = String(taskbar.pref(key, fallback))
    return folderActionNames[v] ? v : fallback
  }
  function ownFolderAction(row, how) {
    var own = row && folderActions[row.path] ? folderActions[row.path][how] : ""
    return own && folderActionNames[own] ? own : ""
  }
  function folderAction(how, row) {
    var v = ownFolderAction(row, how) || globalFolderAction(how)
    return v === "smart" ? (row && (row.git || row.repos > 0) ? "agent" : "files") : v
  }
  // Step a folder's own action for a key: default (the settings'), smart,
  // files, terminal, agent, editor, copy, then back to default.
  readonly property var folderActionOrder: ["", "smart", "files", "terminal", "agent", "editor", "copy"]
  function cycleFolderAction(row, how) {
    var cur = ownFolderAction(row, how)
    var next = folderActionOrder[(folderActionOrder.indexOf(cur) + 1) % folderActionOrder.length]
    var all = Object.assign({}, folderActions)
    var mine = Object.assign({}, all[row.path] || {})
    if (next === "") delete mine[how]
    else mine[how] = next
    if (Object.keys(mine).length) all[row.path] = mine
    else delete all[row.path]
    folderActions = all
    saveConfig()
  }
  function folderActionText(a) {
    return a === "smart" ? "Agent for repos, else Files" : a === "agent" && askAgents.length ? askAgents[0].name
      : a === "files" ? "Files" : a === "terminal" ? "Terminal" : a === "editor" ? "Editor" : a === "copy" ? "Copy path" : a
  }
  // "Click: Terminal" / "Click: default (Files)", for the tile menu.
  function folderActionLine(row, how) {
    var key = how === "ctrl" ? "Ctrl+click" : how === "shift" ? "Shift+click" : "Click"
    var own = ownFolderAction(row, how)
    return key + ":  " + (own ? folderActionText(own) : "default (" + folderActionText(globalFolderAction(how)) + ")")
  }
  function folderActionLabel(how, row) {
    var a = folderAction(how, row)
    return a === "agent" && askAgents.length ? askAgents[0].name : folderActionNames[a]
  }
  function folderHint(row) {
    return "Enter: " + folderActionLabel("enter", row) + " · Shift+Enter: " + folderActionLabel("shift", row)
      + " · Ctrl+Enter: " + folderActionLabel("ctrl", row)
  }
  function openFolderRow(r, how) {
    var a = folderAction(how, r)
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
        menu.pinnedLayout = data.pinnedLayout || null
        menu.folderActions = data.folderActions && typeof data.folderActions === "object" ? data.folderActions : ({})
        menu.groups = Array.isArray(data.groups) ? data.groups.filter(function(g) { return g && typeof g.name === "string" })
          .map(function(g) { return { name: g.name, apps: Array.isArray(g.apps) ? g.apps : [], x: g.x, y: g.y, w: g.w, cells: g.cells || null, shade: g.shade || "", icons: g.icons || "" } }) : []
      } catch (e) {
        menu.pinnedIds = []
        menu.hiddenFrequent = []
        menu.groups = []
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
    if (String(id).indexOf("folder:") === 0) return folderEntry(String(id).slice(7))
    for (var i = 0; i < allEntries.length; i++) if (allEntries[i].id === id) return allEntries[i]
    return null
  }

  // ---------------------------------------------------------- sections
  // Section 0 is Pinned, then the groups: blocks on a grid `columns` tiles
  // wide. A block sits at its place (x, y, in tiles) and each of its tiles in
  // its own cell of it (cells: {id: [column, row]}); the block's size is
  // what its tiles cover. Ids with no app behind them (uninstalled for now)
  // keep their cell but aren't shown.
  property var groups: []            // [{ name, apps, x, y, cells }]
  property var pinnedLayout: null    // Pinned's { x, y, cells }
  property int renaming: -1          // the section whose name is being edited
  readonly property int tileGap: Style.space(6)
  readonly property int bandHeight: Style.space(24)   // a block's title bar (and between its rows)
  readonly property real colPitch: tileWidth + tileGap
  readonly property real rowPitch: tileHeight + bandHeight

  readonly property var sections: {
    var pl = pinnedLayout || {}
    return [{ name: "Pinned", ids: pinnedIds, group: false, x: pl.x, y: pl.y, w: pl.w, cells: pl.cells || null, shade: pl.shade || "", icons: pl.icons || "" }]
      .concat(groups.map(function(g) { return { name: g.name, ids: g.apps, group: true, x: g.x, y: g.y, w: g.w, cells: g.cells, shade: g.shade || "", icons: g.icons || "" } }))
  }

  // Each section's shown tiles at their cells, in reading order:
  // [{ entry, c, r }]. A tile with no cell of its own (or one taken) takes
  // the next free one, in rows as wide as the block was before cells (an
  // older layout's width; Pinned: the grid's).
  readonly property var sectionTiles: sections.map(function(sec, i) {
    var wrap = Math.max(1, Math.min(columns, Math.round(sec.w) || (i === 0 ? columns : 3)))
    var taken = {}, out = [], pending = []
    for (var k = 0; k < sec.ids.length; k++) {
      var entry = entryById(sec.ids[k])
      if (!entry) continue
      var cell = sec.cells ? sec.cells[sec.ids[k]] : null
      var key = cell ? cell[0] + "," + cell[1] : ""
      if (cell && cell[0] >= 0 && cell[1] >= 0 && cell[0] < columns && !taken[key]) {
        taken[key] = true
        out.push({ entry: entry, c: cell[0], r: cell[1] })
      } else pending.push(entry)
    }
    var at = 0
    pending.forEach(function(entry) {
      while (taken[(at % wrap) + "," + Math.floor(at / wrap)]) at++
      taken[(at % wrap) + "," + Math.floor(at / wrap)] = true
      out.push({ entry: entry, c: at % wrap, r: Math.floor(at / wrap) })
    })
    out.sort(function(a, b) { return a.r - b.r || a.c - b.c })
    return out
  })

  readonly property var sectionEntries: sectionTiles.map(function(t) { return t.map(function(x) { return x.entry }) })

  // ------------------------------------------------------------- layout
  function validRect(r) {
    return !!r && r.w >= 1 && r.h >= 1 && r.x >= 0 && r.y >= 0 && r.x + r.w <= columns
  }
  function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
  }
  // Inside the grid and over no other block (skip: one to ignore, itself).
  function fits(rect, placed, skip) {
    if (!validRect(rect)) return false
    for (var i = 0; i < placed.length; i++) if (i !== skip && placed[i] && overlaps(rect, placed[i])) return false
    return true
  }
  function firstSpot(w, h, placed) {
    for (var y = 0; y < 200; y++)
      for (var x = 0; x + w <= columns; x++) {
        var r = { x: x, y: y, w: w, h: h }
        if (fits(r, placed, -1)) return r
      }
    return { x: 0, y: 200, w: w, h: h }
  }

  // A block's size: what its tiles cover (an empty group: one cell).
  function extentOf(i) {
    var w = 1, h = 1
    ;(sectionTiles[i] || []).forEach(function(t) { w = Math.max(w, t.c + 1); h = Math.max(h, t.r + 1) })
    return { w: Math.min(w, columns), h: h }
  }

  // Where each block is: its saved place, its size from its tiles. Blocks
  // are placed top to bottom; one that would overlap an earlier one moves
  // down until it doesn't. One without a place takes the first free spot.
  readonly property var layouts: {
    var sized = sections.map(function(sec, i) {
      var ext = extentOf(i)
      var has = typeof sec.x === "number" && typeof sec.y === "number" && sec.x >= 0 && sec.y >= 0
      return { x: has ? Math.min(Math.round(sec.x), columns - ext.w) : -1, y: has ? Math.round(sec.y) : -1,
               w: ext.w, h: ext.h, has: has }
    })
    var placed = new Array(sized.length)
    var done = []
    sized.map(function(r, i) { return i }).filter(function(i) { return sized[i].has })
      .sort(function(a, b) { return sized[a].y - sized[b].y || sized[a].x - sized[b].x })
      .forEach(function(i) {
        var r = { x: sized[i].x, y: sized[i].y, w: sized[i].w, h: sized[i].h }
        for (var guard = 0; guard < 300 && !fits(r, done, -1); guard++) r.y++
        placed[i] = r
        done.push(r)
      })
    for (var i = 0; i < sized.length; i++) {
      if (placed[i]) continue
      placed[i] = firstSpot(sized[i].w, sized[i].h, done)
      done.push(placed[i])
    }
    return placed
  }
  readonly property int gridRows: layouts.reduce(function(m, r) { return Math.max(m, r.y + r.h) }, 0)

  function shownCount(sec) {
    return sectionEntries[sec] ? sectionEntries[sec].length : 0
  }

  // Where each block's tiles start among all the tiles shown.
  readonly property var sectionOffsets: {
    var out = [], at = 0
    for (var i = 0; i < sections.length; i++) {
      out.push(at)
      at += shownCount(i)
    }
    return out
  }

  // Every tile the blocks show, in order (then Frequent follows).
  readonly property var pinnedEntries: {
    var list = []
    for (var i = 0; i < sections.length; i++) list = list.concat(sectionEntries[i] || [])
    return list
  }

  // Each shown tile's cell on the grid (Frequent's rows after the blocks),
  // for the arrow keys.
  readonly property var tileCells: {
    var cells = []
    for (var i = 0; i < sections.length; i++) {
      var L = layouts[i]
      if (!L) continue
      ;(sectionTiles[i] || []).forEach(function(t) { cells.push({ c: L.x + t.c, r: L.y + t.r }) })
    }
    for (var f = 0; f < frequentEntries.length; f++) cells.push({ c: f % columns, r: gridRows + 1 + Math.floor(f / columns) })
    return cells
  }

  // Every app in Pinned or a group.
  readonly property var groupedIds: {
    var all = pinnedIds.slice()
    for (var i = 0; i < groups.length; i++) all = all.concat(groups[i].apps)
    return all
  }

  // The section and position of a shown tile (flat index), or null.
  function locate(flat) {
    for (var i = sections.length - 1; i >= 0; i--) {
      var at = flat - sectionOffsets[i]
      if (at >= 0 && at < shownCount(i)) return { sec: i, idx: at }
    }
    return null
  }

  function sectionOf(id) {
    if (pinnedIds.indexOf(id) !== -1) return 0
    for (var i = 0; i < groups.length; i++) if (groups[i].apps.indexOf(id) !== -1) return i + 1
    return -1
  }

  // Select an app's tile (after it's moved).
  function selectId(id) {
    var flat = pinnedEntries.map(function(e) { return e.id }).indexOf(id)
    if (flat >= 0) selected = flat
  }

  // ------------------------------------------------- changing the blocks
  // Every section as it is now, written out (places, cells), to change and
  // then commit.
  function snapshot() {
    var all = layouts
    return sections.map(function(sec, i) {
      var cells = {}
      ;(sectionTiles[i] || []).forEach(function(t) { cells[t.entry.id] = [t.c, t.r] })
      sec.ids.forEach(function(id) { if (!cells[id] && sec.cells && sec.cells[id]) cells[id] = sec.cells[id] })
      return { name: sec.name, ids: sec.ids.slice(), x: all[i].x, y: all[i].y, cells: cells, shade: sec.shade || "", icons: sec.icons || "" }
    })
  }
  function commit(secs) {
    pinnedIds = secs[0].ids
    pinnedLayout = { x: secs[0].x, y: secs[0].y, cells: secs[0].cells }
    if (secs[0].shade) pinnedLayout.shade = secs[0].shade
    if (secs[0].icons) pinnedLayout.icons = secs[0].icons
    groups = secs.slice(1).map(function(sec) {
      var g = { name: sec.name, apps: sec.ids, x: sec.x, y: sec.y, cells: sec.cells }
      if (sec.shade) g.shade = sec.shade
      if (sec.icons) g.icons = sec.icons
      return g
    })
    saveConfig()
  }
  // Shift a section's cells so its top-left tile is at 0,0, moving the block
  // by as much (so nothing moves on screen).
  function normalize(sec) {
    var ids = Object.keys(sec.cells)
    if (!ids.length) return
    var mc = 1e9, mr = 1e9
    ids.forEach(function(id) { mc = Math.min(mc, sec.cells[id][0]); mr = Math.min(mr, sec.cells[id][1]) })
    if (mc === 0 && mr === 0) return
    ids.forEach(function(id) { sec.cells[id] = [sec.cells[id][0] - mc, sec.cells[id][1] - mr] })
    sec.x += mc
    sec.y += mr
  }
  function cellAt(sec, c, r) {
    for (var id in sec.cells) if (sec.cells[id][0] === c && sec.cells[id][1] === r) return id
    return null
  }
  // The first free cell in reading order from a position, rows `wrap` wide.
  function freeCell(sec, wrap, from) {
    for (var at = from || 0; at < 10000; at++) {
      var c = at % wrap, r = Math.floor(at / wrap)
      if (!cellAt(sec, c, r)) return [c, r]
    }
    return [0, 0]
  }
  function widthOf(sec) {
    var w = 0
    for (var id in sec.cells) w = Math.max(w, sec.cells[id][0] + 1)
    return w
  }
  // Take an app out of a section (secs: a snapshot); a group it leaves
  // empty goes. Returns the index its removal shifts the groups by (1 if a
  // group before `watch` went, else 0).
  function takeOut(secs, id, watch) {
    var from = -1
    for (var i = 0; i < secs.length; i++) if (secs[i].ids.indexOf(id) !== -1) from = i
    if (from < 0) return 0
    secs[from].ids = secs[from].ids.filter(function(x) { return x !== id })
    delete secs[from].cells[id]
    normalize(secs[from])
    if (from >= 1 && secs[from].ids.length === 0 && from !== watch) {
      secs.splice(from, 1)
      return from < watch ? 1 : 0
    }
    return 0
  }

  // Put an app at a cell of a section (relative to its top-left; one past
  // its right, bottom or left edge grows it), from wherever it was. A tile
  // already there swaps places with it (from the same section) or moves to
  // the next free cell.
  function moveTileTo(id, toSec, c, r) {
    var secs = snapshot()
    var fromSec = sectionOf(id)
    var old = fromSec === toSec && secs[toSec].cells[id] ? secs[toSec].cells[id].slice() : null
    if (fromSec === toSec) {
      delete secs[toSec].cells[id]
    } else {
      toSec -= takeOut(secs, id, toSec)
    }
    var t = secs[toSec]
    if (c < 0) {
      for (var k in t.cells) t.cells[k] = [t.cells[k][0] - c, t.cells[k][1]]
      t.x += c
      if (old) old = [old[0] - c, old[1]]
      c = 0
    }
    var there = cellAt(t, c, r)
    t.cells[id] = [c, r]
    if (t.ids.indexOf(id) === -1) t.ids.push(id)
    if (there) {
      if (old) t.cells[there] = old
      else {
        delete t.cells[there]
        var w = Math.max(1, widthOf(t))
        t.cells[there] = freeCell(t, w, r * w + c + 1)
      }
    }
    normalize(t)
    commit(secs)
    selectId(id)
  }

  // Onto the end of a section: the first free cell, in rows as wide as it
  // is (at least 3, if there's room).
  function appendTo(id, toSec) {
    var secs = snapshot()
    var t = secs[toSec]
    var wrap = Math.max(1, Math.min(columns - t.x, Math.max(widthOf(t), 3)))
    var cell = Object.keys(t.cells).length === 0 ? [0, 0] : freeCell(t, wrap, 0)
    moveTileTo(id, toSec, cell[0], cell[1])
  }

  // Unpin: out of its section.
  function removeTile(id) {
    var secs = snapshot()
    takeOut(secs, id, -1)
    commit(secs)
  }

  // A block's new place (every block's place saved with it).
  function setLayout(sec, rect) {
    var secs = snapshot()
    secs[sec].x = rect.x
    secs[sec].y = rect.y
    commit(secs)
  }

  // Moving a block by dragging its title: which, and the outline of where it
  // would go (ok: it fits there).
  property string blockAction: ""
  property int blockSection: -1
  property var blockGhost: null
  property point blockGrab: Qt.point(0, 0)
  function startBlock(sec, action, scenePoint) {
    var p = blockCanvas.mapFromItem(null, scenePoint.x, scenePoint.y)
    var L = layouts[sec]
    blockAction = action
    blockSection = sec
    blockGrab = Qt.point(p.x - L.x * colPitch, p.y - L.y * rowPitch)
    updateBlock(scenePoint)
  }
  function updateBlock(scenePoint) {
    if (blockAction === "") return
    var p = blockCanvas.mapFromItem(null, scenePoint.x, scenePoint.y)
    var L = layouts[blockSection]
    var r = { x: Math.max(0, Math.min(columns - L.w, Math.round((p.x - blockGrab.x) / colPitch))),
              y: Math.max(0, Math.round((p.y - blockGrab.y) / rowPitch)), w: L.w, h: L.h }
    r.ok = fits(r, layouts, blockSection)
    blockGhost = r
  }
  function endBlock() {
    var g = blockGhost, sec = blockSection
    blockAction = ""
    blockSection = -1
    blockGhost = null
    if (g && g.ok) setLayout(sec, g)
  }

  // A new group at a cell of the grid (an app dropped there), named by typing.
  function newGroupAt(x, y, withId, name) {
    var secs = snapshot()
    if (withId) takeOut(secs, withId, -1)
    var cells = {}
    if (withId) cells[withId] = [0, 0]
    secs.push({ name: name || "New group", ids: withId ? [withId] : [], x: x, y: y, cells: cells })
    commit(secs)
    renaming = secs.length - 1
    if (withId) selectId(withId)
  }
  function addGroup(name, withId) {
    var spot = firstSpot(1, 1, layouts)
    newGroupAt(spot.x, spot.y, withId, name)
  }

  // ------------------------------------------------------------- shades
  // A block's shade: one of the theme's colours, by name ("" for none).
  readonly property var shadeSlots: ["accent", "red", "orange", "yellow", "green", "cyan", "blue", "magenta", "brown",
    "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta",
    "selection", "muted", "foreground", "light_foreground", "dark_foreground"]
  function shadeColor(slot) {
    if (!slot) return ""
    if (slot === "accent") return String(Color.accent)
    return taskbar.themeColors[slot] || ""
  }
  // The slots worth offering in this theme (a colour it doesn't have, or
  // one it repeats, is left out).
  readonly property var shadeChoices: {
    var seen = {}, out = []
    for (var i = 0; i < shadeSlots.length; i++) {
      var hex = shadeColor(shadeSlots[i]).toLowerCase()
      if (!hex || seen[hex]) continue
      seen[hex] = true
      out.push(shadeSlots[i])
    }
    return out
  }
  // The picker's two rows: "none" and the bright colours, then the softer
  // ones (pale, deep or greyish), each in hue order (red, orange, yellow,
  // green, cyan, blue, purple). A theme with only one kind: split in two.
  function hsvOf(hex) {
    var n = parseInt(String(hex).slice(1, 7), 16)
    var r = (n >> 16 & 255) / 255, g = (n >> 8 & 255) / 255, b = (n & 255) / 255
    var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min, h = 0
    if (d > 0) h = max === r ? ((g - b) / d + 6) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4
    return { h: h * 60, s: max === 0 ? 0 : d / max, v: max }
  }
  readonly property var shadeRows: {
    var all = shadeChoices.map(function(slot) { var c = hsvOf(shadeColor(slot)); return { slot: slot, h: c.h, s: c.s, v: c.v } })
    var byHue = function(a, b) { return a.h - b.h || b.v - a.v }
    var bright = function(c) { return c.s >= 0.45 && c.v >= 0.5 }
    var strong = all.filter(bright).sort(byHue)
    var soft = all.filter(function(c) { return !bright(c) }).sort(byHue)
    if (!strong.length || !soft.length) {
      var sorted = all.sort(byHue), half = Math.ceil(sorted.length / 2)
      strong = sorted.slice(0, half)
      soft = sorted.slice(half)
    }
    var slots = function(list) { return list.map(function(c) { return c.slot }) }
    return [[""].concat(slots(strong)), slots(soft)]
  }

  function setShade(sec, slot) {
    var secs = snapshot()
    if (sec < 0 || sec >= secs.length) return
    secs[sec].shade = slot
    if (!slot && secs[sec].icons === "shade") secs[sec].icons = ""
    commit(secs)
  }

  // A block's own icon style (over the Icons setting): stepped from its ⋯.
  readonly property var iconStyleNames: ({ "": "Default (Icons setting)", line: "Line", brand: "Coloured", palette: "Theme-coloured",
                                           original: "Original", shade: "Group shade" })
  function setIcons(sec, style) {
    var secs = snapshot()
    if (sec < 0 || sec >= secs.length) return
    secs[sec].icons = style || ""
    commit(secs)
  }

  function renameGroup(sec, name) {
    renaming = -1
    var clean = String(name).trim()
    if (sec < 1 || sec > groups.length || clean === "") return
    var secs = snapshot()
    secs[sec].name = clean
    commit(secs)
  }

  // Its apps go back to Pinned, after what's there.
  function deleteGroup(sec) {
    if (sec < 1 || sec > groups.length) return
    var secs = snapshot()
    var moving = secs[sec].ids
    secs.splice(sec, 1)
    var pin = secs[0]
    var wrap = Math.max(1, Math.min(columns - pin.x, Math.max(widthOf(pin), 3)))
    moving.forEach(function(id) {
      if (pin.ids.indexOf(id) === -1) pin.ids.push(id)
      pin.cells[id] = Object.keys(pin.cells).length === 0 ? [0, 0] : freeCell(pin, wrap, 0)
    })
    renaming = -1
    commit(secs)
    selected = 0
  }

  readonly property var frequentEntries: {
    if (!showFrequent) return []
    var candidates = []
    for (var id in usage) {
      if (groupedIds.indexOf(id) !== -1 || hiddenFrequent.indexOf(id) !== -1) continue
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
    var data = { pinned: pinnedIds }
    if (pinnedLayout) data.pinnedLayout = pinnedLayout
    if (groups.length) data.groups = groups
    if (hiddenFrequent.length) data.hiddenFrequent = hiddenFrequent
    if (Object.keys(folderActions).length) data.folderActions = folderActions
    configFile.setText(JSON.stringify(data, null, 2) + "\n")
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

  // Pinned here means in Pinned or any group.
  function isPinned(entry) {
    return !!entry && groupedIds.indexOf(entry.id) !== -1
  }

  // Unpin from its section, or pin to Pinned.
  function togglePin(entry) {
    if (!entry) return
    if (sectionOf(entry.id) === -1) appendTo(entry.id, 0)
    else removeTile(entry.id)
  }

  // Dragging a tile: its section (-2: Frequent) and place, where it would
  // land, and the pointer (in the panel) for the floating copy.
  property int dragSection: -1
  property int dragIndex: -1
  property int dropSection: -1
  property int dropIndex: -1
  property point dragPoint: Qt.point(0, 0)
  readonly property var dragEntry: dragIndex < 0 ? null
    : dragSection === -2 ? (frequentEntries[dragIndex] || null)
    : dragSection >= 0 && dragSection < sectionEntries.length ? (sectionEntries[dragSection][dragIndex] || null) : null

  // Where a dragged tile would go, from the cell under the pointer: into a
  // block (an empty cell: there; a tile: they swap), just past a block's
  // right, bottom or left edge (it grows), anywhere else (a new group).
  // {kind: "place" | "swap" | "grow" | "new", sec, c, r (in the block),
  //  gx, gy (on the grid)}
  property var dropPlan: null
  function planDrop(scenePoint) {
    var p = blockCanvas.mapFromItem(null, scenePoint.x, scenePoint.y)
    if (p.x < 0 || p.x > blockCanvas.width || p.y < 0 || p.y > blockCanvas.height) return null
    var gx = Math.max(0, Math.min(columns - 1, Math.floor(p.x / colPitch)))
    var gy = Math.max(0, Math.floor((p.y - bandHeight) / rowPitch))
    var dragged = dragEntry ? dragEntry.id : ""
    var i, L, c, r
    for (i = 0; i < layouts.length; i++) {
      L = layouts[i]
      c = gx - L.x
      r = gy - L.y
      if (c >= 0 && c < L.w && r >= 0 && r < L.h) {
        var tiles = sectionTiles[i] || [], occ = -1
        for (var k = 0; k < tiles.length; k++) if (tiles[k].c === c && tiles[k].r === r && tiles[k].entry.id !== dragged) occ = k
        return { kind: occ >= 0 ? "swap" : "place", sec: i, c: c, r: r, gx: gx, gy: gy, idx: occ }
      }
    }
    var free = { x: gx, y: gy, w: 1, h: 1 }
    for (i = 0; i < layouts.length; i++) {
      L = layouts[i]
      c = gx - L.x
      r = gy - L.y
      var beside = (c === L.w || c === -1) && r >= 0 && r < L.h
      var under = r === L.h && c >= 0 && c < L.w
      if ((beside || under) && fits(free, layouts, i)) return { kind: "grow", sec: i, c: c, r: r, gx: gx, gy: gy, idx: -1 }
    }
    return { kind: "new", sec: -1, c: 0, r: 0, gx: gx, gy: gy, idx: -1 }
  }

  // Drop whatever's being dragged without doing anything (the menu closed,
  // or the drag was cancelled).
  function cancelDrag() {
    dragSection = -1
    dragIndex = -1
    dropSection = -1
    dropIndex = -1
    dropPlan = null
    blockAction = ""
    blockSection = -1
    blockGhost = null
  }

  function updateDrop(point) {
    var plan = planDrop(point)
    dropPlan = plan
    dropSection = plan && plan.kind === "swap" ? plan.sec : -1
    dropIndex = plan && plan.kind === "swap" ? plan.idx : -1
  }

  function endDrag() {
    var entry = dragEntry, plan = dropPlan
    dragSection = -1
    dragIndex = -1
    dropSection = -1
    dropIndex = -1
    dropPlan = null
    if (!entry || !plan) return
    if (plan.kind === "new") newGroupAt(plan.gx, plan.gy, entry.id)
    else moveTileTo(entry.id, plan.sec, plan.c, plan.r)
  }

  // Right-click on a tile: a small menu (pin, move to a group, new group).
  property var tileMenuEntry: null
  property point tileMenuPoint: Qt.point(0, 0)
  readonly property var tileMenuItems: {
    var e = tileMenuEntry
    if (!e) return []
    // A block's ⋯: its shade; for a group, rename and delete too.
    if (e.blockMenu !== undefined) {
      var block = sections[e.blockMenu] || {}
      var cur = block.icons || ""
      var list = [{ header: "Shade" }, { act: "shades", sec: e.blockMenu, swatches: true }, { header: "Icons", gap: true }]
      // Its icons: one line per style, the current one ticked.
      ;["", "line", "brand", "palette", "original"].concat(block.shade ? ["shade"] : []).forEach(function(style) {
        list.push({ label: iconStyleNames[style], act: "icons", sec: e.blockMenu, style: style, checkable: true, checked: style === cur })
      })
      if (block.group) {
        list.push({ label: "Rename", act: "rename", sec: e.blockMenu, gap: true })
        list.push({ label: "Delete group (apps go back to Pinned)", act: "delete", sec: e.blockMenu })
      }
      return list
    }
    var sec = sectionOf(e.id)
    var items = [{ label: sec === -1 ? "Pin" : "Unpin", act: "pin" }]
    for (var i = 0; i < sections.length; i++)
      if (i !== sec) items.push({ label: (sec === -1 ? "Pin to " : "Move to ") + sections[i].name, act: "move", sec: i })
    items.push({ label: e.folder ? "New group with this folder" : "New group with this app", act: "group" })
    if (isFrequent(e)) items.push({ label: "Remove from Frequent", act: "hide" })
    // A pinned folder: what each click does for it (click a line to step it).
    if (e.folder && sec !== -1) {
      var _ = folderActions   // re-read when they change
      items.push({ label: folderActionLine(e, "enter"), act: "cycle", how: "enter", gap: true })
      items.push({ label: folderActionLine(e, "shift"), act: "cycle", how: "shift" })
      items.push({ label: folderActionLine(e, "ctrl"), act: "cycle", how: "ctrl" })
    }
    return items
  }
  // Typing and arrows back to the menu (after renaming a group).
  function focusKeys() { keys.forceActiveFocus() }

  function openBlockMenu(sec, scenePoint) { openTileMenu({ blockMenu: sec }, scenePoint) }

  function openTileMenu(entry, scenePoint) {
    tileMenuEntry = entry
    tileMenuPoint = scenePoint
  }
  function runTileMenu(item) {
    var e = tileMenuEntry
    if (e && item && item.act === "cycle") { cycleFolderAction(e, item.how); return }   // stays open
    tileMenuEntry = null
    if (!e || !item) return
    if (item.act === "shade") setShade(item.sec, item.slot)
    else if (item.act === "icons") { setIcons(item.sec, item.style); tileMenuEntry = { blockMenu: item.sec }; return }   // stays open
    else if (item.act === "rename") renaming = item.sec
    else if (item.act === "delete") deleteGroup(item.sec)
    else if (item.act === "pin") togglePin(e)
    else if (item.act === "move") appendTo(e.id, item.sec)
    else if (item.act === "group") addGroup("New group", e.id)
    else if (item.act === "hide") hideFrequent(e)
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
    cancelDrag()
    opened = true
    refreshFolderInfo()
  }

  // Opened for a look only (superMenuPreview IPC, for screenshots and
  // tests): no keyboard focus, so it can't take anyone's typing.
  property bool previewOnly: false
  Timer {
    id: previewMenuTimer
    property int sec: 0
    interval: 500
    onTriggered: {
      var L = menu.layouts[sec]
      if (L) menu.openBlockMenu(sec, blockCanvas.mapToItem(null, (L.x + L.w) * menu.colPitch - menu.tileGap, L.y * menu.rowPitch + menu.bandHeight))
    }
  }
  // "#menu:N" opens block N's ⋯ menu instead of typing (for screenshots).
  function preview(text) {
    previewOnly = true
    open()
    var m = /^#menu:(\d+)$/.exec(String(text || ""))
    if (m) {
      // Once the menu has settled in (its entrance moves it).
      previewMenuTimer.sec = parseInt(m[1], 10)
      previewMenuTimer.restart()
    } else {
      query = text || ""
    }
  }

  function close() {
    previewOnly = false
    opened = false
    query = ""
    armedAction = ""
    hoveredAction = ""
    tileMenuEntry = null
    renaming = -1
    cancelDrag()
  }

  // Open windows that belong to an app (by launcher entry), via the same
  // class -> entry lookup the usage counting uses.
  // A window belongs to the entry if its class is the entry's startup class or
  // id, or the class -> entry lookup lands on it. (Several entries can claim
  // one class, e.g. microsoft-edge and com.microsoft.Edge.)
  function windowsOf(entry) {
    var list = []
    if (!entry || entry.folder) return list
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
    if (entry && entry.folder) { openFolderRow(entry, forceNew ? "shift" : "enter"); return }
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
    // Nothing typed: by position, across the blocks and into Frequent.
    if (query.length === 0) {
      var cells = tileCells, cur = cells[selected]
      if (!cur) { selected = 0; return }
      var best = -1, bestScore = 1e9
      for (var i = 0; i < cells.length; i++) {
        var dc = cells[i].c - cur.c, dr = cells[i].r - cur.r
        if (dx !== 0 ? (dr !== 0 || dc * dx <= 0) : dr * dy <= 0) continue
        var sc = dx !== 0 ? Math.abs(dc) : Math.abs(dr) * 100 + Math.abs(dc)
        if (sc < bestScore) { bestScore = sc; best = i }
      }
      // Past the end of a row: on to the next tile in order.
      if (best < 0 && dx !== 0) best = Math.max(0, Math.min(count - 1, selected + dx))
      if (best >= 0) selected = best
      return
    }
    var next = selected + dx + dy * columns
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
  // An app's icon: the Icons setting's style, or a block's own (style:
  // "line", "brand", "palette", "original", or "shade" in shadeHex).
  function tileIcon(entry, style, shadeHex) {
    var useLine = style === "original" ? false : (style ? true : lineIcons)
    var name = useLine ? menu.taskbar.lineIconForEntry(entry) : ""
    if (name) {
      var tint = style === "shade" && shadeHex ? shadeHex
        : menu.taskbar.lineColor(name, Color.menu.text, style === "line" ? "mono" : style === "brand" || style === "palette" ? style
                                                       : menu.taskbar.colorModeFor("SuperMenu"))
      return TaskbarIcons.svg(name, tint)
    }
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
          var spot = menu.query.length === 0 ? menu.locate(menu.selected) : null
          if (menu.tileMenuEntry && event.key === Qt.Key_Escape) {
            menu.tileMenuEntry = null
          } else if (ctrl && spot && (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                               || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            // Ctrl+arrows move the tile a cell (swapping with one there; past
            // the block's edge, it grows), within its block.
            var here = menu.sectionTiles[spot.sec][spot.idx]
            var L = menu.layouts[spot.sec]
            var tc = here.c + (event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0)
            var tr = here.r + (event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0)
            var inside = tc >= 0 && tc < L.w && tr >= 0 && tr < L.h
            if (tr >= 0 && (inside || menu.fits({ x: L.x + tc, y: L.y + tr, w: 1, h: 1 }, menu.layouts, spot.sec)))
              menu.moveTileTo(current.id, spot.sec, tc, tr)
          } else if (ctrl && event.key === Qt.Key_P) {
            var row = menu.selected >= menu.tiles.length ? menu.extraResults[menu.selected - menu.tiles.length] : null
            menu.togglePin(row && row.kind === "folder" ? row : current)
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
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && current && current.folder
                     && menu.selected < menu.tiles.length) {
            // A pinned folder: its Enter / Shift+Enter / Ctrl+Enter actions.
            menu.openFolderRow(current, ctrl ? "ctrl" : (event.modifiers & Qt.ShiftModifier) ? "shift" : "enter")
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
            readonly property var selectedExtra: menu.selected >= menu.tiles.length ? menu.extraResults[menu.selected - menu.tiles.length] : null
            text: menu.query.trim() === "" ? "type a question, or click for a new session"
              : selectedExtra && selectedExtra.kind === "folder" ? ""      // Ctrl+Enter is the folder's then
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
          visible: menu.query.length > 0
          title: "Results"
          entries: menu.query.length > 0 ? menu.searchEntries : []
          offset: 0
          empty: menu.extraResults.length > 0 ? "" : "No apps match"
        }

        // Pinned and the groups, each at its place on the grid.
        Item {
          id: blockCanvas
          visible: menu.query.length === 0
          width: menu.gridWidth
          // Room below while something's dragged (to drop or move it there).
          height: (menu.gridRows + (menu.blockAction !== "" || menu.dragIndex >= 0 ? 2 : 0)) * menu.rowPitch

          Repeater {
            id: blockRepeater
            model: menu.query.length === 0 ? menu.sections : []
            SuperMenuGroup {
              required property var modelData
              required property int index
              owner: menu
              sectionIndex: index
              title: modelData.name
              entries: menu.sectionEntries[index] || []
              tiles: menu.sectionTiles[index] || []
              shade: menu.shadeColor(modelData.shade)
              iconStyle: modelData.icons || ""
              layout: menu.layouts[index] || ({ x: 0, y: 0, w: 1, h: 1 })
              offset: menu.sectionOffsets[index] || 0
              editable: modelData.group
            }
          }

          // Where a dragged tile would land, if not onto another tile: the
          // cell, and what it does there.
          Rectangle {
            readonly property var plan: menu.dropPlan
            visible: !!plan && plan.kind !== "swap"
            x: plan ? plan.gx * menu.colPitch : 0
            y: plan ? plan.gy * menu.rowPitch + menu.bandHeight : 0
            width: menu.tileWidth
            height: menu.tileHeight
            radius: Style.cornerRadius
            color: Util.alpha(Color.accent, 0.1)
            border.width: 2
            border.color: Color.accent
            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(10)
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: !parent.plan ? "" : parent.plan.kind === "new" ? "New group"
                : parent.plan.kind === "grow" ? "Grow " + menu.sections[parent.plan.sec].name : ""
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Where the moved block would go: the accent if it fits.
          Rectangle {
            readonly property var g: menu.blockGhost
            visible: g !== null
            x: g ? g.x * menu.colPitch - Style.space(3) : 0
            y: g ? g.y * menu.rowPitch - Style.space(3) : 0
            width: g ? g.w * menu.colPitch - menu.tileGap + Style.space(6) : 0
            height: g ? g.h * menu.rowPitch + Style.space(6) : 0
            radius: Style.cornerRadius
            color: g && g.ok ? Util.alpha(Color.accent, 0.1) : Util.alpha("#e06c75", 0.1)
            border.width: 2
            border.color: g && g.ok ? Color.accent : "#e06c75"
          }
        }

        Text {
          visible: menu.query.length === 0
          text: "+ New group"
          color: Color.menu.text
          opacity: newGroupMouse.containsMouse ? 0.9 : 0.45
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          MouseArea {
            id: newGroupMouse
            anchors.fill: parent
            anchors.margins: -Style.space(4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.addGroup("New group", null)
          }
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
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                  if (mouse.button === Qt.RightButton) {
                    if (extraRow.modelData.kind === "folder") menu.openTileMenu(extraRow.modelData, extraMouse.mapToItem(null, mouse.x, mouse.y))
                    return
                  }
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
          sectionIndex: -2
          draggable: true
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
            : selectedExtra && selectedExtra.kind === "folder" ? menu.folderHint(selectedExtra)
            : menu.selected < menu.tiles.length && menu.tiles[menu.selected] && menu.tiles[menu.selected].folder
              ? menu.folderHint(menu.tiles[menu.selected]).replace(/Enter/g, "click")
            : menu.query.length > 0
            ? "Enter opens (Shift: new window) · Ctrl+Enter asks an agent · + or Ctrl+P pins · Esc closes"
            : "Tiles stay where you drop them: past a group's edge grows it, open space starts one · drag a title to move it"
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
      source: menu.dragEntry && !menu.dragEntry.folder ? menu.tileIcon(menu.dragEntry) : ""
      opacity: 0.9
      Text {
        anchors.centerIn: parent
        visible: !!menu.dragEntry && !!menu.dragEntry.folder
        text: menu.dragEntry && menu.dragEntry.folder ? menu.dragEntry.glyph : ""
        color: Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: menu.iconSize * 0.8
      }
    }

    // A tile's right-click menu; a click anywhere else closes it.
    MouseArea {
      anchors.fill: parent
      visible: menu.tileMenuEntry !== null
      z: 20
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: menu.tileMenuEntry = null
    }
    // Sized to its longest line (up to a limit; longer ones end in "…").
    FontMetrics {
      id: tileMenuMetrics
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
    }
    Rectangle {
      id: tileMenuBox
      readonly property real pad: Style.space(4)
      readonly property real widest: menu.tileMenuItems.reduce(function(w, it) {
        if (it.swatches) return Math.max(w, Math.max(menu.shadeRows[0].length, menu.shadeRows[1].length) * Style.space(24))
        if (it.header) return w
        return Math.max(w, tileMenuMetrics.advanceWidth(it.label) + (it.checkable ? Style.space(20) : 0))
      }, 0)
      visible: menu.tileMenuEntry !== null
      z: 21
      width: Math.max(Style.space(200), Math.min(Style.space(400), widest + Style.space(24) + pad * 2))
      height: tileMenuColumn.implicitHeight + pad * 2
      x: Math.max(4, Math.min(menu.tileMenuPoint.x, parent.width - width - 4))
      y: Math.max(4, Math.min(menu.tileMenuPoint.y, parent.height - height - 4))
      radius: Style.cornerRadius
      color: Color.menu.background
      border.width: 1
      border.color: Util.alpha(Color.menu.text, 0.25)

      Column {
        id: tileMenuColumn
        x: tileMenuBox.pad
        y: tileMenuBox.pad
        width: tileMenuBox.width - tileMenuBox.pad * 2
        Repeater {
          model: menu.tileMenuItems
          Rectangle {
            id: menuRow
            required property var modelData
            readonly property real topGap: modelData.gap ? Style.space(9) : 0
            width: tileMenuColumn.width
            height: topGap + (modelData.swatches ? swatchFlow.height + Style.space(10)
                              : modelData.header ? Style.space(20) : Style.space(28))
            radius: Style.cornerRadius
            color: itemMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
            Rectangle {
              visible: !!menuRow.modelData.gap
              anchors.top: parent.top
              anchors.topMargin: Style.space(4)
              width: parent.width
              height: 1
              color: Util.alpha(Color.menu.text, 0.15)
            }
            // A block's shade: two rows (shadeRows), none first.
            Column {
              id: swatchFlow
              visible: !!menuRow.modelData.swatches
              x: Style.space(8)
              y: menuRow.topGap + Style.space(6)
              spacing: Style.space(6)
              Repeater {
                model: menuRow.modelData.swatches ? menu.shadeRows : []
                Row {
                  required property var modelData
                  spacing: Style.space(6)
              Repeater {
                model: parent.modelData
                Rectangle {
                  required property var modelData
                  readonly property string cur: menu.tileMenuEntry && menu.sections[menu.tileMenuEntry.blockMenu]
                    ? menu.sections[menu.tileMenuEntry.blockMenu].shade : ""
                  width: Style.space(18)
                  height: width
                  radius: width / 2
                  color: modelData === "" ? "transparent" : menu.shadeColor(modelData)
                  border.width: cur === modelData ? 2 : 1
                  border.color: cur === modelData ? Color.menu.text : Util.alpha(Color.menu.text, 0.3)
                  // None: a slash through an empty circle.
                  Rectangle {
                    visible: parent.modelData === ""
                    anchors.centerIn: parent
                    width: parent.width * 0.9
                    height: 1
                    rotation: -45
                    color: Util.alpha(Color.menu.text, 0.5)
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: menu.hoverDetail = parent.modelData === "" ? "No shade" : "Shade: " + parent.modelData.replace(/_/g, " ")
                    onExited: menu.hoverDetail = ""
                    onClicked: menu.runTileMenu({ act: "shade", sec: menu.tileMenuEntry.blockMenu, slot: parent.modelData })
                  }
                }
              }
                }
              }
            }
            // A section's heading.
            Text {
              visible: !!menuRow.modelData.header
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(2)
              text: menuRow.modelData.header ? String(menuRow.modelData.header).toUpperCase() : ""
              color: Color.menu.text
              opacity: 0.45
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            // A choice's tick (checkable lines keep a column for it).
            Text {
              visible: !!menuRow.modelData.checkable
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: rowLabel.verticalCenter
              text: menuRow.modelData.checked ? "\u2713" : ""
              color: itemMouse.containsMouse ? Color.menu.selectedText : Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              id: rowLabel
              visible: !menuRow.modelData.swatches && !menuRow.modelData.header
              anchors.left: parent.left
              anchors.leftMargin: Style.space(menuRow.modelData.checkable ? 30 : 10)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(6)
              text: menuRow.modelData.label || ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: itemMouse.containsMouse ? Color.menu.selectedText : Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              id: itemMouse
              anchors.fill: parent
              enabled: !menuRow.modelData.swatches && !menuRow.modelData.header
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: menu.runTileMenu(menuRow.modelData)
            }
          }
        }
      }
    }
  }
}
