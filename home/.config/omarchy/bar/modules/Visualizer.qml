import QtQuick
import qs.Commons
import "AudioLevels.js" as AudioLevels

// The now-playing card's visualizer scenes, after Windows Media Player's,
// drawn on the GPU by shaders/visualizer.frag, following the music (cava, via
// AudioLevels.js). The CPU only hands over the spectrum and advances `tick`
// (15 a second) while `playing`, so a scene costs the same as a still one.
//   tunnel  kaleido  starfield  battery  lava  lissajous  aurora  woods
ShaderEffect {
  id: vis

  property string scene: "tunnel"
  property bool playing: false
  property int grain: 2            // pixel size: 1 smooth, 2-4 chunkier
  property color colorA: Color.accent
  property color colorB: Color.foreground

  readonly property var scenes: ["tunnel", "kaleido", "starfield", "battery", "lava", "lissajous", "aurora", "woods"]

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

  fragmentShader: Qt.resolvedUrl("shaders/visualizer.frag.qsb")

  Timer {
    running: vis.playing && vis.visible
    interval: 66
    repeat: true
    onTriggered: {
      AudioLevels.feed(vis)
      // Faster when louder.
      vis.tick += vis.live ? 0.5 + 1.5 * AudioLevels.level : 1
    }
  }
}
