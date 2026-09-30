#version 440
// The pixel equalizer, drawn on the GPU (Equalizer.qml). The whole grid is
// computed here from `tick` (a step count the item advances ~10 times a
// second while playing), so the CPU work per frame is one number. Styles are
// deterministic: "random" motion is hashed from (column, tick), so no state.
// Compile: shaders/build (qsb). Styles, by index:
//   0 spectrum  1 wave  2 embers  3 ripple  4 scope  5 mist
//   6 fire      7 radar 8 swirl   9 plasma  10 rain  11 flashlights
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float tick;
    float styleIndex;
    float cols;
    float rowCount;
    float px;        // pixel size
    float gapPx;     // gap between pixels
    float mute;      // 1: muted, one flat row
    vec4 ink;
    // The music (AudioLevels.js, from cava): 16 bands low to high, packed in
    // fours; live is 0 without it (the generated motion then).
    vec4 bandsA;
    vec4 bandsB;
    vec4 bandsC;
    vec4 bandsD;
    float live;
    float loudness;
    float bass;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float bandAt(int i) {
    vec4 v = i < 4 ? bandsA : (i < 8 ? bandsB : (i < 12 ? bandsC : bandsD));
    int k = i - (i / 4) * 4;
    return k == 0 ? v.x : (k == 1 ? v.y : (k == 2 ? v.z : v.w));
}
// The music at a column: the 16 bands stretched across the columns.
float band(float c) {
    float x = cols > 1.0 ? c / (cols - 1.0) * 15.0 : 0.0;
    // Floats for min(): older GLSL (which Qt may translate to) has no int min.
    float fi = floor(x);
    return mix(bandAt(int(fi)), bandAt(int(min(fi + 1.0, 15.0))), fract(x));
}
bool isLive() { return live > 0.5; }

// How tall a column may get: tallest in the middle.
float reach(float c) {
    float mid = (cols - 1.0) / 2.0;
    float away = mid > 0.0 ? abs(c - mid) / mid : 0.0;
    return max(1.0, floor(rowCount * (1.0 - 0.55 * away) + 0.5));
}

// A column filled to height h, a touch brighter toward its top.
float bar(float r, float h) {
    return r < h ? 0.7 + 0.3 * (r + 1.0) / max(1.0, h) : 0.0;
}

// Spectrum-like heights: each column eases between random targets.
float level(float c, float t, float most, float speed) {
    float k = floor(t / speed);
    float a = hash(vec2(c, k)), b = hash(vec2(c, k + 1.0));
    float f = fract(t / speed);
    return 1.0 + floor(mix(a, b, f) * most);
}

float waveAt(float c, float t) {
    return 0.6 * sin(t * 0.42 + c * 0.75) + 0.4 * sin(t * 0.23 - c * 0.4);
}

float scopeRow(float c, float t) {
    float mid = (rowCount - 1.0) / 2.0;
    float v = 0.6 * sin(t * 0.35 + c * 0.8) + 0.4 * sin(t * 0.6 - c * 0.45);
    // Live: the line swings as far as the music at that column is loud.
    if (live > 0.5) v *= clamp(band(c) * 1.8, 0.05, 1.0);
    return clamp(floor(mid + v * mid + 0.5), 0.0, rowCount - 1.0);
}

float radarBeam(float c, float r, float a) {
    float cx = (cols - 1.0) / 2.0, cy = (rowCount - 1.0) / 2.0;
    vec2 d = vec2((c - cx) / (cx + 0.5), (r - cy) / (cy + 0.5));
    float len = length(d);
    if (len > 1.05) return 0.0;
    vec2 dir = vec2(cos(a), sin(a));
    float along = dot(d, dir);
    float off = abs(d.x * dir.y - d.y * dir.x);
    if (along > 0.0 && off < 0.09 + 0.06 * len) return 1.0;
    return len > 0.82 ? 0.18 : 0.0;
}

float brightness(float c, float r, float t, int s) {
    float mid = (cols - 1.0) / 2.0;
    if (s == 1) {  // wave (its height follows the loudness)
        float amp = isLive() ? clamp(loudness * 1.6, 0.15, 1.0) : 1.0;
        float h = 1.0 + floor((waveAt(c, t) * 0.5 + 0.5) * amp * (reach(c) - 1.0) + 0.5);
        return bar(r, h);
    }
    if (s == 2) {  // embers: sparks born along the bottom, rising a row a tick
        float b = 0.0;
        for (int k = 0; k < 16; k++) {
            if (float(k) >= rowCount) break;
            float born = floor(t) - float(k);
            float chance = isLive() ? 0.04 + 0.5 * band(c) : 0.08 + 0.18 * reach(c) / rowCount;
            if (hash(vec2(c, born)) < chance) {
                float top = 2.0 + floor(hash(vec2(born, c + 7.0)) * (rowCount - 1.0));
                if (float(k) < top && r == float(k)) b = max(b, 1.0 - r / rowCount);
            }
        }
        return b;
    }
    if (s == 3) {  // ripple
        float d = sqrt((c - mid) * (c - mid) * 0.55 + r * r);
        float period = rowCount * 0.9;
        float front = mod(d - t * 0.5, period);
        float glow = isLive() ? 0.35 + bass : 1.0;
        return front < 1.0 ? clamp(glow * (1.0 - d / (rowCount * 1.3)), 0.0, 1.0) : 0.0;
    }
    if (s == 4) {  // scope, with a faint trail
        float b = 0.0;
        for (int k = 0; k < 2; k++) {
            float tt = t - float(k);
            float y = scopeRow(c, tt), yp = c > 0.0 ? scopeRow(c - 1.0, tt) : y;
            float lit = r == y ? 1.0 : (r >= min(y, yp) && r <= max(y, yp) ? 0.8 : 0.0);
            b = max(b, lit * (k == 0 ? 1.0 : 0.35));
        }
        return b;
    }
    if (s == 5) {  // mist: mirrored from the middle row, with a trail
        float halfRows = max(1.0, floor(rowCount / 2.0));
        float most = max(1.0, floor(halfRows * reach(c) / rowCount + 0.5));
        float m = (rowCount - 1.0) / 2.0;
        float d = r >= ceil(m) ? r - ceil(m) : floor(m) - r;
        float b = 0.0;
        for (int k = 0; k < 2; k++) {
            float h = isLive() ? ceil(band(c) * halfRows) * (k == 0 ? 1.0 : 0.0) : level(c, t - float(k), most, 3.0);
            if (d < h) b = max(b, (1.0 - 0.5 * d / halfRows) * (k == 0 ? 1.0 : 0.5));
        }
        return b;
    }
    if (s == 6) {  // fire: uneven tongues that flicker and cool upward
        float base = 0.45 + 0.55 * reach(c) / rowCount;
        float height = isLive() ? rowCount * (0.2 + 0.95 * band(c))
            : rowCount * base * (0.55 + 0.45 * mix(hash(vec2(c, floor(t / 2.0))), hash(vec2(c, floor(t / 2.0) + 1.0)), fract(t / 2.0)));
        float heat = 1.0 - r / max(1.0, height) - 0.25 * hash(vec2(c * 3.0 + r, floor(t)));
        return heat > 0.12 ? min(1.0, heat * 1.25) : 0.0;
    }
    if (s == 7) {  // radar, with an afterglow
        float b = 0.0;
        for (int k = 0; k < 3; k++) b = max(b, radarBeam(c, r, (t - float(k)) * 0.4) * pow(0.6, float(k)));
        return isLive() ? b * (0.4 + 1.2 * bass) : b;
    }
    if (s == 8) {  // swirl
        float cx = mid, cy = (rowCount - 1.0) / 2.0;
        float dx = c - cx, dy = (r - cy) * 1.4;
        float d = sqrt(dx * dx + dy * dy);
        float v = cos(2.0 * atan(dy, dx) - d * 0.9 + t * 0.28);
        float swirlGlow = isLive() ? 0.35 + loudness * 1.4 : 1.0;
        return v > 0.3 ? min(1.0, swirlGlow * v * max(0.25, 1.0 - d / (max(cx, cy) * 1.6))) : 0.0;
    }
    if (s == 9) {  // plasma, in four steps
        float p = t * 0.18;
        float v = sin(c * 0.55 + p) + sin(r * 0.8 - p * 1.3) + sin((c + r) * 0.4 + p * 0.7) + sin(sqrt(c * c + r * r) * 0.6 - p);
        if (isLive()) v += (loudness - 0.35) * 3.0;
        float l = floor((v + 4.0) / 8.0 * 4.0) / 3.0;
        return l > 0.34 ? l : 0.0;
    }
    if (s == 11) {  // flashlights: two beams sweeping the dark from the lower corners
        float b = 0.0;
        float reachLen = isLive() ? 0.45 + 0.9 * loudness : 0.9;
        for (int k = 0; k < 2; k++) {
            float side = k == 0 ? -1.0 : 1.0;
            vec2 origin = vec2(k == 0 ? -0.5 : cols - 0.5, -0.5);
            // Sweeping, each at its own pace; aimed up and inwards.
            float aim = radians(90.0 + side * (32.0 + 22.0 * sin(t * (0.09 + 0.03 * float(k)) + float(k) * 2.1)));
            vec2 d = vec2(c, r) - origin;
            d.y *= cols / max(1.0, rowCount) * 0.55;   // the grid is wide: widen the cone's look
            float dist = length(d) / max(cols, 1.0);
            float off = abs(atan(d.y, d.x) - aim);
            float cone = smoothstep(radians(13.0), radians(4.0), off);
            float fall = clamp(1.0 - dist / reachLen, 0.0, 1.0);
            b = max(b, cone * fall);
            // Dust in the beam.
            if (cone > 0.3 && hash(vec2(c * 7.0 + r, floor(t * 0.7) + float(k))) > 0.93) b = max(b, 0.9 * fall + 0.1);
        }
        // Now and then one flickers, like a torch with a loose battery.
        float flick = hash(vec2(floor(t * 0.5), 3.0)) > 0.94 ? 0.35 : 1.0;
        return b * flick * (isLive() ? 0.55 + 0.9 * bass : 1.0);
    }
    if (s == 10) {  // rain: drops falling a row a tick, with a short trail
        float b = 0.0;
        for (int k = 0; k < 16; k++) {
            if (float(k) >= rowCount) break;
            float born = floor(t) - float(k);
            if (hash(vec2(c, born)) < (isLive() ? 0.03 + 0.4 * band(c) : 0.12)) {
                float y = rowCount - 1.0 - float(k);
                if (r == y) b = max(b, 1.0);
                else if (r == y + 1.0) b = max(b, 0.45);
            }
        }
        return b;
    }
    // spectrum: the music's bands, or random heights without it
    if (isLive()) return bar(r, ceil(band(c) * rowCount));
    return bar(r, level(c, t, reach(c), 3.0));
}

void main() {
    float pitch = px + gapPx;
    vec2 size = vec2(cols * pitch - gapPx, rowCount * pitch - gapPx);
    vec2 p = qt_TexCoord0 * size;
    float c = floor(p.x / pitch);
    float rowTop = floor(p.y / pitch);
    // Inside a px, not in the gapPx between them.
    if (mod(p.x, pitch) >= px || mod(p.y, pitch) >= px || c >= cols || rowTop >= rowCount) {
        fragColor = vec4(0.0);
        return;
    }
    float r = rowCount - 1.0 - rowTop;  // row 0 at the bottom
    float b = mute > 0.5 ? (r == 0.0 ? 1.0 : 0.0) : brightness(c, r, tick, int(styleIndex + 0.5));
    float a = clamp(b, 0.0, 1.0) * ink.a * qt_Opacity;
    fragColor = vec4(ink.rgb * a, a);
}
