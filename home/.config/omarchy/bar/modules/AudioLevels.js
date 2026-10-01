.pragma library

// The music's spectrum, shared by every equalizer and visualizer: the taskbar
// runs cava (~/.config/omarchy/cava.conf: 16 bands, 20 frames a second) and
// feeds each frame to set(); the visualizers read it on their own ticks and
// call want(), which is what keeps cava running (the taskbar stops it a
// couple of seconds after nobody wants it, or when nothing plays).
//
//   bands   16 levels 0..1, low to high frequency
//   level   overall loudness 0..1
//   bass    the lowest bands 0..1
//   beat    0..1: a kick (bass jumping above its recent average), decaying
//   pulse   0..1: the bass, rising at once and falling slowly (for things
//           that should pump with the music rather than only on kicks)

var bands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var level = 0
var bass = 0
var beat = 0
var pulse = 0
var frameAt = 0
// The bands packed for shaders (four vec4s), made once per frame; frame
// counts frames, so a visualizer can skip work when nothing's new.
var packedBands = null
var frame = 0
var wantAt = 0
var bassAverage = 0

// One line of cava's output: "511;753;...;" (0..1000).
function set(line) {
  var parts = String(line).split(";")
  var next = []
  var sum = 0
  for (var i = 0; i < 16; i++) {
    var v = Math.max(0, Math.min(1, (parseInt(parts[i], 10) || 0) / 1000))
    next.push(v)
    sum += v
  }
  bands = next
  level = sum / 16
  bass = (next[0] + next[1] + next[2]) / 3
  bassAverage = bassAverage * 0.9 + bass * 0.1
  var kick = Math.max(0, Math.min(1, (bass - bassAverage * 0.98) * 6))
  beat = Math.max(kick, beat * 0.75)
  pulse = Math.max(bass, pulse * 0.82)
  frameAt = Date.now()
  packedBands = [Qt.vector4d(next[0], next[1], next[2], next[3]), Qt.vector4d(next[4], next[5], next[6], next[7]),
                 Qt.vector4d(next[8], next[9], next[10], next[11]), Qt.vector4d(next[12], next[13], next[14], next[15])]
  frame += 1
}

// A visualizer is showing and wants the music.
function want() {
  wantAt = Date.now()
}

// Fresh data (cava is running and sending)?
function live() {
  return Date.now() - frameAt < 400
}

// Hand the music to a visualizer shader: sets its live, beatLevel, pump,
// loudness and bandsA..bandsD (the names shaders/visualizer.frag and
// artfx.frag use), only when there's a new frame. Calls want() too.
function feed(item) {
  wantAt = Date.now()
  var on = live()
  item.live = on ? 1 : 0
  if (!on || item.seenFrame === frame) return
  item.seenFrame = frame
  item.beatLevel = beat
  item.pump = pulse
  item.loudness = level
  item.bandsA = packedBands[0]; item.bandsB = packedBands[1]
  item.bandsC = packedBands[2]; item.bandsD = packedBands[3]
}

// The 16 bands as four vec4s for a shader.
function packed() {
  return packedBands
}
