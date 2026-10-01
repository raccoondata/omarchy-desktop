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
//   7 woods       walking through a digital forest: pines in layers, fog,
//                 the spectrum glowing in the grass, fireflies flaring
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

void main() {
    // Snap to the grain, then work in a centred space (height = 2).
    vec2 px = floor(qt_TexCoord0 * vec2(w, h) / grainPx) * grainPx + grainPx * 0.5;
    vec2 p = (px - vec2(w, h) * 0.5) / (h * 0.5);
    float t = tick / 15.0;   // seconds
    float b = live > 0.5 ? beatLevel : beat(tick);
    float pm = live > 0.5 ? pump : 0.3 + 0.5 * b;          // the bass's pulse
    float loud = live > 0.5 ? loudness : 0.45;
    int s = int(sceneIndex + 0.5);
    float v = 0.0;   // brightness
    float mixB = 0.0;  // how much of the second colour

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
        v *= 0.7 + 0.5 * b;
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
    } else if (s == 7) {  // woods
        vec2 uv = px / vec2(w, h);          // 0..1, y down
        float sky = 0.18 * (1.0 - uv.y) + 0.05;
        v = sky;
        mixB = 1.0;
        float walk = t * (0.35 + 0.5 * loud);
        // Far to near: each layer's pines, lit by fog behind them.
        for (int i = 0; i < 3; i++) {
            float L = float(i);
            float scale = 7.0 - L * 2.2;                     // trees per screen width
            float x = uv.x * scale * (w / h) * 0.5 + walk * (0.08 + 0.12 * L) + L * 13.0;
            float cell = floor(x);
            float f = fract(x) - 0.5;
            // Trees stretch with their band.
            float hgt = (0.35 + 0.2 * L + 0.25 * hash(vec2(cell, L))) * (0.85 + 0.3 * spec(hash(vec2(cell, L + 9.0)), t));
            float y = 1.0 - uv.y;                              // up from the ground
            float trunk = step(abs(f), 0.03 + 0.02 * L) * step(y, hgt * 0.35);
            float canopy = step(abs(f), (hgt - y) * (0.55 + 0.1 * L)) * step(hgt * 0.25, y) * step(y, hgt);
            float tree = max(trunk, canopy) * step(hash(vec2(cell, L + 4.0)), 0.75);
            // A tree covers what's behind it: darker the nearer it is.
            v = mix(v, 0.04 + 0.06 * (2.0 - L), tree);
            mixB = mix(mixB, 0.0, tree);
            // Fog between layers.
            v += (0.03 + 0.08 * loud) * (1.0 - y) * (1.0 - tree) * (2.0 - L) * 0.5;
        }
        // Digital grass along the ground: the spectrum, in pixel steps.
        float grass = ceil(spec(uv.x, t) * 8.0) / 8.0 * 0.16;
        float gy = 1.0 - uv.y;
        if (gy < grass) { v = max(v, 0.35 + 0.5 * gy / max(grass, 0.01)); mixB = 0.0; }
        // Fireflies drifting up, flaring on the kicks.
        vec2 fcell = floor(uv * vec2(18.0, 8.0) + vec2(walk * 0.3, -t * 0.08));
        vec2 ff = fract(uv * vec2(18.0, 8.0) + vec2(walk * 0.3, -t * 0.08)) - 0.5;
        if (hash(fcell) > 0.86) {
            float glow = smoothstep(0.18, 0.0, length(ff)) * (0.5 + 0.5 * sin(t * 3.0 + hash(fcell) * 20.0));
            v = max(v, glow * (0.4 + 0.8 * pm + 0.8 * b));
            mixB = mix(mixB, 0.0, glow);
        }
        // Digital: faint scanlines.
        v *= 0.9 + 0.1 * sin(px.y * 1.6);
    } else {  // aurora
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float y = (0.2 + 0.4 * pm) * sin(p.x * (1.2 + 0.4 * k) + t * (0.5 + 0.2 * k) + k) + (k - 1.0) * 0.3;
            float band = smoothstep(0.2 + 0.3 * loud, 0.0, abs(p.y - y)) * (0.5 + 0.5 * sin(p.x * 6.0 + t * 2.0 + k));
            // Lit across the width by the spectrum, low on the left.
            v = max(v, band * (0.15 + 1.5 * spec(qt_TexCoord0.x, t)));
            if (k == 1.0) mixB = band;
        }
    }
    vec3 ink = mix(inkA.rgb, inkB.rgb, clamp(mixB, 0.0, 1.0) * 0.6);
    float a = clamp(v, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(ink * a, a);
}
