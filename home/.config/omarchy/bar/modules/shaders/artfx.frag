#version 440
// Album art effects for the now-playing card and the Super menu's strip,
// following the music (AudioLevels.js, from cava: the spectrum, loudness and
// the bass's pulse); without it, a generated beat. The CPU only hands those
// over and advances `tick` ~15 times a second while shown and playing.
// Compile: shaders/build. Modes (Visuals.js artEffects):
//   1 glitch  slices jump sideways on the treble, channels split on the bass,
//             blocks corrupt with the mids
//   2 crt     scanlines, a rolling band, a screen bulging with the bass
//   3 melt    each column of the picture drips as far as its band
//   4 datamosh  blocks slide off along their own motion and smear sideways,
//               more of them on the bass
//   5 tear    the picture's rows torn sideways and wrapped, each row as far
//             as its band (bass at the bottom), its colours split
//   6 sort    pixel sorting: bright pixels drag down their columns, as far
//             as the band at that column; more of them when it's loud
//   7 bitcrush  few colours, dithered, coarser the louder it is; rows with
//               flipped bits on the treble
//   8 vhs     a worn tape: colour bleeding sideways, a rolling tracking
//             band, wobbling lines, hiss on the treble
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float tick;
    float mode;
    float aspect;   // width / height
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
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// A decorative beat: a pulse every 4-7 ticks, some stronger, decaying.
float beat(float t) {
    float period = 4.0 + floor(hash(vec2(floor(t / 24.0), 3.0)) * 4.0);
    float phase = mod(t, period) / period;
    float strength = 0.45 + 0.55 * hash(vec2(floor(t / period), 1.0));
    return strength * exp(-phase * 4.0);
}

float bandAt(int i) {
    vec4 q = i < 4 ? bandsA : (i < 8 ? bandsB : (i < 12 ? bandsC : bandsD));
    int j = i - (i / 4) * 4;
    return j == 0 ? q.x : (j == 1 ? q.y : (j == 2 ? q.z : q.w));
}

// The music at x (0 low .. 1 high frequency); without it, a slow wave.
float spec(float x, float t) {
    x = clamp(x, 0.0, 1.0);
    if (live < 0.5) return 0.45 + 0.35 * sin(x * 9.0 + t * 0.11) * sin(x * 4.0 - t * 0.06);
    float f = x * 15.0, i = floor(f);
    return mix(bandAt(int(i)), bandAt(int(min(i + 1.0, 15.0))), f - i);
}

vec4 tex(vec2 uv) { return texture(source, clamp(uv, 0.0, 1.0)); }
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// Ordered (Bayer) dithering threshold for a pixel, 0..1.
float bayer2(vec2 a) { return mod(a.x * 2.0 + a.y * 3.0, 4.0); }
float bayer4(vec2 p) {
    p = mod(floor(p), 4.0);
    return (4.0 * bayer2(mod(p, 2.0)) + bayer2(floor(p / 2.0))) / 16.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = tick;
    float b = live > 0.5 ? beatLevel : beat(t);
    bool on = live > 0.5;
    float pm = on ? pump : 0.3 + 0.5 * b;                                   // the bass's pulse
    float loud = on ? loudness : 0.45;
    float mids = on ? (bandsB.x + bandsB.y + bandsB.z + bandsB.w + bandsC.x + bandsC.y) / 6.0 : 0.4;
    float highs = on ? (bandsC.w + bandsD.x + bandsD.y + bandsD.z + bandsD.w) / 5.0 : 0.4 * b;
    int m = int(mode + 0.5);
    vec4 c;

    if (m == 1) {  // glitch
        float rows = 18.0;
        float slice = floor(uv.y * rows);
        float jolt = hash(vec2(slice, floor(t))) ;
        float edge = 0.9 - 0.45 * highs;                                    // more slices on the treble
        float shift = (jolt > edge ? (jolt - edge) * 0.9 : 0.0) * (b + pm * pm) * sign(hash(vec2(slice, t)) - 0.5);
        vec2 p = uv + vec2(shift, 0.0);
        float split = 0.003 + 0.04 * pm;
        c = vec4(tex(p + vec2(split, 0.0)).r, tex(p).g, tex(p - vec2(split, 0.0)).b, tex(p).a);
        // Corrupt blocks: a patch shows another part of the picture.
        vec2 block = floor(uv * vec2(8.0, 10.0));
        if (hash(block + floor(t / 2.0)) > 1.0 - 0.25 * mids * mids - 0.1 * b) c.rgb = tex(fract(uv + vec2(hash(block), hash(block.yx)) * 0.3)).rgb * vec3(1.1, 0.9, 1.2);
        // A bright noise line now and then.
        if (abs(uv.y - hash(vec2(floor(t), 9.0))) < 0.004 && hash(vec2(t, 4.0)) < 0.5 * highs) c.rgb = vec3(hash(uv * t));
    } else if (m == 2) {  // crt
        vec2 q = uv * 2.0 - 1.0;
        q *= 1.0 + (0.02 + 0.14 * pm) * dot(q, q);  // bulge, with the bass
        vec2 p = q * 0.5 + 0.5;
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) { fragColor = vec4(0.0); return; }
        float s = 0.001 + 0.012 * pm + 0.004 * b;
        c = vec4(tex(p + vec2(s, 0.0)).r, tex(p).g, tex(p - vec2(s, 0.0)).b, 1.0);
        c.rgb *= 0.78 + 0.22 * sin(p.y * 380.0);                           // scanlines
        c.rgb += 0.08 * smoothstep(0.08, 0.0, abs(fract(p.y - t * 0.02) - 0.5));  // rolling band
        c.rgb *= 0.55 + 0.6 * loud + 0.3 * highs * hash(vec2(t, 2.0)) + 0.2 * b;  // brighter, flickering with the music
        c.rgb *= 1.0 - 0.35 * dot(q, q) * 0.5;                            // vignette
        c.a = tex(p).a;
    } else if (m == 3) {  // melt
        // Each column drips as far as its band (32 columns over 16 bands).
        float col = floor(uv.x * 32.0);
        float drip = 0.5 + 0.5 * hash(vec2(col, 5.0));
        float fall = drip * (0.01 + 0.3 * spec(col / 31.0, t)) * (1.0 + b) * smoothstep(0.0, 1.0, uv.y);
        vec2 p = uv - vec2(0.012 * sin(uv.y * 14.0 + t * 0.35) * (0.4 + b), fall);
        c = tex(p);
    } else if (m == 4) {  // datamosh
        vec2 bs = vec2(14.0, 14.0 / aspect);
        vec2 block = floor(uv * bs);
        float k = floor(t / 3.0);
        float r = hash(block + k * 1.3);
        float amt = 0.04 + 0.96 * pm;                                       // still clean in silence
        vec2 p = uv;
        bool moved = false;
        if (r < 0.45 * amt) {
            // Slid along its own (stale) motion.
            p += (vec2(hash(block + k), hash(block.yx + k)) - 0.5) * 0.32 * amt;
            moved = true;
        } else if (r > 1.0 - 0.25 * amt) {
            // Smeared: the block's left edge stretched across it.
            float edge = block.x / bs.x;
            p.x = edge + (uv.x - edge) * 0.06;
            moved = true;
        }
        c = tex(p);
        if (moved) c.rgb = vec3(c.r, tex(p + vec2(0.012, 0.0)).g, c.b) * vec3(1.05, 1.0, 1.1);
    } else if (m == 5) {  // tear
        float row = floor(uv.y * 40.0);
        float f = spec(1.0 - row / 39.0, t);
        float dir = hash(vec2(row, floor(t / 2.0))) > 0.5 ? 1.0 : -1.0;
        float shift = pow(f, 1.6) * 0.4 * dir * (0.7 + 1.2 * b);         // wider on the kicks
        float split = 0.004 + 0.06 * abs(shift);
        vec2 p = vec2(fract(uv.x + shift), uv.y);
        c = vec4(tex(vec2(fract(p.x + split), p.y)).r, tex(p).g, tex(vec2(fract(p.x - split), p.y)).b, tex(p).a);
    } else if (m == 6) {  // pixel sort
        c = tex(uv);
        float col = floor(uv.x * 64.0);
        float f = spec(col / 63.0, t);
        // Some column runs sort, some don't (changing every so often).
        if (hash(vec2(col, floor(t / 8.0))) < 0.35 + 0.6 * f) {
            float thr = 0.72 - 0.4 * loud - 0.25 * b;                     // more pixels sort on a kick
            float len = 0.04 + 0.45 * f;
            float best = lum(c.rgb);
            for (int i = 1; i <= 12; i++) {
                vec4 s = tex(uv - vec2(0.0, len * float(i) / 12.0));
                float l = lum(s.rgb);
                if (l > thr && l > best) { c = s; best = l; }
            }
        }
    } else if (m == 7) {  // bitcrush
        float cells = mix(110.0, 26.0, clamp(loud * 1.6, 0.0, 1.0));
        vec2 cell = vec2(cells, cells / aspect);
        vec2 q = floor(uv * cell);
        c = tex((q + 0.5) / cell);
        // Fewer levels the louder it is; dithered so the picture survives.
        float levels = floor(mix(7.0, 3.0, clamp(loud * 1.3 + 0.3 * b, 0.0, 1.0)));
        float d = (bayer4(q) - 0.5) * 0.9;
        c.rgb = floor(c.rgb * (levels - 1.0) + 0.5 + d) / (levels - 1.0);
        // Flipped bits: a row swaps channels or wraps around.
        float row = q.y;
        float hr = hash(vec2(row, floor(t)));
        if (hr > 1.0 - 0.12 * highs - 0.05 * b) c.rgb = c.gbr;
        else if (hr < 0.06 * highs) c.rgb = fract(c.rgb + 0.5);
        c.rgb = clamp(c.rgb, 0.0, 1.0);
    } else if (m == 8) {  // vhs
        vec2 p = uv;
        float roll = fract(t * 0.008);
        float inBand = smoothstep(0.12, 0.0, abs(uv.y - roll));
        float line = floor(uv.y * 160.0);
        p.y += (hash(vec2(floor(t), 1.0)) - 0.5) * 0.006 * (1.0 + 3.0 * b);        // jitter
        p.x += (hash(vec2(line, t)) - 0.5) * (0.09 * inBand + 0.06 * pm + 0.05 * b);  // tracking, on the bass
        p.x += sin(uv.y * 28.0 + t * 0.5) * 0.004 * (0.3 + 3.0 * pm);              // wobble
        if (uv.y > 0.92) p.x += (hash(vec2(line, floor(t))) - 0.5) * 0.12;        // head switching
        // Colour bleeds and lags to the right; brightness a little soft.
        vec3 bleed = vec3(0.0);
        float spread = 0.003 + 0.022 * loud;                                        // wider when loud
        for (int i = 0; i < 6; i++) bleed += tex(p - vec2(spread * (1.0 + float(i)), 0.0)).rgb;
        bleed /= 6.0;
        vec4 src = tex(p);
        float y = (lum(src.rgb) + lum(tex(p + vec2(0.004, 0.0)).rgb)) * 0.5;
        c = vec4(vec3(y) + (bleed - lum(bleed)) * (0.8 + 2.0 * loud), src.a);
        c.rgb += (hash(uv * vec2(320.0, 240.0) + t) - 0.5) * (0.08 + 0.25 * highs);  // hiss
        c.rgb += inBand * (0.05 + 0.35 * pm) * (0.5 + hash(vec2(line, t + 3.0)));  // the tracking band
        c.rgb = vec3(0.07, 0.05, 0.09) + c.rgb * vec3(0.98, 0.92, 0.86);             // washed blacks, worn
    } else {
        c = tex(uv);
    }
    fragColor = c * qt_Opacity;
}
