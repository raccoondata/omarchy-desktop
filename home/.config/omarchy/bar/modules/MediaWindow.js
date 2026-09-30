.pragma library

// Which window is playing this media (an MPRIS player), for "go to the app"
// in the now-playing widget (nowplaying.qml) and the Super menu. Browsers
// can't be raised over MPRIS, and their web apps (Teams, YouTube… as Omarchy
// web apps, class chrome-/msedge-<site>__…) share the browser's process, so
// the candidates (same process, or an app name match) are ranked: the one
// whose title names the track (the tab that's playing), then its artist or
// album; then the browser's own window over its web apps.
//
//   bestWindow(player, toplevels) -> a HyprlandToplevel, or null

function squash(v) {
  return String(v || "").toLowerCase().replace(/[^a-z0-9]/g, "")
}

function bestWindow(player, toplevels) {
  if (!player) return null
  var pidMatch = /instance_?(\d+)$/.exec(String(player.dbusName || ""))
  var pid = pidMatch ? Number(pidMatch[1]) : 0
  var names = [squash(player.desktopEntry), squash(player.identity)].filter(function(n) { return n !== "" })
  var track = String(player.trackTitle || "").toLowerCase()
  var artist = String(player.trackArtist || "").toLowerCase()
  var album = String(player.trackAlbum || "").toLowerCase()
  var best = null
  var bestScore = 0
  for (var i = 0; i < toplevels.length; i++) {
    var ipc = toplevels[i] && toplevels[i].lastIpcObject ? toplevels[i].lastIpcObject : null
    if (!ipc) continue
    var rawClass = String(ipc.class || "")
    var cls = squash(rawClass)
    var named = cls !== "" && names.some(function(n) { return n === cls || n.indexOf(cls) !== -1 || cls.indexOf(n) !== -1 })
    var mine = pid > 0 && Number(ipc.pid) === pid
    if (!named && !mine) continue
    var title = String(toplevels[i].title || ipc.title || "").toLowerCase()
    var webApp = /^(chrome|msedge|brave|chromium)-.+__/i.test(rawClass)
    var score = 1
    if (track && title.indexOf(track) !== -1) score += 100
    if (artist && title.indexOf(artist) !== -1) score += 30
    if (album && title.indexOf(album) !== -1) score += 20
    if (!webApp) score += 10
    if (named) score += 5
    if (score > bestScore) {
      best = toplevels[i]
      bestScore = score
    }
  }
  return best
}

function hexAddress(toplevel) {
  var a = String(toplevel && toplevel.address || "")
  return a.indexOf("0x") === 0 ? a : "0x" + a
}

// The player's own PipeWire playback stream (its volume), by app name: e.g.
// the player "Microsoft Edge" and the stream application.name "Microsoft
// Edge". nodes: bound (PwObjectTracker) playback streams. Or null.
function nodeName(n) {
  var p = n && n.ready && n.properties ? n.properties : {}
  return String(p["application.name"] || (n && n.description) || p["media.name"] || (n && n.name) || "")
}

function playerStream(player, nodes) {
  if (!player) return null
  var b = squash(player.identity || player.desktopEntry)
  if (b === "") return null
  for (var i = 0; i < nodes.length; i++) {
    var n = nodes[i]
    if (!n || !n.audio) continue
    var a = squash(nodeName(n))
    if (a !== "" && (a === b || a.indexOf(b) !== -1 || b.indexOf(a) !== -1)) return n
  }
  return null
}
