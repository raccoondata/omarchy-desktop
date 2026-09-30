import QtQuick
import qs.Commons

// The pixel equalizer behind a taskbar icon while its app plays sound, and
// the now-playing card's visualizer. Every style is drawn on the same grid of
// square pixels in one colour; each pixel has a brightness 0..1 recomputed
// about ten times a second, and only while playing and shown (the Timer
// stops otherwise), so a style costs a few dozen multiplications a tick. The
// motion is decorative, not the real audio level. Muted: one flat row.
//
//   spectrum  columns step toward random heights, tallest in the middle
//   wave      a wave rolls across the columns
//   embers    pixels rise from the bottom and fade as they climb
//   ripple    rings pulse out from the bottom centre, like a speaker cone
// After Windows Media Player's visualizations, on the same pixel grid:
//   scope     an oscilloscope line ("Bars and Waves: Scope")
//   mist      bars mirrored from the middle, leaving a fading trail ("Ocean Mist")
//   fire      flames that cool as they rise ("Fire Storm")
//   radar     a sweeping beam with an afterglow ("Battery")
//   swirl     two spiral arms turning ("Ambience")
//   plasma    a slow interference pattern in four steps of brightness ("Alchemy")
//   rain      drops falling and splashing
//   shuffle   a different one every 20 seconds, the same for every equalizer
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

  // The last frame, dimmed: the trail the afterglow styles draw on.
  function afterglow(factor) {
    var list = blank()
    if (cells.length === count) for (var i = 0; i < count; i++) list[i] = cells[i] > 0.05 ? cells[i] * factor : 0
    return list
  }

  function stepScope() {
    phase += 0.35
    var list = afterglow(0.35)
    var mid = (rows - 1) / 2
    var prev = -1
    for (var c = 0; c < columns; c++) {
      var v = 0.6 * Math.sin(phase + c * 0.8) + 0.4 * Math.sin(phase * 1.7 - c * 0.45)
      var y = Math.max(0, Math.min(rows - 1, Math.round(mid + v * mid)))
      // Joined to the previous column, so it reads as one line.
      if (prev >= 0) for (var r = Math.min(prev, y); r <= Math.max(prev, y); r++) list[r * columns + c] = Math.max(list[r * columns + c], 0.8)
      list[y * columns + c] = 1
      prev = y
    }
    return list
  }

  function stepMist() {
    var levels = eq.levels.length === columns ? eq.levels.slice() : new Array(columns).fill(1)
    var targets = eq.targets.length === columns ? eq.targets.slice() : new Array(columns).fill(1)
    var half = Math.max(1, Math.floor(rows / 2))
    for (var c = 0; c < columns; c++) {
      var most = Math.max(1, Math.round(half * reach(c) / rows))
      if (levels[c] === targets[c] || targets[c] > most) targets[c] = 1 + Math.floor(Math.random() * most)
      levels[c] += levels[c] < targets[c] ? 1 : (levels[c] > targets[c] ? -1 : 0)
    }
    eq.levels = levels
    eq.targets = targets
    var list = afterglow(0.5)
    var mid = (rows - 1) / 2
    for (var c2 = 0; c2 < columns; c2++) {
      for (var d = 0; d < levels[c2]; d++) {
        var up = Math.ceil(mid) + d, down = Math.floor(mid) - d
        var b = 1 - 0.5 * d / half
        if (up < rows) list[up * columns + c2] = Math.max(list[up * columns + c2], b)
        if (down >= 0) list[down * columns + c2] = Math.max(list[down * columns + c2], b)
      }
    }
    return list
  }

  function stepFire() {
    var heat = cells.length === count ? cells.slice() : blank()
    // New heat along the bottom, hottest in the middle.
    for (var c = 0; c < columns; c++) heat[c] = Math.random() < 0.85 ? 0.55 + 0.45 * Math.random() * reach(c) / rows : 0.2
    // Each pixel is the heat below it, spread a little and cooled.
    for (var r = rows - 1; r > 0; r--) {
      for (var c2 = 0; c2 < columns; c2++) {
        var below = (r - 1) * columns
        var sum = heat[below + c2] * 2 + heat[below + Math.max(0, c2 - 1)] + heat[below + Math.min(columns - 1, c2 + 1)]
        heat[r * columns + c2] = Math.max(0, sum / 4 - 0.1 - Math.random() * 0.08)
      }
    }
    return heat
  }

  function stepRadar() {
    phase += 0.4
    var list = afterglow(0.6)
    var cx = (columns - 1) / 2, cy = (rows - 1) / 2
    var reachR = Math.max(cx, cy) + 0.5
    var ax = Math.cos(phase), ay = Math.sin(phase)
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        var dx = (c - cx) / (cx + 0.5), dy = (r - cy) / (cy + 0.5)
        var len = Math.sqrt(dx * dx + dy * dy)
        if (len > 1.05) continue
        // On the beam: in its direction, and close to its line.
        var along = dx * ax + dy * ay
        var off = Math.abs(dx * ay - dy * ax)
        if (along > 0 && off < 0.14 + 0.1 * len) list[r * columns + c] = 1
      }
    }
    return list
  }

  function stepSwirl() {
    phase += 0.28
    var list = blank()
    var cx = (columns - 1) / 2, cy = (rows - 1) / 2
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        var dx = c - cx, dy = (r - cy) * 1.4
        var d = Math.sqrt(dx * dx + dy * dy)
        var v = Math.cos(2 * Math.atan2(dy, dx) - d * 0.9 + phase)
        if (v > 0.3) list[r * columns + c] = v * Math.max(0.25, 1 - d / (Math.max(cx, cy) * 1.6))
      }
    }
    return list
  }

  function stepPlasma() {
    phase += 0.18
    var list = blank()
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        var v = Math.sin(c * 0.55 + phase) + Math.sin(r * 0.8 - phase * 1.3)
          + Math.sin((c + r) * 0.4 + phase * 0.7) + Math.sin(Math.sqrt(c * c + r * r) * 0.6 - phase)
        // Four steps of brightness, for a pixel-art look.
        var level = Math.floor((v + 4) / 8 * 4) / 3
        list[r * columns + c] = level > 0.34 ? level : 0
      }
    }
    return list
  }

  function stepRain() {
    var list = afterglow(0.45)
    var next = []
    for (var i = 0; i < embers.length; i++) {
      var drop = embers[i]
      if (drop.row > 0) next.push({ column: drop.column, row: drop.row - 1 })
      else {
        // A splash either side as it lands.
        if (drop.column > 0) list[drop.column - 1] = Math.max(list[drop.column - 1], 0.6)
        if (drop.column < columns - 1) list[drop.column + 1] = Math.max(list[drop.column + 1], 0.6)
      }
    }
    for (var c = 0; c < columns; c++) if (Math.random() < 0.12) next.push({ column: c, row: rows - 1 })
    embers = next
    for (var j = 0; j < next.length; j++) list[next[j].row * columns + next[j].column] = 1
    return list
  }

  readonly property var shuffleStyles: ["spectrum", "wave", "embers", "ripple", "scope", "mist", "fire", "radar", "swirl", "plasma", "rain"]
  // Shuffle: the same style everywhere at once (by the clock), 20 s each.
  property string shown: style
  function pickShown() {
    var next = style === "shuffle" ? shuffleStyles[Math.floor(Date.now() / 20000) % shuffleStyles.length] : style
    if (next !== shown) {
      shown = next
      embers = []
      levels = []
      targets = []
    }
  }

  function step() {
    if (silent) {
      var flat = blank()
      for (var c = 0; c < columns; c++) flat[c] = 1
      cells = flat
      return
    }
    pickShown()
    if (shown === "wave") cells = stepWave()
    else if (shown === "embers") cells = stepEmbers()
    else if (shown === "ripple") cells = stepRipple()
    else if (shown === "scope") cells = stepScope()
    else if (shown === "mist") cells = stepMist()
    else if (shown === "fire") cells = stepFire()
    else if (shown === "radar") cells = stepRadar()
    else if (shown === "swirl") cells = stepSwirl()
    else if (shown === "plasma") cells = stepPlasma()
    else if (shown === "rain") cells = stepRain()
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
    interval: eq.shown === "embers" || eq.shown === "rain" ? 110 : 95
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
