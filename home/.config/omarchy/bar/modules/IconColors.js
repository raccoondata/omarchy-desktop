.pragma library

// The colour a line icon is drawn in (Taskbar & Desktop > Icons > Line icon
// colours), shared by the taskbar, window previews and switcher, the Super
// menu and now playing:
//   mono     the theme's colours, as the place normally draws (default)
//   brand    each app's own colour (icon-colors.json, taken from the app's
//            icon by the taskbar-icons skill's icon-colors)
//   palette  that colour moved onto the theme: the theme colour with the
//            nearest hue
// Icons without a colour (generic ones, black-and-white logos) keep the
// place's normal colour in every mode. taskbar.qml loads the colours and the
// theme's palette (setBrand, setPalette).

var brand = {}
var palette = []

// The theme colours worth snapping to (colors.toml keys); greys are skipped.
var PALETTE_KEYS = ["red", "orange", "yellow", "green", "cyan", "blue", "magenta", "brown",
  "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta", "accent"]

function setBrand(map) {
  brand = map || {}
}

function setPalette(tomlText) {
  var found = {}
  var re = /^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"/gm
  var m
  while ((m = re.exec(String(tomlText || ""))) !== null) {
    if (found[m[1]] === undefined) found[m[1]] = m[2]
  }
  var list = []
  for (var i = 0; i < PALETTE_KEYS.length; i++) {
    var hex = found[PALETTE_KEYS[i]]
    if (hex && hsv(hex).s >= 0.25) list.push(hex)
  }
  palette = list
}

function hsv(hex) {
  var r = parseInt(hex.substr(1, 2), 16) / 255, g = parseInt(hex.substr(3, 2), 16) / 255, b = parseInt(hex.substr(5, 2), 16) / 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
  var h = 0
  if (d > 0) {
    if (max === r) h = ((g - b) / d) % 6
    else if (max === g) h = (b - r) / d + 2
    else h = (r - g) / d + 4
    h *= 60
    if (h < 0) h += 360
  }
  return { h: h, s: max === 0 ? 0 : d / max, v: max }
}

// The theme colour closest in hue (saturation breaks near-ties), or "".
function onTheme(hex) {
  if (!hex || palette.length === 0) return ""
  var c = hsv(hex)
  var best = "", bestScore = 1e9
  for (var i = 0; i < palette.length; i++) {
    var p = hsv(palette[i])
    var dh = Math.abs(c.h - p.h)
    if (dh > 180) dh = 360 - dh
    var score = dh + Math.abs(c.s - p.s) * 20
    if (score < bestScore) {
      bestScore = score
      best = palette[i]
    }
  }
  return best
}

function colorFor(name, mode, fallback) {
  var own = brand[name]
  if (mode === "brand" && own) return own
  if (mode === "palette" && own) return onTheme(own) || fallback
  return fallback
}
