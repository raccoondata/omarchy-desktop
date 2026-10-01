#version 440
// The pixel equalizer, drawn on the GPU (Equalizer.qml). The whole grid is
// computed here from `tick` (a step count the item advances ~10 times a
// second while playing), so the CPU work per frame is one number. Styles are
// deterministic: "random" motion is hashed from (column, tick), so no state.
// Compile: shaders/build (qsb). Styles, by index (Visuals.js eqStyles):
//   0 spectrum  1 mist  2 scope  3 radar  4 plasma  5 static  6 corrupt
// Styles 0-4 get a glitch layer on top (main), all from the music, none in
// silence: rows torn on the hits, an echo while the bass swells, dropouts and
// stuck pixels on the kicks.
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
    float beatLevel;  // kicks, decaying
    float pump;       // the bass, rising at once and falling slowly
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

// How hard the music hits right now, 0 in silence: the kicks most, the
// bass's swell some (a steady 0.25 without cava). Glitches happen only as
// often as this says.
float hit() { return isLive() ? clamp(beatLevel * 0.9 + pump * pump * 0.5, 0.0, 1.0) : 0.25; }

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
    if (s == 1) {  // mist: mirrored from the middle row, with a trail
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
    if (s == 2) {  // scope, with a faint trail
        float b = 0.0;
        for (int k = 0; k < 2; k++) {
            float tt = t - float(k);
            float y = scopeRow(c, tt), yp = c > 0.0 ? scopeRow(c - 1.0, tt) : y;
            float lit = r == y ? 1.0 : (r >= min(y, yp) && r <= max(y, yp) ? 0.8 : 0.0);
            b = max(b, lit * (k == 0 ? 1.0 : 0.35));
        }
        return b;
    }
    if (s == 3) {  // radar, with an afterglow
        float b = 0.0;
        for (int k = 0; k < 3; k++) b = max(b, radarBeam(c, r, (t - float(k)) * 0.4) * pow(0.6, float(k)));
        return isLive() ? b * (0.12 + 1.5 * bass) : b;
    }
    if (s == 4) {  // plasma, in four steps
        float p = t * 0.18;
        float v = sin(c * 0.55 + p) + sin(r * 0.8 - p * 1.3) + sin((c + r) * 0.4 + p * 0.7) + sin(sqrt(c * c + r * r) * 0.6 - p);
        if (isLive()) v += (loudness - 0.35) * 3.0;
        float l = floor((v + 4.0) / 8.0 * 4.0) / 3.0;
        return l > 0.34 ? l : 0.0;
    }
    if (s == 5) {  // static: snow shaped like the spectrum, new every tick
        float shape = isLive() ? clamp(band(c) * 1.3, 0.0, 1.0) : reach(c) / rowCount * 0.6;
        float chance = shape * (1.0 - 0.7 * r / rowCount) * (0.6 + 1.0 * hit());
        float n = hash(vec2(c * 1.37 + r * 7.1, floor(t)));
        // A kick sweeps a row of solid static across.
        if (isLive() && hash(vec2(r, floor(t) + 3.0)) < 0.25 * beatLevel) return 0.8;
        return n < chance ? 0.45 + 0.55 * hash(vec2(r, c + floor(t))) : 0.0;
    }
    if (s == 6) {  // corrupt: the spectrum in 3x2 blocks, some showing the
                    // wrong block; now and then a column hangs upside down
        float k = floor(t / 2.0);
        vec2 blk = vec2(floor(c / 3.0), floor(r / 2.0));
        float cc = c, rr = r;
        if (hash(blk + k * 1.31) < 0.04 + 0.45 * hit()) {
            cc = mod(c + floor(hash(blk + k) * 5.0 - 2.0) * 3.0 + cols, cols);
            rr = mod(r + floor(hash(blk.yx + k) * 3.0 - 1.0) * 2.0 + rowCount, rowCount);
        }
        if (hash(vec2(cc, floor(t / 4.0) + 9.0)) < 0.15 * hit()) rr = rowCount - 1.0 - rr;
        float h = isLive() ? ceil(band(cc) * rowCount) : level(cc, t, reach(cc), 3.0);
        return bar(rr, h);
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
    int st = int(styleIndex + 0.5);
    float b;
    if (mute > 0.5) b = r == 0.0 ? 1.0 : 0.0;
    else if (st >= 5) b = brightness(c, r, tick, st);    // the glitch family: glitched already
    else {
        // The glitch layer over the older styles, all of it from the music
        // (none in silence): rows torn sideways on the hits, a dim echo a
        // column behind while the bass swells, columns dropping out and
        // pixels sticking on the kicks.
        float k = floor(tick);
        float h = hit();
        float shift = hash(vec2(r, k)) < 0.45 * h ? floor((hash(vec2(r + 5.0, k)) - 0.5) * cols * 0.5) : 0.0;
        float cc = mod(c + shift + cols, cols);
        b = brightness(cc, r, tick, st);
        float swell = isLive() ? pump : 0.3;
        if (swell > 0.4) b = max(b, 0.45 * swell * brightness(mod(cc - 1.0 + cols, cols), r, tick, st));
        if (hash(vec2(c, k + 0.5)) < 0.06 * h) b = 0.0;
        if (hash(vec2(c * 7.0 + r, k)) < 0.015 * h) b = 1.0;
    }
    float a = clamp(b, 0.0, 1.0) * ink.a * qt_Opacity;
    fragColor = vec4(ink.rgb * a, a);
}
