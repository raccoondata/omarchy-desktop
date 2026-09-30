# written to: ~/.config/omarchy/bar/modules/Equalizer.qml
import QtQuick
import qs.Commons

// The pixel equalizer behind a taskbar icon while its app plays sound. Every
// style is drawn on the same grid of square pixels in the accent colour; each
// pixel has a brightness 0..1 recomputed a few times a second. The motion is
// decorative, not the real audio level. Muted: one flat, faint row.
//
//   spectrum  columns step toward random heights, tallest in the middle
//   wave      a wave rolls across the columns
//   embers    pixels rise from the bottom and fade as they climb
//   ripple    rings pulse out from the bottom centre, like a speaker cone
Item {
  id: eq

  property int columns: 10
  property int rows: 8
  property int pixel: 3
  property int gap: 1
  property bool playing: false
  property bool silent: false
  property string style: "spectrum"
  property color color: Color.accent

  width: columns * pixel + (columns - 1) * gap
  height: rows * pixel + (rows - 1) * gap

  // Brightness per pixel, row-major with row 0 at the bottom.
  property var cells: []
  property real phase: 0
  property var levels: []
  property var targets: []
  property var embers: []

  readonly property int count: columns * rows

  function blank() {
    var list = new Array(count)
    for (var i = 0; i < count; i++) list[i] = 0
    return list
  }

  // Columns filled up to a height each (spectrum, wave).
  function fromLevels(levels) {
    var list = blank()
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < Math.min(rows, levels[c] || 0); r++) {
        // A touch brighter toward the top of each column.
        list[r * columns + c] = 0.7 + 0.3 * (r + 1) / Math.max(1, levels[c])
      }
    }
    return list
  }

  function reach(column) {
    var middle = (columns - 1) / 2
    var away = middle > 0 ? Math.abs(column - middle) / middle : 0
    return Math.max(1, Math.round(rows * (1 - 0.55 * away)))
  }

  function stepSpectrum() {
    var levels = eq.levels.length === columns ? eq.levels.slice() : new Array(columns).fill(1)
    var targets = eq.targets.length === columns ? eq.targets.slice() : new Array(columns).fill(1)
    for (var c = 0; c < columns; c++) {
      if (levels[c] === targets[c]) targets[c] = 1 + Math.floor(Math.random() * reach(c))
      levels[c] += levels[c] < targets[c] ? 1 : (levels[c] > targets[c] ? -1 : 0)
    }
    eq.levels = levels
    eq.targets = targets
    return fromLevels(levels)
  }

  function stepWave() {
    phase += 0.42
    var levels = []
    for (var c = 0; c < columns; c++) {
      // Two waves at different speeds, so it never quite repeats.
      var v = 0.6 * Math.sin(phase + c * 0.75) + 0.4 * Math.sin(phase * 0.55 - c * 0.4)
      levels.push(1 + Math.round((v * 0.5 + 0.5) * (reach(c) - 1)))
    }
    return fromLevels(levels)
  }

  function stepEmbers() {
    var list = blank()
    var next = []
    for (var i = 0; i < embers.length; i++) {
      var e = embers[i]
      // Rise a row, drifting sideways now and then.
      var row = e.row + 1
      var column = Math.max(0, Math.min(columns - 1, e.column + (Math.random() < 0.2 ? (Math.random() < 0.5 ? -1 : 1) : 0)))
      if (row < e.top) next.push({ column: column, row: row, top: e.top })
    }
    // New embers from the bottom, more toward the middle.
    for (var c = 0; c < columns; c++) {
      if (Math.random() < 0.08 + 0.18 * reach(c) / rows) next.push({ column: c, row: 0, top: 2 + Math.floor(Math.random() * (rows - 1)) })
    }
    embers = next
    for (var j = 0; j < next.length; j++) {
      var k = next[j].row * columns + next[j].column
      list[k] = Math.max(list[k], 1 - next[j].row / rows)
    }
    return list
  }

  function stepRipple() {
    phase += 0.5
    var list = blank()
    var middle = (columns - 1) / 2
    var period = rows * 0.9
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        var d = Math.sqrt((c - middle) * (c - middle) * 0.55 + r * r)
        // Rings move outward: the distance to the nearest ring front.
        var front = (d - phase) % period
        if (front < 0) front += period
        if (front < 1) list[r * columns + c] = Math.max(0, 1 - d / (rows * 1.3))
      }
    }
    return list
  }

  function step() {
    if (silent) {
      var flat = blank()
      for (var c = 0; c < columns; c++) flat[c] = 1
      cells = flat
      return
    }
    if (style === "wave") cells = stepWave()
    else if (style === "embers") cells = stepEmbers()
    else if (style === "ripple") cells = stepRipple()
    else cells = stepSpectrum()
  }

  onSilentChanged: step()
  onStyleChanged: {
    embers = []
    step()
  }
  onPlayingChanged: if (playing) step()

  Timer {
    running: eq.playing && !eq.silent
    interval: eq.style === "embers" ? 110 : 95
    repeat: true
    onTriggered: eq.step()
  }

  Repeater {
    model: eq.count

    Rectangle {
      required property int index
      readonly property real level: eq.cells[index] || 0
      readonly property int column: index % eq.columns
      readonly property int row: Math.floor(index / eq.columns)

      x: column * (eq.pixel + eq.gap)
      y: eq.height - (row + 1) * eq.pixel - row * eq.gap
      width: eq.pixel
      height: eq.pixel
      color: eq.color
      visible: level > 0.02
      opacity: level
    }
  }
}
