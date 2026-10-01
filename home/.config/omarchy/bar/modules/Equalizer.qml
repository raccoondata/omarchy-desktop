import QtQuick
import qs.Commons
import "AudioLevels.js" as AudioLevels
import "Visuals.js" as Visuals

// The pixel equalizer behind a taskbar icon while its app plays sound, and
// the now-playing card's visualizer. Drawn entirely on the GPU by one shader
// (shaders/equalizer.frag): the CPU only hands it the music's spectrum and a
// tick, 10 times a second, and only while playing and shown, whatever the
// style or size. The music comes from cava (AudioLevels.js): bars follow the
// real bands, speed and glitches the loudness and kicks. Without cava: generated motion.
// Muted, or saving power (`saving`, AudioLevels.saving): one flat row.
//
// Styles (Visuals.js), one per look; spectrum to plasma also get a glitch
// layer (rows torn on the hits, an echo on the bass, dropouts on kicks):
//   spectrum  the music's bands as bars
//   mist      bars mirrored from the middle, leaving a trail ("Ocean Mist")
//   scope     an oscilloscope line ("Bars and Waves: Scope")
//   radar     a sweeping beam with an afterglow ("Battery")
//   plasma    an interference pattern in four steps ("Alchemy")
//   static    snow in the spectrum's shape, a row of solid static on kicks
//   corrupt   the spectrum in blocks, some showing the wrong one, a column
//             now and then upside down
//   shuffle   a different one every 20 seconds, the same for every equalizer
ShaderEffect {
  id: eq

  property int columns: 10
  property int rows: 8
  property int pixel: 3
  property int gap: 1
  property bool playing: false
  property bool silent: false
  property bool saving: false
  property string style: "spectrum"
  property color color: Color.accent

  // The order is the shader's style index (Visuals.js).
  readonly property var styles: Visuals.values(Visuals.eqStyles)
  // Shuffle: the same style everywhere at once, by the clock.
  property string shown: style === "shuffle" ? styles[Math.floor(Date.now() / 20000) % styles.length] : style

  width: columns * pixel + (columns - 1) * gap
  height: rows * pixel + (rows - 1) * gap

  // The shader's inputs (names match shaders/equalizer.frag).
  property real tick: Math.floor(Math.random() * 1000)
  readonly property real styleIndex: Math.max(0, styles.indexOf(shown))
  readonly property real cols: columns
  readonly property real rowCount: rows
  readonly property real px: pixel
  readonly property real gapPx: gap
  readonly property real mute: silent || saving ? 1 : 0
  readonly property color ink: color
  property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)
  property vector4d bandsB: Qt.vector4d(0, 0, 0, 0)
  property vector4d bandsC: Qt.vector4d(0, 0, 0, 0)
  property vector4d bandsD: Qt.vector4d(0, 0, 0, 0)
  property real live: 0
  property real loudness: 0
  property real bass: 0
  property real beatLevel: 0
  property real pump: 0
  property int seenFrame: -1

  fragmentShader: Qt.resolvedUrl("shaders/equalizer.frag.qsb")

  Timer {
    running: eq.playing && !eq.silent && !eq.saving && eq.visible
    interval: 100
    repeat: true
    onTriggered: {
      // Faster when louder.
      eq.tick += AudioLevels.feed(eq) ? 0.4 + 1.4 * AudioLevels.level : 0.66
      if (eq.style === "shuffle" && eq.tick % 20 === 0)
        eq.shown = eq.styles[Math.floor(Date.now() / 20000) % eq.styles.length]
    }
  }
}
