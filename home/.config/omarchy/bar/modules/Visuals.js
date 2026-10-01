.pragma library

// Every equalizer style, card visualizer scene and album-art effect, in one
// place: the order is each shader's index (shaders/equalizer.frag,
// visualizer.frag, artfx.frag), the labels are what settings and the card
// show. Equalizer.qml, Visualizer.qml, nowplaying.qml, SuperMenu.qml and
// TaskbarSettings.qml all read these.

// Equalizer styles (the pixel grid behind taskbar icons, in the bar and the
// card). "shuffle" isn't a style: Equalizer.qml picks one by the clock.
var eqStyles = [
  { value: "spectrum", label: "Spectrum" },
  { value: "wave", label: "Wave" },
  { value: "embers", label: "Embers" },
  { value: "ripple", label: "Ripple" },
  { value: "scope", label: "Scope" },
  { value: "mist", label: "Mist" },
  { value: "fire", label: "Fire" },
  { value: "radar", label: "Radar" },
  { value: "swirl", label: "Swirl" },
  { value: "plasma", label: "Plasma" },
  { value: "rain", label: "Rain" },
  { value: "woods", label: "Woods" },
  { value: "glitch", label: "Glitch" },
  { value: "static", label: "Static" },
  { value: "corrupt", label: "Corrupt" }
]

// The card's visualizer scenes (Visualizer.qml); the card also offers
// "pixel" (its pixel equalizer) and "off".
var scenes = [
  { value: "tunnel", label: "Tunnel" },
  { value: "kaleido", label: "Kaleidoscope" },
  { value: "starfield", label: "Starfield" },
  { value: "battery", label: "Battery" },
  { value: "lava", label: "Lava" },
  { value: "lissajous", label: "Lissajous" },
  { value: "aurora", label: "Aurora" },
  { value: "woods", label: "Digital woods" },
  { value: "glitch", label: "Glitch" },
  { value: "signal", label: "Signal loss" },
  { value: "blocks", label: "Macroblocks" },
  { value: "sorted", label: "Pixel sort" }
]

// Album-art effects (shaders/artfx.frag; "off" is index 0).
var artEffects = [
  { value: "off", label: "Off" },
  { value: "glitch", label: "Glitch" },
  { value: "crt", label: "CRT" },
  { value: "melt", label: "Melt" },
  { value: "datamosh", label: "Datamosh" },
  { value: "tear", label: "Tear" },
  { value: "sort", label: "Pixel sort" },
  { value: "bitcrush", label: "Bitcrush" },
  { value: "vhs", label: "VHS" }
]

function values(list) {
  return list.map(function(o) { return o.value })
}

function label(list, value) {
  for (var i = 0; i < list.length; i++) if (list[i].value === value) return list[i].label
  return String(value)
}

// The card's visualizer choices: its pixel equalizer, the scenes, off.
function cardVisuals() {
  return [{ value: "pixel", label: "Pixel equalizer" }].concat(scenes).concat([{ value: "off", label: "Off" }])
}
