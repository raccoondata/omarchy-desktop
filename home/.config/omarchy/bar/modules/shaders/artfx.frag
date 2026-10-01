#version 440
// Album art effects for the now-playing card and the Super menu's strip,
// following the music (AudioLevels.js, from cava: the spectrum, loudness and
// the bass's pulse); without it, a generated beat. The CPU only hands those
// over and advances `tick` ~15 times a second while shown and playing.
// Compile: shaders/build. Modes:
//   1 glitch  slices jump sideways on the treble, channels split on the bass,
//             blocks corrupt with the mids
//   2 chroma  red / green / blue pushed apart by the bass, swirling
//   3 pixel   a mosaic coarser the louder it is, in few colours
//   4 crt     scanlines, a rolling band, a screen bulging with the bass
//   5 melt    each column of the picture drips as far as its band
//   6 solar   solarized flashes and a posterized, inverted bloom on the bass
//   7 night   grainy green night-vision footage; the tape tracks on kicks
//   8 torch   the picture in the dark, lit by a roaming flashlight that
//             widens with the loudness
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
        float shift = (jolt > edge ? (jolt - edge) * 0.9 : 0.0) * (0.3 + b + pm) * sign(hash(vec2(slice, t)) - 0.5);
        vec2 p = uv + vec2(shift, 0.0);
        float split = 0.003 + 0.04 * pm;
        c = vec4(tex(p + vec2(split, 0.0)).r, tex(p).g, tex(p - vec2(split, 0.0)).b, tex(p).a);
        // Corrupt blocks: a patch shows another part of the picture.
        vec2 block = floor(uv * vec2(8.0, 10.0));
        if (hash(block + floor(t / 2.0)) > 0.97 - 0.25 * mids * mids - 0.1 * b) c.rgb = tex(fract(uv + vec2(hash(block), hash(block.yx)) * 0.3)).rgb * vec3(1.1, 0.9, 1.2);
        // A bright noise line now and then.
        if (abs(uv.y - hash(vec2(floor(t), 9.0))) < 0.004 && hash(vec2(t, 4.0)) > 0.6) c.rgb = vec3(hash(uv * t));
    } else if (m == 2) {  // chroma
        float a = t * 0.15;
        vec2 dir = vec2(cos(a), sin(a)) * (0.003 + 0.05 * pm + 0.02 * b);
        c = vec4(tex(uv + dir).r, tex(uv - dir * 0.5).g, tex(uv - dir).b, tex(uv).a);
    } else if (m == 3) {  // pixel
        float cells = mix(72.0, 8.0, clamp(loud * 1.5 + 0.4 * b, 0.0, 1.0));
        vec2 cell = vec2(cells, cells / aspect);
        vec2 p = (floor(uv * cell) + 0.5) / cell;
        c = tex(p);
        c.rgb = floor(c.rgb * 5.0 + 0.5) / 5.0;
    } else if (m == 4) {  // crt
        vec2 q = uv * 2.0 - 1.0;
        q *= 1.0 + (0.02 + 0.14 * pm) * dot(q, q);  // bulge, with the bass
        vec2 p = q * 0.5 + 0.5;
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) { fragColor = vec4(0.0); return; }
        float s = 0.0025 + 0.004 * b;
        c = vec4(tex(p + vec2(s, 0.0)).r, tex(p).g, tex(p - vec2(s, 0.0)).b, 1.0);
        c.rgb *= 0.78 + 0.22 * sin(p.y * 380.0);                           // scanlines
        c.rgb += 0.08 * smoothstep(0.08, 0.0, abs(fract(p.y - t * 0.02) - 0.5));  // rolling band
        c.rgb *= 0.88 + 0.25 * highs * hash(vec2(t, 2.0)) + 0.2 * b;       // flicker
        c.rgb *= 1.0 - 0.35 * dot(q, q) * 0.5;                            // vignette
        c.a = tex(p).a;
    } else if (m == 5) {  // melt
        // Each column drips as far as its band (32 columns over 16 bands).
        float col = floor(uv.x * 32.0);
        float drip = 0.5 + 0.5 * hash(vec2(col, 5.0));
        float fall = drip * (0.01 + 0.3 * spec(col / 31.0, t)) * smoothstep(0.0, 1.0, uv.y);
        vec2 p = uv - vec2(0.012 * sin(uv.y * 14.0 + t * 0.35) * (0.4 + b), fall);
        c = tex(p);
    } else if (m == 6) {  // solar
        c = tex(uv);
        float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        vec3 sol = abs(c.rgb - vec3(step(0.5, l)));        // solarize
        vec3 post = floor(c.rgb * 4.0) / 4.0;
        c.rgb = mix(post, 1.0 - sol, smoothstep(0.2, 0.85, max(b, pm * pm)));
    } else if (m == 7) {  // night vision
        vec2 p = uv;
        // A kick knocks the tape's tracking: a band slides sideways.
        float band = floor(uv.y * 24.0);
        if (b > 0.35 && hash(vec2(band, floor(t))) > 0.8) p.x += (hash(vec2(band, t)) - 0.5) * 0.08 * b;
        vec4 src = tex(p);
        float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
        l = pow(l, 0.8) * (0.8 + 0.7 * loud + 0.5 * b);                   // gain, blooming with the music
        l += (hash(uv * 400.0 + t) - 0.5) * (0.1 + 0.3 * highs);           // grain, hissing on the treble
        l *= 0.86 + 0.14 * sin(uv.y * 520.0);                              // scanlines
        vec2 q = uv * 2.0 - 1.0;
        l *= 1.0 - 0.55 * dot(q, q) * 0.5;                                 // tube vignette
        c = vec4(vec3(0.32, 1.0, 0.42) * clamp(l, 0.0, 1.2), src.a);
    } else if (m == 8) {  // torch
        vec4 src = tex(uv);
        // The beam wanders over the picture; wider when the music swells.
        vec2 spot = vec2(0.5 + 0.32 * sin(t * 0.045) , 0.5 + 0.28 * sin(t * 0.063 + 1.3));
        vec2 d = (uv - spot) * vec2(aspect, 1.0);
        float radius = 0.12 + 0.35 * loud + 0.1 * pm;
        float light = smoothstep(radius, radius * 0.35, length(d));
        light *= hash(vec2(floor(t * 0.5), 5.0)) > 0.98 - 0.15 * highs ? 0.4 : 1.0;  // a flicker
        c = vec4(src.rgb * (0.05 + light * vec3(1.05, 1.0, 0.88)), src.a);
    } else {
        c = tex(uv);
    }
    fragColor = c * qt_Opacity;
}
