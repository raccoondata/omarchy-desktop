#version 440
// The now-playing card's visualizer scenes (Visualizer.qml), after Windows
// Media Player's, in the theme's colours. Drawn per pixel on the GPU from
// `tick` (~15 a second, only while the card is open and playing); `grain`
// snaps it to chunky pixels for the Omarchy look. With cava running, every
// scene follows the music (AudioLevels.js): the spectrum, the loudness and
// the bass's pulse; without it, generated motion. Compile: shaders/build.
// Scenes:
//   0 tunnel      rings rushing at you, striped and turning ("Alchemy"); the
//                 mouth pumps with the bass, each stripe lit by its band
//   1 kaleido     a six-way mirrored pattern blooming with the loudness,
//                 its rings lit by the spectrum from the centre out
//   2 starfield   stars streaming out, each twinkling with a band
//   3 battery     rings and spokes turning against each other ("Battery");
//                 each spoke as long as its band, the rings pumping
//   4 lava        blobs that merge and part, each swelling with a band
//   5 lissajous   a looping curve ("Bars and Waves") bent by the spectrum
//   6 aurora      ribbons of light, lit across the width by the spectrum
// Scenes 0-6 get a glitch layer on top (main), all from the music, none in
// silence: slices torn on the hits, a ghost as far as the bass swells, blocks
// flipping on the kicks, scanlines.
// The glitch family:
//   7 glitch      a spectrum torn into slices that jump on the kicks, split
//                 into two colours, with blocks flipping and dropping out
//   8 signal      signal loss: a waveform built from the bands (each wave
//                 as tall as its band, travelling only while it plays),
//                 tearing, rolling on the kicks, lost in snow when quiet
//   9 blocks      macroblocks: the spectrum as compressed-video blocks,
//                 moshed sideways and smeared, more so on the bass
//   10 sorted     pixel sort: streaks dripping from the top, each as long
//                 as its band
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float tick;
    float sceneIndex;
    float w;
    float h;
    float grainPx; // pixel size, 1 = smooth
    vec4 inkA;     // the accent
    vec4 inkB;     // a second theme colour
    float live;     // 1: the music's (AudioLevels.js), from cava
    float beatLevel;  // kicks, decaying
    float pump;       // the bass, rising at once and falling slowly
    float loudness;
    // 16 bands, low to high, packed in fours.
    vec4 bandsA;
    vec4 bandsB;
    vec4 bandsC;
    vec4 bandsD;
    // Signal loss: how far each of its 8 waves has travelled, moved by the
    // music (Visualizer.qml), not the clock.
    vec4 wavePhaseA;
    vec4 wavePhaseB;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float beat(float t) {
    float period = 4.0 + floor(hash(vec2(floor(t / 24.0), 3.0)) * 4.0);
    float phase = mod(t, period) / period;
    return (0.45 + 0.55 * hash(vec2(floor(t / period), 1.0))) * exp(-phase * 4.0);
}

float bandAt(int i) {
    vec4 q = i < 4 ? bandsA : (i < 8 ? bandsB : (i < 12 ? bandsC : bandsD));
    int j = i - (i / 4) * 4;
    return j == 0 ? q.x : (j == 1 ? q.y : (j == 2 ? q.z : q.w));
}

// The music at x (0 low .. 1 high frequency); without it, a slow wave.
float spec(float x, float t) {
    x = clamp(x, 0.0, 1.0);
    if (live < 0.5) return 0.45 + 0.35 * sin(x * 9.0 + t * 1.7) * sin(x * 4.0 - t * 0.9);
    float f = x * 15.0, i = floor(f);
    return mix(bandAt(int(i)), bandAt(int(min(i + 1.0, 15.0))), f - i);
}

// How hard the music hits right now, 0 in silence: the kicks most, the
// bass's swell some. Every glitch below happens only as often as this says.
float hitOf(float b, float pm) { return clamp(b * 0.9 + pm * pm * 0.5, 0.0, 1.0); }

float wavePhase(int i) {
    vec4 q = i < 4 ? wavePhaseA : wavePhaseB;
    int j = i - (i / 4) * 4;
    return j == 0 ? q.x : (j == 1 ? q.y : (j == 2 ? q.z : q.w));
}

// Signal loss's waveform at x: 8 waves, each as tall as its band and as far
// along as the music has pushed it (wavePhase), about -0.8..0.8.
float signalWave(float x, float t) {
    float wv = 0.0, total = 0.0;
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float weight = 1.0 / (1.0 + fi * 0.4);
        wv += spec(fi / 7.0, t) * sin(x * 6.2832 * (1.0 + fi * 1.5) + wavePhase(i)) * weight;
        total += weight;
    }
    return wv / total * 2.2;
}

// One scene at a (grain-snapped) pixel: (brightness, how much of the second
// colour).
vec2 scene(vec2 px, int s, float t, float b, float pm, float loud) {
    vec2 p = (px - vec2(w, h) * 0.5) / (h * 0.5);   // centred, height = 2
    float v = 0.0;
    float mixB = 0.0;

    if (s == 0) {  // tunnel
        float r = length(p) * (1.25 - 0.45 * pm), a = atan(p.y, p.x);   // the mouth pumps
        float depth = 0.6 / max(r, 0.05) + t * 1.4;
        float rings = step(0.55 - 0.35 * pm, fract(depth));
        float turn = a / 6.2832 * 8.0 + t * 0.2 + depth * 0.1;
        float stripes = step(0.5, fract(turn));
        // Each of the 8 stripes lit by a band, low to high around the ring.
        float lit = spec(fract(floor(turn) / 8.0), t);
        v = mix(rings, stripes, 0.5) * smoothstep(0.02, 0.6, r) * (0.2 + 1.3 * lit) * (0.7 + 0.5 * b);
        mixB = stripes;
    } else if (s == 1) {  // kaleido
        float r = length(p), a = atan(p.y, p.x);
        a = abs(mod(a, 1.0472) - 0.5236);  // six mirrored wedges
        vec2 q = vec2(cos(a), sin(a)) * r * (2.2 + 1.6 * pm);
        float f = sin(q.x * 2.0 + t) + sin(q.y * 3.0 - t * 1.3) + sin((q.x + q.y) * 1.5 + t * 0.7);
        v = smoothstep(0.6, 1.4, f + 2.2 * loud - 0.5 + 0.6 * b);
        // The spectrum from the centre (bass) outward (treble).
        v *= 0.25 + 1.4 * spec(r / 1.6, t);
        mixB = smoothstep(-0.5, 0.5, sin(r * 4.0 - t * 2.0));
    } else if (s == 2) {  // starfield
        for (int i = 0; i < 3; i++) {
            float layer = float(i);
            float z = fract(t * (0.25 + 0.1 * layer) + hash(vec2(layer, 7.0)));
            vec2 cell = floor(p * (6.0 + layer * 5.0) / max(z, 0.05));
            vec2 f = fract(p * (6.0 + layer * 5.0) / max(z, 0.05)) - 0.5;
            float star = hash(cell + layer * 13.0);
            // More stars when it's loud; each twinkles with its own band.
            if (star > 0.94 - 0.1 * loud) {
                float tw = 0.3 + 1.8 * spec(hash(cell + 31.0), t);
                v = max(v, smoothstep(0.2 + 0.15 * tw, 0.0, length(f)) * (1.0 - z) * tw);
            }
        }
        // A glow in the middle on the bass.
        v = max(v, smoothstep(0.2 + 0.5 * pm, 0.0, length(p)) * pm * 0.8);
        mixB = step(0.5, fract(p.x * 3.0));
        v *= (0.25 + 1.3 * loud) * (0.8 + 0.4 * b);
    } else if (s == 3) {  // battery
        float r = length(p), a = atan(p.y, p.x);
        float ring = step(0.85 - 0.35 * pm, fract(r * 3.0 - t * 0.8));
        float turn = a / 6.2832 * 12.0 + t * 0.3 * (r > 0.8 ? -1.0 : 1.0);
        float spokes = step(0.8, fract(turn));
        // Each of the 12 spokes reaches as far as its band.
        float reach = 0.3 + 1.1 * spec(fract(floor(turn) / 12.0), t);
        spokes *= step(0.25, r) * step(r, reach);
        v = max(ring * (0.35 + 0.9 * pm), spokes) * smoothstep(1.4, 0.2, r) * (0.7 + 0.5 * b);
        mixB = spokes;
    } else if (s == 4) {  // lava
        float f = 0.0;
        for (int i = 0; i < 4; i++) {
            float k = float(i);
            vec2 c = vec2(sin(t * (0.4 + 0.13 * k) + k * 1.7) * (w / h) * 0.8, cos(t * (0.3 + 0.11 * k) + k * 2.3) * 0.6);
            f += (0.05 + 0.2 * spec(k / 3.0, t) + 0.05 * pm) / max(dot(p - c, p - c), 0.01);
        }
        v = smoothstep(0.9, 1.3, f);
        mixB = smoothstep(1.3, 3.0, f);
    } else if (s == 5) {  // lissajous
        // Distance to the curve: to each short segment along it.
        // Bent by the spectrum: each stretch of the loop swells with a band.
        float d = 10.0;
        vec2 prev = vec2(sin(t * 0.9) * (w / h) * 0.85, sin(t * 0.4) * 0.8) * (0.45 + 0.75 * spec(0.0, t));
        for (int i = 1; i <= 72; i++) {
            float u = float(i) / 72.0 * 6.2832;
            float swell = 0.45 + 0.75 * spec(abs(float(i) / 36.0 - 1.0), t);
            vec2 c = vec2(sin(u * 3.0 + t * 0.9) * (w / h) * 0.85, sin(u * 2.0 + t * 0.4) * 0.8) * swell;
            vec2 pa = p - prev, ba = c - prev;
            float k = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
            d = min(d, length(pa - ba * k));
            prev = c;
        }
        v = smoothstep(0.05 + 0.08 * pm, 0.0, d) + (0.15 + 0.6 * loud) * smoothstep(0.25, 0.0, d);
        mixB = smoothstep(0.03, 0.0, d);
    } else if (s == 7) {  // glitch
        vec2 uv = px / vec2(w, h);
        float slice = floor(uv.y * 12.0);
        float k = floor(tick / 2.0);
        // Slices tear on the hits, mostly where the spectrum is loud (bass
        // at the bottom).
        float shift = hash(vec2(slice, k)) < hitOf(b, pm) * (0.2 + 0.8 * spec(1.0 - slice / 11.0, t)) * 0.7
            ? (hash(vec2(slice, tick)) - 0.5) * (0.08 + 0.4 * pm) : 0.0;
        float x = fract(uv.x + shift);
        float y = 1.0 - uv.y;
        float bars = clamp(floor(w / max(grainPx, 1.0) / 6.0), 16.0, 48.0);
        float lead = 0.0, ghost = 0.0;
        for (int i = 0; i < 2; i++) {
            // The ghost: the same spectrum a little to the side (the split).
            float xx = fract(x + (i == 1 ? 0.002 + 0.04 * pm : 0.0));
            float bi = floor(xx * bars);
            float hgt = 0.04 + 0.92 * spec(bi / (bars - 1.0), t);
            float on = step(fract(xx * bars), 0.75) * step(y, hgt) * (0.45 + 0.55 * y / hgt);
            if (i == 0) lead = on; else ghost = on;
        }
        // Corrupt blocks: some flip, some go dark.
        vec2 blk = floor(uv * vec2(20.0, 6.0));
        float hb = hash(blk + floor(tick / 3.0) * 1.7);
        if (hb > 1.0 - 0.06 * b) lead = 1.0 - lead * 0.8;
        else if (hb < 0.03 * hitOf(b, pm)) { lead = 0.0; ghost = 0.0; }
        v = max(lead, ghost * 0.7);
        mixB = ghost > lead ? 1.0 : 0.0;
        if (shift != 0.0) mixB = 1.0 - mixB;                          // torn slices swap colours
        v *= 0.82 + 0.18 * step(0.5, fract(px.y / (grainPx * 2.0)));  // scanlines
    } else if (s == 8) {  // signal loss
        vec2 uv = px / vec2(w, h);
        float k = floor(tick);
        float roll = b * 0.35 * (hash(vec2(k, 2.0)) - 0.5);           // vertical hold slips on a kick
        float slice = floor(uv.y * 16.0);
        float tear = hash(vec2(slice, k)) < hitOf(b, pm) * 0.5 ? (hash(vec2(slice, k + 1.0)) - 0.5) * (0.1 + 0.3 * pm) : 0.0;
        float x = uv.x + tear;
        float yy = fract(uv.y + roll) * 2.0 - 1.0;
        // The wave, and its ghost a little behind (the colours split apart).
        float d = abs(yy - signalWave(x, t));
        float dg = abs(yy - signalWave(x - 0.012 - 0.03 * pm, t));
        float line = smoothstep(0.07 + 0.05 * pm, 0.0, d) + 0.25 * smoothstep(0.35, 0.0, d);
        float ghost = 0.7 * smoothstep(0.06 + 0.05 * pm, 0.0, dg);
        // Snow, thicker when the signal (the music) is weak.
        float snow = hash(floor(px / grainPx) + k * vec2(1.3, 7.7));
        float noise = snow * (0.06 + 0.3 * (1.0 - clamp(loud * 2.0, 0.0, 1.0)));
        v = max(max(line, ghost), noise);
        mixB = ghost > line ? 1.0 : (line > noise ? 0.0 : 1.0);
        if (tear != 0.0) v *= 0.75;
    } else if (s == 9) {  // macroblocks
        vec2 uv = px / vec2(w, h);
        vec2 grid = vec2(floor(clamp(w / h * 6.0, 12.0, 40.0)), 6.0);
        vec2 cell = floor(uv * grid);
        float k = floor(tick / 2.0);
        vec2 src = cell;
        // Moshed: a block shows one from beside it.
        if (hash(cell + k * 0.73) < 0.45 * hitOf(b, pm)) src.x = mod(src.x + floor((hash(cell + k) - 0.5) * 8.0) + grid.x, grid.x);
        // Smeared: a run of blocks repeats the one at its left.
        float smear = hash(vec2(cell.y, floor(tick / 4.0))) < 0.5 * hitOf(b, pm) ? floor(hash(vec2(cell.y, k)) * grid.x) : -1.0;
        if (smear >= 0.0 && cell.x > smear && cell.x < smear + 2.0 + 6.0 * pm) src.x = smear;
        float f = spec(src.x / (grid.x - 1.0), t);
        float row = grid.y - 1.0 - src.y;                             // 0 at the bottom
        float on = step(row / grid.y, f * 1.05 - 0.02);
        vec2 inner = fract(uv * grid);
        // Solid blocks, lit from below; a moshed one carries a compression
        // pattern and the other colour.
        bool moshed = src.x != cell.x;
        float pat = moshed ? 0.55 + 0.45 * step(0.5, fract(inner.x * 2.0 + floor(inner.y * 2.0) * 0.5)) : 0.8 + 0.2 * (1.0 - inner.y);
        float edge = step(0.08, inner.x) * step(0.1, inner.y);
        v = on * pat * edge * (0.45 + 0.55 * (row + 1.0) / grid.y);
        mixB = moshed ? 1.0 : 0.0;
        if (hash(cell + floor(tick / 12.0) * 3.1) > 1.0 - 0.03 * spec(0.85, t)) { v = max(v, 0.7 * edge); mixB = 1.0; }   // stuck, on the treble
    } else if (s == 10) {  // pixel sort
        vec2 uv = px / vec2(w, h);
        float colW = grainPx * 2.0;
        float col = floor(px.x / colW);
        float x = col / max(floor(w / colW) - 1.0, 1.0);
        // Each column starts at its own height and smears down as far as
        // its band; bright at the head, or (some) at the tail.
        float start = hash(vec2(col, floor(tick / 6.0))) * 0.35;
        float along = (uv.y - start) / (spec(x, t) * (0.9 - start) + 0.03);
        float on = step(0.0, along) * step(along, 1.0);
        float grad = hash(vec2(col, 3.0)) > 0.5 ? 1.0 - along : along;
        v = on * (0.25 + 0.75 * grad);
        if (hash(vec2(col, floor(tick))) < 0.25 * b) v *= 0.4;          // columns skip on the kicks
        mixB = step(0.5, hash(vec2(col, floor(tick / 6.0) + 5.0)));
        v = max(v, 0.08 * hash(floor(px / grainPx) + floor(tick / 3.0)));   // the unsorted rest
    } else {  // aurora
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float y = (0.2 + 0.4 * pm) * sin(p.x * (1.2 + 0.4 * k) + t * (0.5 + 0.2 * k) + k) + (k - 1.0) * 0.3;
            float band = smoothstep(0.2 + 0.3 * loud, 0.0, abs(p.y - y)) * (0.5 + 0.5 * sin(p.x * 6.0 + t * 2.0 + k));
            // Lit across the width by the spectrum, low on the left.
            v = max(v, band * (0.15 + 1.5 * spec(px.x / w, t)));
            if (k == 1.0) mixB = band;
        }
    }
    return vec2(v, mixB);
}

void main() {
    // Snap to the grain (chunky pixels for the Omarchy look).
    vec2 px = floor(qt_TexCoord0 * vec2(w, h) / grainPx) * grainPx + grainPx * 0.5;
    float t = tick / 15.0;   // seconds
    float b = live > 0.5 ? beatLevel : beat(tick);
    float pm = live > 0.5 ? pump : 0.3 + 0.5 * b;          // the bass's pulse
    float loud = live > 0.5 ? loudness : 0.45;
    int s = int(sceneIndex + 0.5);
    vec2 o;
    if (s >= 7) {
        o = scene(px, s, t, b, pm, loud);   // the glitch family: glitched already
    } else {
        // The glitch layer over the older scenes, all of it from the music
        // (none in silence): slices torn sideways on the hits, where the
        // spectrum is loud (bass at the bottom); a ghost split off in the
        // other colour as far as the bass swells; blocks flipping on kicks.
        vec2 uv = px / vec2(w, h);
        float hit = hitOf(b, pm);
        float slice = floor(uv.y * 10.0);
        float tear = hash(vec2(slice, floor(tick / 2.0))) < hit * (0.2 + 0.8 * spec(1.0 - slice / 9.0, t)) * 0.6
            ? (hash(vec2(slice, tick)) - 0.5) * w * (0.05 + 0.3 * hit) : 0.0;
        vec2 q = floor(vec2(mod(px.x + tear, w), px.y) / grainPx) * grainPx + grainPx * 0.5;
        vec2 body = scene(q, s, t, b, pm, loud);
        vec2 ghost = scene(q + vec2(grainPx * floor(6.0 * pm), 0.0), s, t, b, pm, loud);
        o.x = max(body.x, ghost.x * 0.55);
        o.y = ghost.x * 0.55 > body.x ? 1.0 : body.y;
        if (tear != 0.0) o.y = 1.0 - o.y;
        float hb = hash(floor(uv * vec2(18.0, 5.0)) + floor(tick / 3.0) * 1.7);
        if (hb > 1.0 - 0.03 * b) o.x = 1.0 - o.x * 0.8;
        else if (hb < 0.03 * hit) o.x *= 0.1;
        o.x *= 0.82 + 0.18 * step(0.5, fract(px.y / (grainPx * 2.0)));
    }
    vec3 ink = mix(inkA.rgb, inkB.rgb, clamp(o.y, 0.0, 1.0) * 0.6);
    float a = clamp(o.x, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(ink * a, a);
}
