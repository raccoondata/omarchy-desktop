#version 440
// The now-playing card's visualizer scenes (Visualizer.qml), after Windows
// Media Player's, in the theme's colours. Drawn per pixel on the GPU from
// `tick` (~15 a second, only while the card is open and playing); `grain`
// snaps it to chunky pixels for the Omarchy look. The beat is decorative.
// Compile: shaders/build. Scenes:
//   0 tunnel      rings rushing at you, striped and turning ("Alchemy")
//   1 kaleido     a six-way mirrored, drifting pattern
//   2 starfield   stars streaming out from the middle
//   3 battery     rings and spokes turning against each other ("Battery")
//   4 lava        blobs that merge and part
//   5 lissajous   a glowing looping curve ("Bars and Waves")
//   6 aurora      ribbons of light waving
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
    float live;     // 1: beatLevel is the music's (AudioLevels.js)
    float beatLevel;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float beat(float t) {
    float period = 4.0 + floor(hash(vec2(floor(t / 24.0), 3.0)) * 4.0);
    float phase = mod(t, period) / period;
    return (0.45 + 0.55 * hash(vec2(floor(t / period), 1.0))) * exp(-phase * 4.0);
}

void main() {
    // Snap to the grain, then work in a centred space (height = 2).
    vec2 px = floor(qt_TexCoord0 * vec2(w, h) / grainPx) * grainPx + grainPx * 0.5;
    vec2 p = (px - vec2(w, h) * 0.5) / (h * 0.5);
    float t = tick / 15.0;   // seconds
    float b = live > 0.5 ? beatLevel : beat(tick);
    int s = int(sceneIndex + 0.5);
    float v = 0.0;   // brightness
    float mixB = 0.0;  // how much of the second colour

    if (s == 0) {  // tunnel
        float r = length(p), a = atan(p.y, p.x);
        float depth = 0.6 / max(r, 0.05) + t * 1.4;
        float rings = step(0.5, fract(depth));
        float stripes = step(0.5, fract(a / 6.2832 * 8.0 + t * 0.2 + depth * 0.1));
        v = mix(rings, stripes, 0.5) * smoothstep(0.02, 0.6, r) * (0.6 + 0.4 * b);
        mixB = stripes;
    } else if (s == 1) {  // kaleido
        float r = length(p), a = atan(p.y, p.x);
        a = abs(mod(a, 1.0472) - 0.5236);  // six mirrored wedges
        vec2 q = vec2(cos(a), sin(a)) * r * 3.0;
        float f = sin(q.x * 2.0 + t) + sin(q.y * 3.0 - t * 1.3) + sin((q.x + q.y) * 1.5 + t * 0.7);
        v = smoothstep(0.6, 1.4, f + b);
        mixB = smoothstep(-0.5, 0.5, sin(r * 4.0 - t * 2.0));
    } else if (s == 2) {  // starfield
        for (int i = 0; i < 3; i++) {
            float layer = float(i);
            float z = fract(t * (0.25 + 0.1 * layer) + hash(vec2(layer, 7.0)));
            vec2 cell = floor(p * (6.0 + layer * 5.0) / max(z, 0.05));
            vec2 f = fract(p * (6.0 + layer * 5.0) / max(z, 0.05)) - 0.5;
            float star = hash(cell + layer * 13.0);
            if (star > 0.92) v = max(v, smoothstep(0.25, 0.0, length(f)) * (1.0 - z) * 1.6);
        }
        mixB = step(0.5, fract(p.x * 3.0));
        v *= 0.7 + 0.5 * b;
    } else if (s == 3) {  // battery
        float r = length(p), a = atan(p.y, p.x);
        float ring = step(0.8, fract(r * 3.0 - t * 0.8));
        float spokes = step(0.85, fract(a / 6.2832 * 12.0 + t * 0.3 * (r > 0.8 ? -1.0 : 1.0)));
        v = max(ring, spokes * step(0.25, r)) * smoothstep(1.3, 0.2, r) * (0.55 + 0.6 * b);
        mixB = spokes;
    } else if (s == 4) {  // lava
        float f = 0.0;
        for (int i = 0; i < 4; i++) {
            float k = float(i);
            vec2 c = vec2(sin(t * (0.4 + 0.13 * k) + k * 1.7) * (w / h) * 0.8, cos(t * (0.3 + 0.11 * k) + k * 2.3) * 0.6);
            f += (0.12 + 0.05 * b) / max(dot(p - c, p - c), 0.01);
        }
        v = smoothstep(0.9, 1.3, f);
        mixB = smoothstep(1.3, 3.0, f);
    } else if (s == 5) {  // lissajous
        // Distance to the curve: to each short segment along it.
        float d = 10.0;
        vec2 prev = vec2(sin(t * 0.9) * (w / h) * 0.85, sin(t * 0.4) * 0.8);
        for (int i = 1; i <= 72; i++) {
            float u = float(i) / 72.0 * 6.2832;
            vec2 c = vec2(sin(u * 3.0 + t * 0.9) * (w / h) * 0.85, sin(u * 2.0 + t * 0.4) * 0.8);
            vec2 pa = p - prev, ba = c - prev;
            float k = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
            d = min(d, length(pa - ba * k));
            prev = c;
        }
        v = smoothstep(0.06 + 0.05 * b, 0.0, d) + 0.35 * smoothstep(0.25, 0.0, d);
        mixB = smoothstep(0.03, 0.0, d);
    } else {  // aurora
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float y = 0.35 * sin(p.x * (1.2 + 0.4 * k) + t * (0.5 + 0.2 * k) + k) + (k - 1.0) * 0.3;
            float band = smoothstep(0.35, 0.0, abs(p.y - y)) * (0.5 + 0.5 * sin(p.x * 6.0 + t * 2.0 + k));
            v = max(v, band * (0.6 + 0.5 * b));
            if (k == 1.0) mixB = band;
        }
    }
    vec3 ink = mix(inkA.rgb, inkB.rgb, clamp(mixB, 0.0, 1.0) * 0.6);
    float a = clamp(v, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(ink * a, a);
}
