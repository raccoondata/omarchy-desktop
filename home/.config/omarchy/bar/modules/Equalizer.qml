import QtQuick
import qs.Commons

// The pixel equalizer behind a taskbar icon while its app plays sound, and
// the now-playing card's visualizer. Drawn entirely on the GPU by one shader
// (shaders/equalizer.frag): the CPU only advances `tick` about ten times a
// second, and only while playing and shown, whatever the style or size. The
// motion is decorative, not the real audio level. Muted: one flat row.
//
//   spectrum  columns step toward random heights, tallest in the middle
//   wave      a wave rolls across the columns
//   embers    pixels rise from the bottom and fade as they climb
//   ripple    rings pulse out from the bottom centre, like a speaker cone
// After Windows Media Player's visualizations, on the same pixel grid:
//   scope     an oscilloscope line ("Bars and Waves: Scope")
//   mist      bars mirrored from the middle, leaving a trail ("Ocean Mist")
//   fire      flames that cool as they rise ("Fire Storm")
//   radar     a sweeping beam with an afterglow ("Battery")
//   swirl     two spiral arms turning ("Ambience")
//   plasma    a slow interference pattern in four steps ("Alchemy")
//   rain      drops falling a row at a time
//   shuffle   a different one every 20 seconds, the same for every equalizer
ShaderEffect {
  id: eq

  property int columns: 10
  property int rows: 8
  property int pixel: 3
  property int gap: 1
  property bool playing: false
  property bool silent: false
  property string style: "spectrum"
  property color color: Color.accent

  readonly property var styles: ["spectrum", "wave", "embers", "ripple", "scope", "mist", "fire", "radar", "swirl", "plasma", "rain"]
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
  readonly property real mute: silent ? 1 : 0
  readonly property color ink: color

  fragmentShader: Qt.resolvedUrl("shaders/equalizer.frag.qsb")

  Timer {
    running: eq.playing && !eq.silent && eq.visible
    interval: 100
    repeat: true
    onTriggered: {
      eq.tick += 1
      if (eq.style === "shuffle" && eq.tick % 20 === 0)
        eq.shown = eq.styles[Math.floor(Date.now() / 20000) % eq.styles.length]
    }
  }
}
