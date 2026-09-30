#version 440
// Album art effects for the now-playing card (nowplaying.qml, ArtEffect). The
// "beat" is decorative, hashed from `tick` here (no audio, no CPU work: the
// item only advances tick ~15 times a second while the card is open and
// playing). Compile: shaders/build. Modes:
//   1 glitch  slices jump sideways, colour channels split, blocks corrupt
//   2 chroma  red / green / blue drift apart and swirl with the beat
//   3 pixel   a mosaic that pulses coarser on the beat, in few colours
//   4 crt     scanlines, a rolling band, a bulging screen, a flicker
//   5 melt    the picture drips and wobbles downward
//   6 solar   solarized flashes and a posterized, inverted bloom on the beat
//   7 night   grainy green night-vision footage; the tape tracks on kicks
//   8 torch   the picture in the dark, lit by a roaming flashlight
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float tick;
    float mode;
    float aspect;   // width / height
    float live;     // 1: beatLevel is the music's (AudioLevels.js)
    float beatLevel;
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

vec4 tex(vec2 uv) { return texture(source, clamp(uv, 0.0, 1.0)); }

void main() {
    vec2 uv = qt_TexCoord0;
    float t = tick;
    float b = live > 0.5 ? beatLevel : beat(t);
    int m = int(mode + 0.5);
    vec4 c;

    if (m == 1) {  // glitch
        float rows = 18.0;
        float slice = floor(uv.y * rows);
        float jolt = hash(vec2(slice, floor(t))) ;
        float shift = (jolt > 0.78 ? (jolt - 0.78) * 0.9 : 0.0) * (0.3 + b) * sign(hash(vec2(slice, t)) - 0.5);
        vec2 p = uv + vec2(shift, 0.0);
        float split = 0.006 + 0.03 * b;
        c = vec4(tex(p + vec2(split, 0.0)).r, tex(p).g, tex(p - vec2(split, 0.0)).b, tex(p).a);
        // Corrupt blocks: a patch shows another part of the picture.
        vec2 block = floor(uv * vec2(8.0, 10.0));
        if (hash(block + floor(t / 2.0)) > 0.94 - 0.1 * b) c.rgb = tex(fract(uv + vec2(hash(block), hash(block.yx)) * 0.3)).rgb * vec3(1.1, 0.9, 1.2);
        // A bright noise line now and then.
        if (abs(uv.y - hash(vec2(floor(t), 9.0))) < 0.004 && hash(vec2(t, 4.0)) > 0.6) c.rgb = vec3(hash(uv * t));
    } else if (m == 2) {  // chroma
        float a = t * 0.15;
        vec2 dir = vec2(cos(a), sin(a)) * (0.008 + 0.035 * b);
        c = vec4(tex(uv + dir).r, tex(uv - dir * 0.5).g, tex(uv - dir).b, tex(uv).a);
    } else if (m == 3) {  // pixel
        float cells = mix(64.0, 10.0, clamp(b * 1.3, 0.0, 1.0));
        vec2 cell = vec2(cells, cells / aspect);
        vec2 p = (floor(uv * cell) + 0.5) / cell;
        c = tex(p);
        c.rgb = floor(c.rgb * 5.0 + 0.5) / 5.0;
    } else if (m == 4) {  // crt
        vec2 q = uv * 2.0 - 1.0;
        q *= 1.0 + 0.06 * dot(q, q);  // bulge
        vec2 p = q * 0.5 + 0.5;
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) { fragColor = vec4(0.0); return; }
        float s = 0.0025 + 0.004 * b;
        c = vec4(tex(p + vec2(s, 0.0)).r, tex(p).g, tex(p - vec2(s, 0.0)).b, 1.0);
        c.rgb *= 0.78 + 0.22 * sin(p.y * 380.0);                           // scanlines
        c.rgb += 0.08 * smoothstep(0.08, 0.0, abs(fract(p.y - t * 0.02) - 0.5));  // rolling band
        c.rgb *= 0.92 + 0.08 * hash(vec2(t, 2.0)) + 0.2 * b;               // flicker
        c.rgb *= 1.0 - 0.35 * dot(q, q) * 0.5;                            // vignette
        c.a = tex(p).a;
    } else if (m == 5) {  // melt
        float drip = hash(vec2(floor(uv.x * 40.0), 5.0));
        float fall = drip * (0.04 + 0.12 * b) * smoothstep(0.0, 1.0, uv.y);
        vec2 p = uv - vec2(0.012 * sin(uv.y * 14.0 + t * 0.35) * (0.4 + b), fall);
        c = tex(p);
    } else if (m == 6) {  // solar
        c = tex(uv);
        float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        vec3 sol = abs(c.rgb - vec3(step(0.5, l)));        // solarize
        vec3 post = floor(c.rgb * 4.0) / 4.0;
        c.rgb = mix(post, 1.0 - sol, smoothstep(0.25, 0.9, b));
    } else if (m == 7) {  // night vision
        vec2 p = uv;
        // A kick knocks the tape's tracking: a band slides sideways.
        float band = floor(uv.y * 24.0);
        if (b > 0.35 && hash(vec2(band, floor(t))) > 0.8) p.x += (hash(vec2(band, t)) - 0.5) * 0.08 * b;
        vec4 src = tex(p);
        float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
        l = pow(l, 0.8) * (1.05 + 0.5 * b);                               // gain, blooming on the beat
        l += (hash(uv * 400.0 + t) - 0.5) * 0.18;                          // grain
        l *= 0.86 + 0.14 * sin(uv.y * 520.0);                              // scanlines
        vec2 q = uv * 2.0 - 1.0;
        l *= 1.0 - 0.55 * dot(q, q) * 0.5;                                 // tube vignette
        c = vec4(vec3(0.32, 1.0, 0.42) * clamp(l, 0.0, 1.2), src.a);
    } else if (m == 8) {  // torch
        vec4 src = tex(uv);
        // The beam wanders over the picture; wider when the music swells.
        vec2 spot = vec2(0.5 + 0.32 * sin(t * 0.045) , 0.5 + 0.28 * sin(t * 0.063 + 1.3));
        vec2 d = (uv - spot) * vec2(aspect, 1.0);
        float radius = 0.22 + 0.16 * b;
        float light = smoothstep(radius, radius * 0.35, length(d));
        light *= hash(vec2(floor(t * 0.5), 5.0)) > 0.95 ? 0.4 : 1.0;      // a flicker
        c = vec4(src.rgb * (0.05 + light * vec3(1.05, 1.0, 0.88)), src.a);
    } else {
        c = tex(uv);
    }
    fragColor = c * qt_Opacity;
}
