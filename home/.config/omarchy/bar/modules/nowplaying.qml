import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "MediaWindow.js" as MediaWindow
import "taskbar-icons.js" as TaskbarIcons
import "TaskbarMatch.js" as TaskbarMatch
import "IconColors.js" as IconColors

// Now playing, in place of Omarchy's Media widget (omarchy.media). Reads MPRIS
// (any player: Edge/Chromium tabs, Spotify, mpv, ...) directly.
//
// On the bar: the album art, then the title and the artist taking turns (each
// gliding to its end first if it doesn't fit), and a thin line under them,
// level with the bottom of the art, for how far into the track it is. Paused: dimmed. Left-click: the
// card; right-click: play/pause (or the other way round); middle-click: next;
// scroll: the app's volume, previous/next track, or nothing. Set in Taskbar &
// Desktop > Now Playing.
//
// The card: big album art over a blurred wash of the same art, title, artist
// and album, with the pixel equalizer (in the style picked
// under Taskbar & Desktop > Effects). Below: a seek bar of square pixels (click
// or drag to jump; hover shows the time), shuffle / previous / play / next /
// repeat (the ones the player supports), the playing app's volume with a
// mixer under the chevron (system + every other app playing sound), and when
// more than one app has something loaded, a chip per app to switch between
// them. Click the art to go to the app. Keys: Space play/pause, Left/Right
// 5 s back/forward, Up/Down volume, Esc close. Art fades in pixel by pixel on
// a new track. Colours are all the theme's.
BarWidget {
  id: root
  moduleName: "nowplaying"

  readonly property string omarchyDir: Quickshell.env("HOME") + "/.config/omarchy"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color text: Color.popups.text
  readonly property color accent: Color.accent
  readonly property int maxLabelWidth: Number(setting("maxLabelWidth", 200))

  function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // --- which player -----------------------------------------------------------
  readonly property var players: Mpris.players ? Mpris.players.values : []
  // The one picked in the card (a chip); dropped when another app starts playing.
  property string preferredKey: ""
  // Order in which players started playing; the newest one playing is shown.
  property var startedAt: ({})
  property int serial: 0

  function keyOf(p) { return p ? String(p.dbusName || p.identity || "") : "" }
  function isProxy(p) { return keyOf(p).indexOf("playerctld") !== -1 }
  function hasTrack(p) { return !!p && !!(p.trackTitle || p.trackArtist) }

  function syncOrder() {
    var next = {}
    var s = serial
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      var k = keyOf(p)
      if (!k || !p.isPlaying) continue
      if (startedAt[k] === undefined) {
        s += 1
        next[k] = s
        if (preferredKey && preferredKey !== k) preferredKey = ""
      } else {
        next[k] = startedAt[k]
      }
    }
    serial = s
    startedAt = next
  }

  // Players with a track loaded (playerctld only if it's all there is).
  readonly property var trackPlayers: {
    var list = []
    for (var i = 0; i < players.length; i++)
      if (hasTrack(players[i]) && !isProxy(players[i])) list.push(players[i])
    if (list.length === 0)
      for (var j = 0; j < players.length; j++)
        if (hasTrack(players[j])) list.push(players[j])
    return list
  }

  readonly property var livePlayer: {
    var list = trackPlayers
    var preferred = null
    var newest = null
    var newestOrder = -1
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (keyOf(p) === preferredKey) preferred = p
      if (p.isPlaying) {
        var order = startedAt[keyOf(p)] || 0
        if (order > newestOrder) { newest = p; newestOrder = order }
      }
    }
    return preferred || newest || (list.length ? list[0] : null)
  }

  // Skipping a track, a player (Edge) reports no track for a moment while it
  // loads the next one. Hold on to the last player and track for up to 2 s
  // so the widget and the card don't vanish in between.
  property var heldPlayer: null
  onLivePlayerChanged: if (livePlayer) heldPlayer = livePlayer
  readonly property var player: livePlayer
    || (holdTimer.running && heldPlayer && players.indexOf(heldPlayer) !== -1 ? heldPlayer : null)
  Timer { id: holdTimer; interval: 2000 }

  Component.onCompleted: syncOrder()
  onPlayersChanged: syncOrder()
  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.syncOrder() }
    }
  }

  // --- the track --------------------------------------------------------------
  readonly property bool liveMedia: hasTrack(livePlayer)
  readonly property bool hasMedia: liveMedia || holdTimer.running
  // While it loads the next track the player also says it's paused, with no
  // length and no next/previous. "Settling" (right after a skip, or when the
  // length drops to nothing, up to 1.5 s, until it's playing with a length
  // again) keeps showing the last real state, so the card doesn't flicker to
  // PAUSED / LIVE / greyed-out buttons.
  readonly property bool holding: (!liveMedia && holdTimer.running) || settleTimer.running
  property bool wasPlaying: false
  property real heldLength: 0
  property real settleStarted: 0
  Timer { id: settleTimer; interval: 1500 }
  function settle() {
    if (!settleTimer.running) settleStarted = Date.now()
    settleTimer.restart()
  }
  function settled() {
    if (settleTimer.running && rawPlaying && rawLength > 0 && Date.now() - settleStarted > 250) settleTimer.stop()
  }
  onLiveMediaChanged: {
    if (liveMedia) { holdTimer.stop(); return }
    if (title !== "") holdTimer.restart()
  }
  // Remember the last real state while nothing's in flux.
  onRawPlayingChanged: { if (!holding) wasPlaying = rawPlaying; settled() }
  onRawLengthChanged: {
    if (rawLength <= 0 && heldLength > 0 && liveMedia) settle()
    else if (!holding && rawLength > 0) heldLength = rawLength
    settled()
  }
  readonly property bool rawPlaying: !!player && player.isPlaying
  readonly property real rawLength: player && player.lengthSupported ? Number(player.length) || 0 : 0
  readonly property bool playing: holding ? wasPlaying : rawPlaying
  readonly property bool canNext: holding || (!!player && player.canGoNext)
  readonly property bool canPrevious: holding || (!!player && player.canGoPrevious)
  // What's shown: the last track reported (kept through the gap above). Art
  // often arrives a moment after the title; the old art stays until then
  // (or 1.5 s, in case the new track has none).
  property string title: ""
  property string artist: ""
  property string album: ""
  property string artUrl: ""
  readonly property string rawTrack: player ? [player.trackTitle, player.trackArtist, player.trackAlbum, player.trackArtUrl].join("\u0001") : ""
  onRawTrackChanged: remember()
  function remember() {
    var p = player
    if (!hasTrack(p)) return
    title = String(p.trackTitle || "")
    artist = String(p.trackArtist || "")
    album = String(p.trackAlbum || "")
    var art = String(p.trackArtUrl || "")
    if (art !== "") { artUrl = art; artGrace.stop() }
    else if (artUrl !== "") artGrace.restart()
  }
  // The art on screen: the new art only once it has loaded (a hidden image
  // loads it first), so there's never a blank between tracks. Every image
  // uses the same size, so they all come straight from the cache.
  property string shownArt: ""
  onArtUrlChanged: if (artUrl === "") shownArt = ""
  Image {
    id: artLoader
    visible: false
    source: root.artUrl
    sourceSize.width: 320
    sourceSize.height: 320
    asynchronous: true
    onStatusChanged: if (status === Image.Ready) root.shownArt = String(source)
  }
  Timer {
    id: artGrace
    interval: 1500
    onTriggered: if (root.player && !root.player.trackArtUrl) root.artUrl = ""
  }
  // The window playing it, and, when that's a browser web app (it shares the
  // browser's process and player), the web app's own launcher: so it's
  // "YouTube Music", not "Microsoft Edge".
  readonly property var playerWindow: player ? MediaWindow.bestWindow(player, Hyprland.toplevels.values) : null
  readonly property var webApp: MediaWindow.webAppEntry(MediaWindow.webAppSite(playerWindow), DesktopEntries.applications.values)
  readonly property string appName: webApp ? String(webApp.name)
    : player ? String(player.identity || player.desktopEntry || "") : ""
  // The playing app's icon in the mixer: the web app's when it is one.
  function playerAppIcon() {
    if (webApp) {
      var line = lineIcons ? TaskbarMatch.forEntry(webApp) : ""
      if (line) return TaskbarIcons.svg(line, IconColors.colorFor(line, iconColorMode, String(Color.popups.text)))
      if (webApp.icon) return Quickshell.iconPath(webApp.icon, true)
    }
    return root.playerStream ? root.streamIcon(root.playerStream) : ""
  }
  readonly property real length: holding ? heldLength : rawLength
  readonly property real position: holding ? 0 : (player && player.positionSupported ? Number(player.position) || 0 : 0)
  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
  readonly property bool canSeek: !!player && player.canSeek && player.positionSupported && length > 0
  readonly property bool hasVolume: !!player && player.volumeSupported && player.canControl
  // Changes once per track (not when its art turns up).
  readonly property string trackKey: title + "\u0001" + artist + "\u0001" + album

  // MPRIS doesn't push the position as it plays; ask for it.
  Timer {
    running: root.playing && root.hasMedia
    interval: root.popupOpen ? 200 : 1000
    repeat: true
    triggeredOnStart: true
    onTriggered: if (root.player) root.player.positionChanged()
  }

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var sec = s % 60
    var mm = h > 0 && m < 10 ? "0" + m : String(m)
    return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec
  }

  // --- actions ----------------------------------------------------------------
  function toggle() {
    var p = player
    if (!p) return
    if (p.canTogglePlaying) p.togglePlaying()
    else if (p.isPlaying) p.pause()
    else p.play()
  }
  // While settling the player may briefly say it can't skip; ask anyway (it
  // ignores what it can't do), so quick repeated skips all go through.
  function next() { if (player && (player.canGoNext || holding)) player.next() }
  function previous() { if (player && (player.canGoPrevious || holding)) player.previous() }
  // From the card's buttons: the card slides the way you skipped.
  property int skipDir: 0
  signal skipped(int dir)
  function skip(dir) {
    skipDir = dir
    if (dir > 0) next(); else previous()
    settle()
    skipped(dir)
  }
  function seekTo(fraction) {
    if (canSeek) player.position = Math.max(0, Math.min(1, fraction)) * length
  }
  function seekBy(seconds) {
    if (canSeek) player.position = Math.max(0, Math.min(length - 1, player.position + seconds))
  }
  function setVolume(v) {
    if (hasVolume) player.volume = Math.max(0, Math.min(1, v))
  }
  property real volumeBeforeMute: 0.6
  function toggleMute() {
    if (!hasVolume) return
    if (player.volume > 0.001) { volumeBeforeMute = player.volume; setVolume(0) }
    else setVolume(volumeBeforeMute > 0.01 ? volumeBeforeMute : 0.6)
  }
  function cycleLoop() {
    if (!player || !player.loopSupported) return
    player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
      : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
  }
  function toggleShuffle() {
    if (player && player.shuffleSupported) player.shuffle = !player.shuffle
  }
  // Go to the app that's playing: its window (MediaWindow.js picks it; the
  // Super menu uses the same), via the taskbar's focus action (switches
  // workspace, restores a minimized one).
  function raiseApp() {
    var p = player
    if (!p) return
    close()
    Hyprland.refreshToplevels()
    var win = MediaWindow.bestWindow(p, Hyprland.toplevels.values)
    if (win) Util.execArgv([omarchyDir + "/taskbar-action", "focus", MediaWindow.hexAddress(win)])
    else if (p.canRaise) p.raise()
  }

  // Options, in taskbar-settings.json with the taskbar's (Taskbar & Desktop >
  // Now Playing): nowPlayingClick "card" (left = card, right = play/pause) or
  // "play" (the other way round), nowPlayingScroll "volume" (default) | "track" | "off",
  // nowPlayingTitle (title next to the art), nowPlayingMixer (mixer left
  // open), nowPlayingVolume (the scroll meter: center | side), and the
  // taskbar's equalizerStyle.
  property string equalizerStyle: "spectrum"
  property string clickMode: "card"
  property string scrollMode: "volume"
  property bool showTitle: true
  property bool mixerOpen: false
  // The scroll volume meter: "center" (percent in the middle, the level
  // growing out both sides) or "side" (a bar, the percent at the right).
  property string volumeStyle: "center"
  // Taskbar & Desktop > Icons > Now playing: the apps' own icons, or the
  // desktop's line icons (where an app has one).
  property bool lineIcons: false
  property bool cardVisualizer: true
  // The card's visualizer ("off", "pixel": the equalizer style, or a scene:
  // Visualizer.qml) and the album art's effect ("off" or shaders/artfx.frag's
  // modes). Right-click / middle-click the art to step through them.
  property string cardVisual: "pixel"
  // Per place (Taskbar & Desktop > Equalizer): "off", "same" (the
  // taskbar's style) or a style. The bar one is off unless chosen.
  property string barEq: "off"
  property string headerEq: "same"
  property string cardEq: "same"
  function eqStyle(choice) { return choice === "same" || !choice ? root.equalizerStyle : choice }
  property string artEffect: "off"
  readonly property var visuals: ["pixel", "tunnel", "kaleido", "starfield", "battery", "lava", "lissajous", "aurora", "off"]
  readonly property var artEffects: ["off", "glitch", "chroma", "pixel", "crt", "melt", "solar"]
  readonly property var visualNames: ({ pixel: "Pixel equalizer", tunnel: "Tunnel", kaleido: "Kaleidoscope", starfield: "Starfield",
    battery: "Battery", lava: "Lava", lissajous: "Lissajous", aurora: "Aurora", off: "No visualizer" })
  readonly property var artEffectNames: ({ off: "No art effect", glitch: "Glitch", chroma: "Chroma", pixel: "Pixelate", crt: "CRT", melt: "Melt", solar: "Solar" })
  function stepSetting(key, list, current) {
    var next = list[(list.indexOf(current) + 1) % list.length]
    Util.execArgv([root.omarchyDir + "/taskbar-setting", "set", key, next])
    return next
  }
  property string iconColorMode: "mono"
  FileView {
    path: root.omarchyDir + "/taskbar-settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var o = {}
      try { o = JSON.parse(text()) || {} } catch (e) { }
      root.equalizerStyle = String(o.equalizerStyle || "spectrum")
      root.clickMode = o.nowPlayingClick === "play" ? "play" : "card"
      root.lineIcons = o.iconsNowPlaying === "line"
      root.cardVisualizer = o.nowPlayingVisualizer !== false
      root.cardVisual = root.visuals.indexOf(o.nowPlayingVisual) !== -1 ? o.nowPlayingVisual : (o.nowPlayingVisualizer === false ? "off" : "pixel")
      root.artEffect = root.artEffects.indexOf(o.nowPlayingArtFx) !== -1 ? o.nowPlayingArtFx : "off"
      root.barEq = String(o.nowPlayingBarEq || "off")
      root.headerEq = String(o.nowPlayingHeaderEq || "same")
      root.cardEq = String(o.nowPlayingCardEq || "same")
      root.iconColorMode = String(o.iconColorsNowPlaying || o.iconColors || "mono")
      root.scrollMode = ["track", "volume", "off"].indexOf(o.nowPlayingScroll) !== -1 ? o.nowPlayingScroll : "volume"
      root.showTitle = o.nowPlayingTitle !== false && o.nowPlayingTitle !== "false"
      root.mixerOpen = o.nowPlayingMixer === true || o.nowPlayingMixer === "true"
      root.volumeStyle = o.nowPlayingVolume === "side" ? "side" : "center"
    }
  }
  function toggleMixer() {
    mixerOpen = !mixerOpen
    Util.execArgv([omarchyDir + "/taskbar-setting", "set", "nowPlayingMixer", String(mixerOpen)])
  }

  // --- volume: PipeWire -------------------------------------------------------
  // Every app's playback stream, bound (PwObjectTracker) so its volume can be
  // read and set. The mixer's rows come from a snapshot taken a moment after
  // the list changes, and only while the card is open: rebuilding a Repeater
  // straight from PipeWire's removal signal can crash Quickshell (same
  // precaution as Omarchy's Audio panel).
  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var liveStreams: {
    var list = []
    for (var i = 0; i < pwNodes.length; i++) {
      var n = pwNodes[i]
      if (n && n.isStream && n.isSink) list.push(n)
    }
    return list
  }
  PwObjectTracker { objects: root.liveStreams }
  property var streams: []
  onLiveStreamsChanged: if (popupOpen) streamSnapshot.restart()
  Timer {
    id: streamSnapshot
    interval: 150
    onTriggered: root.streams = root.popupOpen ? root.liveStreams.slice() : []
  }

  function nodeProps(n) { return n && n.ready && n.properties ? n.properties : {} }
  function streamName(n) {
    var p = nodeProps(n)
    return String(p["application.name"] || (n && n.description) || p["media.name"] || (n && n.name) || "App")
  }
  function streamIcon(n) {
    var p = nodeProps(n)
    var binary = String(p["application.process.binary"] || "")
    var entry = DesktopEntries.heuristicLookup(binary || String(p["application.name"] || ""))
    if (lineIcons) {
      var line = TaskbarMatch.forApp(p["application.icon-name"], p["application.name"], binary, entry)
      if (line) return TaskbarIcons.svg(line, IconColors.colorFor(line, iconColorMode, String(Color.popups.text)))
    }
    var name = p["application.icon-name"] || (entry ? entry.icon : "")
    return name ? Quickshell.iconPath(name, true) : ""
  }
  // The playing app's own stream (its volume in the card and on scroll).
  // (MediaWindow.js, shared with the Super menu's now playing.)
  readonly property var playerStream: MediaWindow.playerStream(player, liveStreams)

  // System output: the sink the volume keys change (through any speaker
  // tuning), like Omarchy's Audio panel.
  property string outputSinkName: ""
  readonly property var outputSink: {
    var fallback = Pipewire.defaultAudioSink
    if (outputSinkName === "") return fallback
    for (var i = 0; i < pwNodes.length; i++) {
      var n = pwNodes[i]
      if (n && n.isSink && !n.isStream && String(n.name) === outputSinkName) return n
    }
    return fallback
  }
  PwObjectTracker { objects: root.outputSink ? [root.outputSink] : [] }
  Process {
    id: outputSinkProc
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector { onStreamFinished: root.outputSinkName = this.text.trim() }
  }

  // This app's volume: its PipeWire stream, else what the player reports.
  readonly property bool hasAppVolume: (!!playerStream && !!playerStream.audio) || hasVolume
  readonly property real appVolume: playerStream && playerStream.audio ? playerStream.audio.volume
    : (hasVolume ? Number(player.volume) || 0 : 0)
  readonly property bool appMuted: !!playerStream && !!playerStream.audio && playerStream.audio.muted
  function setAppVolume(v) {
    var value = Math.max(0, Math.min(1, v))
    if (playerStream && playerStream.audio) {
      playerStream.audio.volume = value
      if (value > 0 && playerStream.audio.muted) playerStream.audio.muted = false
    } else {
      setVolume(value)
    }
  }
  function toggleAppMute() {
    if (playerStream && playerStream.audio) playerStream.audio.muted = !playerStream.audio.muted
    else toggleMute()
  }

  // --- on the bar -------------------------------------------------------------
  property bool popupOpen: false
  function close() { popupOpen = false }
  onHasMediaChanged: if (!hasMedia) popupOpen = false
  onPopupOpenChanged: {
    if (popupOpen) { streamSnapshot.restart(); if (!outputSinkProc.running) outputSinkProc.running = true }
    else { streamSnapshot.stop(); streams = [] }
  }

  visible: hasMedia
  implicitWidth: hasMedia ? pill.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: pill
    anchors.centerIn: parent
    spacing: Style.space(7)
    opacity: root.playing ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // A small visualizer by the song (Equalizer > Bar), off by default.
    Equalizer {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.barEq !== "off" && root.hasMedia && !root.vertical
      columns: 5
      rows: 4
      pixel: Math.max(2, Style.space(3))
      gap: 1
      playing: root.playing && visible
      silent: !root.playing
      style: root.eqStyle(root.barEq)
      color: root.accent
    }

    Item {
      id: thumb
      readonly property int size: Math.max(12, root.barSize - Style.space(12))
      width: size
      height: size
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: Math.min(Style.cornerRadius, 3)
        color: root.tint(root.foreground, 0.12)
        visible: thumbArt.status !== Image.Ready
        Text {
          anchors.centerIn: parent
          text: "󰝚"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.round(thumb.size * 0.7)
        }
      }
      Image {
        id: thumbArt
        anchors.fill: parent
        Connections {
          target: root
          function onShownArtChanged() { if (root.shownArt !== "") { thumbReveal.reseed(); thumbAssemble.restart() } }
        }
        source: root.shownArt
        sourceSize.width: 320
        sourceSize.height: 320
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
      }
      // New art: it assembles out of pixels, like the taskbar's icons.
      PixelCover {
        id: thumbReveal
        anchors.fill: parent
        cell: Math.max(2, Math.round(thumb.size / 8))
        coverColor: Color.bar.background
        progress: 1.2
        visible: thumbAssemble.running
      }
      NumberAnimation { id: thumbAssemble; target: thumbReveal; property: "progress"; from: -0.1; to: 1.2; duration: 420; easing.type: Easing.OutQuad }
    }

    // The title, then the artist (dimmer), taking turns: each one rests,
    // glides to its end if it's too long to fit, rests, and fades over to the
    // other. Fixed width (the longer of the two, up to maxLabelWidth) so the
    // bar doesn't shift as they swap. No artist: just the title, gliding and
    // fading back to its start.
    Item {
      id: marquee
      width: Math.max(Math.min(root.maxLabelWidth, Math.max(titleMetrics.advanceWidth, root.artist ? artistMetrics.advanceWidth : 0)) + 1,
                      root.showingVolume ? Style.space(150) : 0)
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      height: label.implicitHeight
      anchors.verticalCenter: parent.verticalCenter
      clip: true
      visible: !root.vertical && root.showTitle

      property bool showingArtist: false
      readonly property real titleOverflow: Math.max(0, Math.ceil(titleMetrics.advanceWidth - width))
      readonly property real artistOverflow: Math.max(0, Math.ceil(artistMetrics.advanceWidth - width))
      readonly property bool alternate: root.artist !== ""

      TextMetrics { id: titleMetrics; font: label.font; text: root.title }
      TextMetrics { id: artistMetrics; font: label.font; text: root.artist }

      // The title/artist, cross-faded with the volume meter below (its own
      // layer: the scroll animation drives the label's opacity itself).
      Item {
        anchors.fill: parent
        opacity: root.showingVolume ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Text {
          id: label
          textFormat: Text.PlainText
          text: marquee.showingArtist ? root.artist : root.title
          color: marquee.showingArtist ? root.tint(root.foreground, 0.72) : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          transform: Translate { id: lift; y: 0 }
        }
      }

      // Scrolling: square-pixel level · percent.
      Row {
        id: meter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Style.space(7)
        opacity: root.showingVolume && root.volumeStyle === "side" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        PixelBar {
          anchors.verticalCenter: parent.verticalCenter
          width: meter.width - meterPercent.width - meter.spacing
          cell: Math.max(3, Style.space(3))
          gap: 1
          rows: 2
          value: root.appMuted ? 0 : Math.min(1, root.appVolume)
          fill: root.accent
          track: root.tint(root.foreground, 0.16)
        }
        Text {
          id: meterPercent
          anchors.verticalCenter: parent.verticalCenter
          width: percentMetrics.advanceWidth
          horizontalAlignment: Text.AlignRight
          text: root.appMuted ? "mute" : Math.round(root.appVolume * 100) + "%"
          color: root.appMuted ? root.tint(root.foreground, 0.5) : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          onTextChanged: if (root.showingVolume) percentPop.restart()
          SequentialAnimation on scale {
            id: percentPop
            running: false
            NumberAnimation { to: 1.14; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 160; easing.type: Easing.OutBack }
          }
          TextMetrics { id: percentMetrics; font: meterPercent.font; text: "100%" }
        }
      }

      // Centered: the percent in the middle, the level growing out to both
      // sides from it.
      Item {
        id: centerMeter
        anchors.fill: parent
        opacity: root.showingVolume && root.volumeStyle === "center" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Text {
          id: centerPercent
          anchors.centerIn: parent
          width: centerMetrics.advanceWidth
          horizontalAlignment: Text.AlignHCenter
          text: root.appMuted ? "mute" : Math.round(root.appVolume * 100) + "%"
          color: root.appMuted ? root.tint(root.foreground, 0.5) : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          onTextChanged: if (root.showingVolume) centerPop.restart()
          SequentialAnimation on scale {
            id: centerPop
            running: false
            NumberAnimation { to: 1.14; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 160; easing.type: Easing.OutBack }
          }
          TextMetrics { id: centerMetrics; font: centerPercent.font; text: "100%" }
        }
        // Left of it, filling from the percent outwards.
        PixelBar {
          anchors.left: parent.left
          anchors.right: centerPercent.left
          anchors.rightMargin: Style.space(7)
          anchors.verticalCenter: parent.verticalCenter
          cell: Math.max(3, Style.space(3))
          gap: 1
          rows: 2
          value: root.appMuted ? 0 : Math.min(1, root.appVolume)
          fill: root.accent
          track: root.tint(root.foreground, 0.16)
          reverse: true
        }
        PixelBar {
          anchors.left: centerPercent.right
          anchors.right: parent.right
          anchors.leftMargin: Style.space(7)
          anchors.verticalCenter: parent.verticalCenter
          cell: Math.max(3, Style.space(3))
          gap: 1
          rows: 2
          value: root.appMuted ? 0 : Math.min(1, root.appVolume)
          fill: root.accent
          track: root.tint(root.foreground, 0.16)
        }
      }

      // The cycle: title, (scroll), artist, (scroll), back. A Timer waits
      // between the steps and each movement is its own short animation: a
      // running animation makes the bar redraw every frame, pauses and all,
      // which at a high refresh rate is real CPU for a still picture.
      property int stage: 0
      readonly property bool shouldRun: marquee.visible && !root.popupOpen && !root.showingVolume && (marquee.alternate || marquee.titleOverflow > 0)
      onShouldRunChanged: marquee.reset()
      Component.onCompleted: marquee.reset()

      function reset() {
        stageTimer.stop()
        scrollAnim.stop()
        fadeOut.stop()
        fadeIn.stop()
        showingArtist = false
        label.x = 0
        label.opacity = 1
        lift.y = 0
        stage = 0
        if (shouldRun) wait(5000)
      }
      function wait(ms) {
        stageTimer.interval = ms
        stageTimer.restart()
      }
      // One step on. Stages: 0 title shown, 1 title scrolled, 2 switched to
      // the artist, 3 artist shown, 4 artist scrolled, then back to 0.
      function advance() {
        if (!shouldRun) return
        var artist = stage >= 3
        var overflow = artist ? marquee.artistOverflow : marquee.titleOverflow
        if (stage === 0 || stage === 3) {
          if (artist && !marquee.alternate) { stage = 0; wait(5000); return }
          stage += 1
          if (overflow > 0) {
            scrollAnim.to = -overflow
            scrollAnim.duration = Math.max(1200, overflow * 28)
            scrollAnim.restart()  // then a pause (scrollAnim.onFinished)
          } else advance()
        } else if (stage === 1 || stage === 4) {
          stage = stage === 1 ? 2 : 5
          fadeOut.restart()  // then swap and fade in (fadeOut.onFinished)
        }
      }
      Timer { id: stageTimer; onTriggered: marquee.advance() }
      NumberAnimation {
        id: scrollAnim
        target: label
        property: "x"
        easing.type: Easing.InOutSine
        onFinished: marquee.wait(1600)
      }
      NumberAnimation {
        id: fadeOut
        target: label
        property: "opacity"
        to: 0
        duration: 240
        easing.type: Easing.InQuad
        onFinished: {
          label.x = 0
          // Stage 2: the artist next (when alternating); 5: the title again.
          marquee.showingArtist = marquee.stage === 2 && marquee.alternate
          marquee.stage = marquee.showingArtist ? 3 : 0
          fadeIn.restart()
        }
      }
      ParallelAnimation {
        id: fadeIn
        NumberAnimation { target: label; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: lift; property: "y"; from: Style.space(3); to: 0; duration: 300; easing.type: Easing.OutCubic }
        onFinished: marquee.wait(marquee.stage === 3 ? 3500 : 5000)
      }
    }
  }

  // Scrolling the volume: for a moment a small meter takes the title's
  // place: the percent centered with the level growing out both sides, or a
  // bar with the percent at the right (volumeStyle).
  property bool showingVolume: false
  function flashVolume() {
    showingVolume = true
    volumeFlash.restart()
  }
  Timer { id: volumeFlash; interval: 1500; onTriggered: root.showingVolume = false }
  // How far into the track: a hairline along the bottom of the widget.
  Item {
    visible: root.length > 0 && marquee.visible
    x: pill.x + marquee.x
    width: marquee.width
    y: pill.y + thumb.y + thumb.height - height
    height: Math.max(1, Style.space(2))

    Rectangle { anchors.fill: parent; color: root.tint(root.foreground, 0.14) }
    Rectangle {
      width: parent.width * root.progress
      height: parent.height
      color: root.accent
      opacity: root.playing ? 0.9 : 0.5
      // No smoothing: the position moves once a second by well under a
      // pixel, and a width animation would keep the bar redrawing every
      // frame, all the time.
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) root.next()
      else if ((mouse.button === Qt.LeftButton) === (root.clickMode === "card")) root.popupOpen = !root.popupOpen
      else root.toggle()
    }
    onWheel: function(wheel) {
      if (wheel.angleDelta.y === 0 || root.scrollMode === "off") return
      if (root.scrollMode === "volume") {
        root.setAppVolume(root.appVolume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        root.flashVolume()
      }
      else if (wheel.angleDelta.y > 0) root.previous()
      else root.next()
    }
  }

  // --- the card ---------------------------------------------------------------

  // A square-pixel bar (seek and volume): `value` 0..1 filled in the accent,
  // `ghost` (hover) previewed faintly.
  component PixelBar: Item {
    id: pixels
    property real value: 0
    property real ghost: -1
    property int cell: Style.space(4)
    property int gap: Math.max(1, Style.space(2))
    property int rows: 2
    property color fill: Color.accent
    property color track: tint(Color.popups.text, 0.14)
    // Fill from the right edge instead (the left half of the centered meter).
    property bool reverse: false
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property int count: Math.max(1, Math.floor((width + gap) / (cell + gap)))
    implicitHeight: rows * cell + (rows - 1) * gap

    Repeater {
      model: pixels.count * pixels.rows
      Rectangle {
        required property int index
        readonly property int column: index % pixels.count
        readonly property int row: Math.floor(index / pixels.count)
        // How much of this column the value covers (the last one partly).
        readonly property real share: Math.max(0, Math.min(1, pixels.value * pixels.count - column))
        readonly property bool ghosted: pixels.ghost >= 0 && column < pixels.ghost * pixels.count
        x: pixels.reverse ? pixels.width - (column + 1) * pixels.cell - column * pixels.gap : column * (pixels.cell + pixels.gap)
        y: row * (pixels.cell + pixels.gap)
        width: pixels.cell
        height: pixels.cell
        color: share > 0 ? pixels.fill : (ghosted ? pixels.tint(pixels.fill, 0.38) : pixels.track)
        opacity: share > 0 ? 0.35 + 0.65 * share : 1
      }
    }
  }

  // A flat icon button: a soft square on hover, a small press.
  component IconButton: Item {
    id: button
    property string glyph: ""
    property bool active: false
    property int glyphSize: Style.font.iconLarge
    property string fontFamily: Style.font.family
    // -1/1: the glyph darts that way when clicked (previous/next).
    property int nudge: 0
    readonly property color ink: Color.popups.text
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    signal clicked()
    width: Style.space(36)
    height: Style.space(36)
    opacity: enabled ? 1 : 0.3

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: button.tint(button.ink, buttonMouse.pressed ? 0.16 : 0.08)
      opacity: buttonMouse.containsMouse ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Text {
      anchors.centerIn: parent
      text: button.glyph
      color: button.active ? Color.accent : button.ink
      font.family: button.fontFamily
      font.pixelSize: button.glyphSize
      scale: buttonMouse.pressed ? 0.86 : 1
      Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
      Behavior on color { ColorAnimation { duration: 140 } }
      transform: Translate { id: dart }
    }
    SequentialAnimation {
      id: dartAnim
      NumberAnimation { target: dart; property: "x"; to: button.nudge * Style.space(6); duration: 90; easing.type: Easing.OutQuad }
      NumberAnimation { target: dart; property: "x"; to: 0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
    Rectangle {
      visible: button.active
      width: Style.space(4)
      height: width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(2)
      color: Color.accent
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: button.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: { if (button.nudge !== 0) dartAnim.restart(); button.clicked() }
    }
  }

  // One mixer row: icon (click to mute), name, square-pixel level, percent.
  component VolumeRow: Item {
    id: vrow
    property string name: ""
    property string icon: ""
    property string glyph: "󰝚"
    property real level: 0
    property bool muted: false
    property bool highlight: false
    property string fontFamily: Style.font.family
    readonly property color ink: Color.popups.text
    signal changeLevel(real value)
    signal toggleMute()
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    implicitHeight: Style.space(26)

    Item {
      id: vIcon
      width: Style.space(20)
      height: width
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      Image {
        id: vImage
        anchors.fill: parent
        source: vrow.icon
        sourceSize.width: 40
        sourceSize.height: 40
        asynchronous: true
        visible: vrow.icon !== "" && status === Image.Ready
        opacity: vrow.muted ? 0.3 : 1
      }
      Text {
        anchors.centerIn: parent
        visible: !vImage.visible || vrow.muted
        text: vrow.muted ? "󰝟" : vrow.glyph
        color: vrow.muted ? vrow.tint(vrow.ink, 0.8) : vrow.tint(vrow.ink, 0.7)
        font.family: vrow.fontFamily
        font.pixelSize: Style.font.title
      }
      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(3)
        cursorShape: Qt.PointingHandCursor
        onClicked: vrow.toggleMute()
      }
    }
    Text {
      id: vName
      anchors.left: vIcon.right
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(96)
      textFormat: Text.PlainText
      text: vrow.name
      color: vrow.highlight ? Color.accent : vrow.tint(vrow.ink, vrow.muted ? 0.45 : 0.8)
      font.family: vrow.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
    PixelBar {
      id: vBar
      anchors.left: vName.right
      anchors.right: vPercent.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      rows: 1
      value: vrow.muted ? 0 : Math.min(1, vrow.level)
      ghost: vMouse.containsMouse ? vMouse.fraction : -1
      fill: vrow.highlight ? Color.accent : vrow.tint(vrow.ink, 0.75)
    }
    Text {
      id: vPercent
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(38)
      horizontalAlignment: Text.AlignRight
      text: vrow.muted ? "muted" : Math.round(vrow.level * 100) + "%"
      color: vrow.tint(vrow.ink, 0.45)
      font.family: vrow.fontFamily
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      id: vMouse
      anchors.fill: vBar
      anchors.topMargin: -Style.space(8)
      anchors.bottomMargin: -Style.space(8)
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      readonly property real fraction: Math.max(0, Math.min(1, mouseX / Math.max(1, width)))
      onPressed: vrow.changeLevel(fraction)
      onPositionChanged: if (pressed) vrow.changeLevel(fraction)
      onWheel: function(wheel) { vrow.changeLevel(Math.max(0, Math.min(1, vrow.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(384))
    contentHeight: popup.fittedContentHeight(card.implicitHeight)

    Item {
      id: card
      anchors.fill: parent
      implicitHeight: body.implicitHeight
      focus: root.popupOpen

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space) root.toggle()
        else if (event.key === Qt.Key_Left) root.seekBy(-5)
        else if (event.key === Qt.Key_Right) root.seekBy(5)
        else if (event.key === Qt.Key_Up && root.hasAppVolume) root.setAppVolume(root.appVolume + 0.05)
        else if (event.key === Qt.Key_Down && root.hasAppVolume) root.setAppVolume(root.appVolume - 0.05)
        else if (event.key === Qt.Key_Escape) root.close()
        else return
        event.accepted = true
      }

      // Opening: the art block rises in, the controls follow.
      property real enter: 0
      Connections {
        target: root
        function onPopupOpenChanged() {
          if (root.popupOpen) { card.enter = 0; enterAnim.restart(); card.forceActiveFocus() }
        }
      }
      NumberAnimation { id: enterAnim; target: card; property: "enter"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }

      Column {
        id: body
        width: parent.width
        spacing: Style.space(14)

        // Art, over a blurred wash of itself.
        Item {
          id: hero
          width: parent.width

          // Skipping: art and words slide out the way you skipped and dim;
          // the next track slides in from the other side (its art assembling
          // out of pixels). A track that changes by itself slides in too.
          property real shift: 0
          property real dim: 1
          property real arriveFrom: 0
          readonly property real travel: Style.space(18)
          ParallelAnimation {
            id: skipOut
            NumberAnimation { target: hero; property: "shift"; to: -root.skipDir * hero.travel; duration: 170; easing.type: Easing.InCubic }
            NumberAnimation { target: hero; property: "dim"; to: 0.2; duration: 170; easing.type: Easing.InQuad }
          }
          ParallelAnimation {
            id: arrive
            NumberAnimation { target: hero; property: "shift"; from: hero.arriveFrom; to: 0; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: hero; property: "dim"; to: 1; duration: 340; easing.type: Easing.OutCubic }
          }
          // Nothing changed (e.g. "previous" restarted the same track): settle back.
          Timer {
            id: skipGuard
            interval: 1100
            onTriggered: { hero.arriveFrom = hero.shift; arrive.restart(); root.skipDir = 0 }
          }
          Connections {
            target: root
            function onSkipped(dir) { arrive.stop(); skipOut.restart(); skipGuard.restart() }
            function onTrackKeyChanged() {
              if (!root.popupOpen) return
              skipOut.stop()
              skipGuard.stop()
              hero.arriveFrom = (root.skipDir !== 0 ? root.skipDir : 1) * hero.travel
              root.skipDir = 0
              if (hero.dim > 0.99) hero.dim = 0.2
              arrive.restart()
            }
          }
          // Grows (the art doesn't) when a long title and album need the room.
          height: Math.max(Style.space(164), info.implicitHeight + Style.space(28))
          opacity: card.enter
          transform: Translate { y: (1 - card.enter) * Style.space(8) }

          Rectangle {
            id: heroClip
            anchors.fill: parent
            radius: Style.cornerRadius
            color: root.tint(root.text, 0.05)
            clip: true
            layer.enabled: Style.cornerRadius > 0
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: heroMask
            }

            Image {
              id: wash
              anchors.fill: parent
              anchors.margins: -Style.space(30)
              source: root.shownArt
              sourceSize.width: 320
              sourceSize.height: 320
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: false
            }
            MultiEffect {
              anchors.fill: wash
              source: wash
              visible: wash.status === Image.Ready
              blurEnabled: true
              blur: 1.0
              blurMax: 48
              saturation: 0.15
              brightness: -0.1
              opacity: 0.55
            }
            // Fade the wash into the card's own colour at the right.
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.tint(Color.popups.background, 0.1) }
                GradientStop { position: 1.0; color: root.tint(Color.popups.background, 0.75) }
              }
            }
          }
          Rectangle {
            id: heroMask
            anchors.fill: parent
            radius: Style.cornerRadius
            visible: false
            layer.enabled: true
          }

          Item {
            id: artBox
            x: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(140)
            height: width
            opacity: hero.dim
            transform: Translate { x: hero.shift }

            // Soft shadow under the art.
            Rectangle {
              id: shadowShape
              anchors.fill: parent
              color: "black"
              radius: Style.cornerRadius
              visible: false
            }
            MultiEffect {
              anchors.fill: shadowShape
              source: shadowShape
              shadowEnabled: true
              shadowBlur: 0.8
              shadowOpacity: 0.45
              shadowVerticalOffset: Style.space(4)
              shadowColor: "black"
              opacity: art.status === Image.Ready ? 1 : 0
            }

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: root.tint(root.text, 0.08)
              border.width: 1
              border.color: root.tint(root.text, 0.14)
              visible: art.status !== Image.Ready
              Text {
                anchors.centerIn: parent
                text: "󰝚"
                color: root.tint(root.text, 0.6)
                font.family: root.fontFamily
                font.pixelSize: Math.round(parent.width * 0.4)
              }
            }
            Image {
              id: art
              anchors.fill: parent
              source: root.shownArt
              sourceSize.width: 320
              sourceSize.height: 320
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              mipmap: true
              visible: status === Image.Ready
              // Still drawn under an art effect, which reads it as a texture.
              opacity: artFx.visible ? 0 : 1
              layer.enabled: Style.cornerRadius > 0
              layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
            }
            // The art effect (shaders/artfx.frag), on the GPU; its beat moves
            // only while the card is open and playing.
            ShaderEffect {
              id: artFx
              anchors.fill: art
              visible: root.artEffect !== "off" && art.status === Image.Ready
              property variant source: art
              property real tick: 0
              readonly property real mode: Math.max(0, root.artEffects.indexOf(root.artEffect))
              readonly property real aspect: width / Math.max(1, height)
              fragmentShader: Qt.resolvedUrl("shaders/artfx.frag.qsb")
              Timer {
                running: artFx.visible && root.popupOpen && root.playing
                interval: 66
                repeat: true
                onTriggered: artFx.tick += 1
              }
            }
            // What right / middle click just switched to.
            Rectangle {
              id: fxToast
              property string text: ""
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(8)
              width: toastText.implicitWidth + Style.space(14)
              height: toastText.implicitHeight + Style.space(6)
              radius: Style.cornerRadius
              color: root.tint(Color.popups.background, 0.85)
              opacity: 0
              z: 5
              function show(t) { text = t; toastAnim.restart() }
              Text {
                id: toastText
                anchors.centerIn: parent
                text: fxToast.text
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: fxToast; property: "opacity"; to: 1; duration: 120 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: fxToast; property: "opacity"; to: 0; duration: 300 }
              }
            }
            Rectangle {
              id: artMask
              anchors.fill: parent
              radius: Style.cornerRadius
              visible: false
              layer.enabled: true
            }

            // New track: the art assembles out of pixels.
            PixelCover {
              id: artReveal
              anchors.fill: parent
              cell: Math.max(4, Math.round(parent.width / 18))
              coverColor: root.tint(root.text, 0.06)
              progress: 1.2
              visible: artAssemble.running
            }
            NumberAnimation {
              id: artAssemble
              target: artReveal
              property: "progress"
              from: -0.1
              to: 1.2
              duration: 520
              easing.type: Easing.OutQuad
            }
            Connections {
              target: root
              function onShownArtChanged() {
                if (root.shownArt !== "" && root.popupOpen) { artReveal.reseed(); artAssemble.restart() }
              }
            }

            // Hover: "go to the app".
            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: root.tint(Color.popups.background, 0.6)
              opacity: artMouse.containsMouse ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 140 } }
              Column {
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰏌"
                  color: root.text
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.appName ? "Open " + root.appName : "Open"
                  color: root.text
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  width: Math.min(implicitWidth, artBox.width - Style.space(12))
                  elide: Text.ElideRight
                }
              }
            }
            MouseArea {
              id: artMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              // Left: go to the app. Right: next visualizer. Middle: next art effect.
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                  root.cardVisual = root.stepSetting("nowPlayingVisual", root.visuals, root.cardVisual)
                  fxToast.show(root.visualNames[root.cardVisual])
                } else if (mouse.button === Qt.MiddleButton) {
                  root.artEffect = root.stepSetting("nowPlayingArtFx", root.artEffects, root.artEffect)
                  fxToast.show(root.artEffectNames[root.artEffect])
                } else root.raiseApp()
              }
            }
          }

          Column {
            id: info
            anchors.left: artBox.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            // The words travel a little further than the art (parallax).
            opacity: hero.dim
            transform: Translate { x: hero.shift * 1.5 }

            Row {
              spacing: Style.space(7)
              height: Math.max(eq.height, statusLabel.implicitHeight)

              Equalizer {
                id: eq
                anchors.verticalCenter: parent.verticalCenter
                columns: 6
                rows: 5
                pixel: Math.max(3, Style.space(3))
                gap: 1
                playing: root.playing && root.popupOpen
                silent: !root.playing
                style: root.eqStyle(root.headerEq)
                // One per card: only when the card visualizer below is off.
                visible: root.headerEq !== "off" && root.cardVisual === "off"
                color: root.accent
              }
              Text {
                id: statusLabel
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.playing ? "NOW PLAYING" : "PAUSED"
                color: root.tint(root.text, 0.55)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1.5
              }
            }

            Item { width: 1; height: Style.space(2) }

            Text {
              textFormat: Text.PlainText
              text: root.title || "Nothing playing"
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.title + Style.space(2)
              font.bold: true
              width: parent.width
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              lineHeight: 1.05
            }
            Text {
              textFormat: Text.PlainText
              text: root.artist
              visible: text !== ""
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              width: parent.width
              elide: Text.ElideRight
            }
            // Wraps at words, up to three lines; a subtitle ("Name: Subtitle",
            // "Name - Subtitle", "Name (Deluxe)") starts on its own line.
            Text {
              textFormat: Text.PlainText
              text: {
                var a = root.album
                var m = /^(.+?)(: | - | – | — | \(| \[)(.+)$/.exec(a)
                if (!m) return a
                var sep = m[2].trim()
                return sep === "(" || sep === "[" ? m[1] + "\n" + sep + m[3]
                  : sep === ":" ? m[1] + ":\n" + m[3] : m[1] + "\n" + m[3]
              }
              visible: text !== ""
              color: root.tint(root.text, 0.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              width: parent.width
              wrapMode: Text.WordWrap
              maximumLineCount: 3
              elide: Text.ElideRight
              lineHeight: 1.1
            }
          }
        }

        // The visualizer: the equalizer style, card-wide (Taskbar & Desktop >
        // Now Playing > Visualizer). Big pixels keep it to ~300 cells, and it
        // only runs while the card is open and playing.
        Item {
          id: visualizer
          visible: root.cardVisual !== "off"
          width: parent.width
          height: !visible ? 0 : root.cardVisual === "pixel" ? vis.height : Style.space(72)
          opacity: card.enter * 0.85
          Visualizer {
            anchors.fill: parent
            visible: root.cardVisual !== "pixel"
            scene: root.cardVisual
            playing: root.playing && root.popupOpen && visualizer.visible && visible
            colorA: root.accent
            colorB: root.text
          }
          Equalizer {
            id: vis
            visible: root.cardVisual === "pixel"
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property int cell: Math.max(6, Style.space(6))
            pixel: cell
            gap: 2
            columns: Math.max(8, Math.floor((visualizer.width + gap) / (cell + gap)))
            rows: 5
            playing: root.playing && root.popupOpen && visualizer.visible && visible
            silent: !root.playing
            style: root.eqStyle(root.cardEq)
            color: root.accent
          }
        }

        // Seek: elapsed · pixels · remaining. A stream with no length says so.
        Item {
          id: seek
          width: parent.width
          height: Math.max(seekBar.implicitHeight, elapsed.implicitHeight) + Style.space(6)
          opacity: card.enter
          transform: Translate { y: (1 - card.enter) * Style.space(12) }

          property real dragValue: -1
          readonly property real shown: dragValue >= 0 ? dragValue : root.progress

          Text {
            id: elapsed
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(44)
            textFormat: Text.PlainText
            text: root.length > 0 ? root.clock(seek.shown * root.length) : root.clock(root.position)
            color: root.tint(root.text, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          PixelBar {
            id: seekBar
            visible: root.length > 0
            anchors.left: elapsed.right
            anchors.right: remaining.left
            anchors.leftMargin: Style.space(4)
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            value: seek.shown
            ghost: seekMouse.containsMouse && seek.dragValue < 0 ? seekMouse.fraction : -1
            fill: root.playing ? root.accent : root.tint(root.accent, 0.7)
          }
          Text {
            visible: root.length <= 0
            anchors.centerIn: parent
            text: "LIVE"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }
          Text {
            id: remaining
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(44)
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: root.length > 0 ? "-" + root.clock(root.length - seek.shown * root.length) : ""
            color: root.tint(root.text, 0.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: seekMouse
            anchors.fill: seekBar
            anchors.topMargin: -Style.space(6)
            anchors.bottomMargin: -Style.space(6)
            enabled: root.canSeek
            hoverEnabled: true
            cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
            readonly property real fraction: Math.max(0, Math.min(1, mouseX / Math.max(1, width)))
            onPressed: seek.dragValue = fraction
            onPositionChanged: if (pressed) seek.dragValue = fraction
            onReleased: { root.seekTo(seek.dragValue); seek.dragValue = -1 }
            onCanceled: seek.dragValue = -1
          }

          // Hover: the time under the pointer.
          Rectangle {
            visible: seekMouse.containsMouse && root.canSeek
            x: Math.max(0, Math.min(seek.width - width, seekBar.x + seekMouse.mouseX - width / 2))
            y: seekBar.y - height - Style.space(6)
            width: hoverTime.implicitWidth + Style.space(10)
            height: hoverTime.implicitHeight + Style.space(4)
            radius: Style.cornerRadius
            color: Color.popups.background
            border.width: 1
            border.color: root.tint(root.accent, 0.6)
            Text {
              id: hoverTime
              anchors.centerIn: parent
              text: root.clock((seek.dragValue >= 0 ? seek.dragValue : seekMouse.fraction) * root.length)
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Transport.
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(10)
          opacity: card.enter
          transform: Translate { y: (1 - card.enter) * Style.space(16) }

          IconButton {
            fontFamily: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.player && root.player.shuffleSupported
            glyph: root.player && root.player.shuffle ? "󰒝" : "󰒞"
            active: !!root.player && root.player.shuffle
            glyphSize: Style.font.title + Style.space(2)
            onClicked: root.toggleShuffle()
          }
          IconButton {
            fontFamily: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            glyph: "󰒮"
            nudge: -1
            enabled: root.canPrevious
            onClicked: root.skip(-1)
          }

          // Play/pause: a filled accent square; the glyph pops on change.
          Item {
            id: play
            width: Style.space(50)
            height: Style.space(50)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: root.accent
              scale: playMouse.pressed ? 0.93 : (playMouse.containsMouse ? 1.04 : 1)
              Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
            }
            Text {
              id: playGlyph
              anchors.centerIn: parent
              anchors.horizontalCenterOffset: root.playing ? 0 : Style.space(1)
              text: root.playing ? "󰏤" : "󰐊"
              color: Color.popups.background
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              onTextChanged: playPop.restart()
              SequentialAnimation on scale {
                id: playPop
                running: false
                NumberAnimation { to: 0.7; duration: 70; easing.type: Easing.InQuad }
                NumberAnimation { to: 1.0; duration: 180; easing.type: Easing.OutBack }
              }
            }
            MouseArea {
              id: playMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggle()
            }
          }

          IconButton {
            fontFamily: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            glyph: "󰒭"
            nudge: 1
            enabled: root.canNext
            onClicked: root.skip(1)
          }
          IconButton {
            fontFamily: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.player && root.player.loopSupported
            readonly property int loopMode: root.player ? root.player.loopState : MprisLoopState.None
            glyph: loopMode === MprisLoopState.Track ? "󰑘" : (loopMode === MprisLoopState.Playlist ? "󰑖" : "󰑗")
            active: loopMode !== MprisLoopState.None
            glyphSize: Style.font.title + Style.space(2)
            onClicked: root.cycleLoop()
          }
        }

        // Volume: the playing app's, and (chevron) the mixer: the system and
        // every other app playing sound. Click an icon to mute.
        Column {
          width: parent.width
          spacing: Style.space(2)
          opacity: card.enter
          transform: Translate { y: (1 - card.enter) * Style.space(20) }

          Item {
            width: parent.width
            height: appRow.implicitHeight

            VolumeRow {
              id: appRow
              anchors.left: parent.left
              anchors.right: mixerToggle.left
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              fontFamily: root.fontFamily
              readonly property bool isApp: root.hasAppVolume
              name: isApp ? (root.appName || "This app") : "System"
              icon: isApp ? root.playerAppIcon() : ""
              glyph: isApp ? "󰝚" : "󰓃"
              level: isApp ? root.appVolume : (root.outputSink && root.outputSink.audio ? root.outputSink.audio.volume : 0)
              muted: isApp ? root.appMuted : (!!root.outputSink && !!root.outputSink.audio && root.outputSink.audio.muted)
              highlight: isApp
              onChangeLevel: function(v) {
                if (isApp) root.setAppVolume(v)
                else if (root.outputSink && root.outputSink.audio) root.outputSink.audio.volume = v
              }
              onToggleMute: {
                if (isApp) root.toggleAppMute()
                else if (root.outputSink && root.outputSink.audio) root.outputSink.audio.muted = !root.outputSink.audio.muted
              }
            }
            IconButton {
              id: mixerToggle
              fontFamily: root.fontFamily
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(28)
              height: Style.space(28)
              glyph: "󰅀"
              glyphSize: Style.font.title
              rotation: root.mixerOpen ? 180 : 0
              Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
              onClicked: root.toggleMixer()
            }
          }

          Item {
            id: mixerBox
            width: parent.width
            height: root.mixerOpen ? mixerColumn.implicitHeight + Style.space(6) : 0
            clip: true
            opacity: root.mixerOpen ? 1 : 0
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Column {
              id: mixerColumn
              y: Style.space(6)
              width: parent.width - mixerToggle.width - Style.space(4)
              spacing: Style.space(2)

              Rectangle { width: parent.width; height: 1; color: root.tint(root.text, 0.1) }
              Item { width: 1; height: Style.space(4) }

              VolumeRow {
                width: parent.width
                visible: appRow.isApp
                fontFamily: root.fontFamily
                name: "System"
                glyph: "󰓃"
                level: root.outputSink && root.outputSink.audio ? root.outputSink.audio.volume : 0
                muted: !!root.outputSink && !!root.outputSink.audio && root.outputSink.audio.muted
                onChangeLevel: function(v) { if (root.outputSink && root.outputSink.audio) root.outputSink.audio.volume = v }
                onToggleMute: if (root.outputSink && root.outputSink.audio) root.outputSink.audio.muted = !root.outputSink.audio.muted
              }

              Repeater {
                model: root.streams

                VolumeRow {
                  id: streamRow
                  required property var modelData
                  width: mixerColumn.width
                  visible: !!modelData && !!modelData.audio && modelData !== root.playerStream
                  fontFamily: root.fontFamily
                  name: root.streamName(modelData)
                  icon: root.streamIcon(modelData)
                  level: modelData && modelData.audio ? modelData.audio.volume : 0
                  muted: !!modelData && !!modelData.audio && modelData.audio.muted
                  onChangeLevel: function(v) {
                    if (!streamRow.modelData || !streamRow.modelData.audio) return
                    streamRow.modelData.audio.volume = v
                    if (v > 0 && streamRow.modelData.audio.muted) streamRow.modelData.audio.muted = false
                  }
                  onToggleMute: if (streamRow.modelData && streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                }
              }

              Text {
                visible: {
                  for (var i = 0; i < root.streams.length; i++)
                    if (root.streams[i] && root.streams[i].audio && root.streams[i] !== root.playerStream) return false
                  return true
                }
                leftPadding: Style.space(28)
                topPadding: Style.space(2)
                text: "No other apps playing"
                color: root.tint(root.text, 0.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // More than one app with something loaded: switch between them.
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: root.trackPlayers.length > 1
          opacity: card.enter

          Repeater {
            model: root.trackPlayers

            Rectangle {
              id: chip
              required property var modelData
              readonly property bool selected: root.keyOf(modelData) === root.keyOf(root.player)
              width: chipRow.implicitWidth + Style.space(14)
              height: chipRow.implicitHeight + Style.space(8)
              radius: Style.cornerRadius
              color: selected ? root.tint(root.accent, 0.16) : (chipMouse.containsMouse ? root.tint(root.text, 0.08) : "transparent")
              border.width: 1
              border.color: selected ? root.accent : root.tint(root.text, 0.16)
              Behavior on color { ColorAnimation { duration: 120 } }

              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Style.space(6)
                Image {
                  id: chipArt
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(16)
                  height: width
                  source: chip.modelData ? String(chip.modelData.trackArtUrl || "") : ""
                  sourceSize.width: 32
                  sourceSize.height: 32
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  visible: status === Image.Ready
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: chip.modelData && chip.modelData.isPlaying ? "󰐊" : "󰏤"
                  visible: !chipArt.visible
                  color: root.tint(root.text, 0.6)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: chip.modelData ? String(chip.modelData.identity || chip.modelData.desktopEntry || "Player") : ""
                  color: chip.selected ? root.text : root.tint(root.text, 0.7)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.preferredKey = root.keyOf(chip.modelData)
              }
            }
          }
        }
      }
    }
  }
}
