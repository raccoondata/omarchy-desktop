import QtQuick
import qs.Commons
import "AudioLevels.js" as AudioLevels
import "Visuals.js" as Visuals

// The now-playing card's visualizer scenes, after Windows Media Player's,
// drawn on the GPU by shaders/visualizer.frag, following the music (cava, via
// AudioLevels.js). The CPU only hands over the spectrum and advances `tick`
// (15 a second) while `playing`, so a scene costs the same as a still one.
//   tunnel  kaleido  starfield  battery  lava  lissajous  aurora  woods
//   glitch  signal  blocks  sorted (the glitch family)
ShaderEffect {
  id: vis

  property string scene: "tunnel"
  property bool playing: false
  property bool saving: false      // saving power: hold still (AudioLevels.saving)
  property int grain: 2            // pixel size: 1 smooth, 2-4 chunkier
  property color colorA: Color.accent
  property color colorB: Color.foreground

  // The order is the shader's scene index (Visuals.js).
  readonly property var scenes: Visuals.values(Visuals.scenes)

  // The shader's inputs (names match shaders/visualizer.frag).
  property real tick: Math.floor(Math.random() * 1000)
  readonly property real sceneIndex: Math.max(0, scenes.indexOf(scene))
  readonly property real w: width
  readonly property real h: height
  readonly property real grainPx: Math.max(1, grain)
  readonly property color inkA: colorA
  readonly property color inkB: colorB
  // The music (AudioLevels.js), when cava is sending.
  property real live: 0
  property real beatLevel: 0
  property real pump: 0
  property real loudness: 0
  property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)
  property vector4d bandsB: Qt.vector4d(0, 0, 0, 0)
  property vector4d bandsC: Qt.vector4d(0, 0, 0, 0)
  property vector4d bandsD: Qt.vector4d(0, 0, 0, 0)
  property int seenFrame: -1
  // Signal loss's 8 waves: how far each has travelled. Each moves only while
  // its band of the music plays (bass waves roll with the bass, treble
  // wiggles with the highs), and the kicks shove them all.
  property vector4d wavePhaseA: Qt.vector4d(0, 0, 0, 0)
  property vector4d wavePhaseB: Qt.vector4d(0, 0, 0, 0)
  function moveWaves() {
    var p = [wavePhaseA.x, wavePhaseA.y, wavePhaseA.z, wavePhaseA.w, wavePhaseB.x, wavePhaseB.y, wavePhaseB.z, wavePhaseB.w]
    for (var i = 0; i < 8; i++) {
      var step = live ? AudioLevels.bands[Math.round(i / 7 * 15)] * (0.16 + 0.06 * i) + 0.1 * AudioLevels.beat
                      : (1.2 + 0.35 * i) / 15   // without cava: the clock, as before
      p[i] = (p[i] + step) % (2 * Math.PI)
    }
    wavePhaseA = Qt.vector4d(p[0], p[1], p[2], p[3])
    wavePhaseB = Qt.vector4d(p[4], p[5], p[6], p[7])
  }

  fragmentShader: Qt.resolvedUrl("shaders/visualizer.frag.qsb")

  Timer {
    running: vis.playing && !vis.saving && vis.visible
    interval: 66
    repeat: true
    onTriggered: {
      AudioLevels.feed(vis)
      // Faster when louder.
      vis.tick += vis.live ? 0.5 + 1.5 * AudioLevels.level : 1
      if (vis.scene === "signal") vis.moveWaves()
    }
  }
}
