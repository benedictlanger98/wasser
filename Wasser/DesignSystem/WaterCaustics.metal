#include <metal_stdlib>
using namespace metal;

// Faithful port of the design's WebGL hero shader (Wassertemperatur.dc.html).
// Applied via SwiftUI `.colorEffect`, so it runs per output pixel: it ignores
// the incoming colour and computes the water surface procedurally.
//
// Coordinates: SwiftUI hands us `position` in points, top-left origin. The
// original GLSL used a bottom-left origin (gl_FragCoord), so we flip Y to keep
// the gradient/caustics oriented as designed — light (shallow) at the top.

constant float TAU = 6.28318530718;

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),               hash(i + float2(1.0, 0.0)), u.x),
               mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), u.x), u.y);
}

// Layered caustic field — 5 octaves of travelling sine interference.
static float caustic(float2 uv, float uTime) {
    float time = uTime * 0.5 + 23.0;
    float2 p = (TAU * fract(uv)) - 250.0;   // == mod(uv*TAU, TAU) - 250
    float2 i = p;
    float c = 1.0;
    float inten = 0.005;
    for (int n = 0; n < 5; n++) {
        float t = time * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y),
                       sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + t) / inten),
                                 p.y / (cos(i.y + t) / inten)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}

[[ stitchable ]]
half4 waterCaustics(float2 position,
                    half4 color,
                    float2 size,
                    float uTime,
                    float3 uDeep,
                    float3 uShallow,
                    float3 uSun,
                    float uIntensity,
                    float uRays,
                    float uFlow) {
    float2 uv = float2(position.x / size.x, 1.0 - position.y / size.y);

    float g = smoothstep(0.0, 1.0, uv.y);
    float3 col = mix(uDeep, uShallow, g);

    // Surface ripple distorting the caustic lookup.
    float rip = sin(uv.x * 8.0 + uTime * 1.2) * 0.004
              + sin(uv.y * 14.0 - uTime * 0.8) * 0.003;
    float2 cuv = uv * 2.2;
    cuv.x += uTime * uFlow;
    cuv += rip;

    float c = caustic(cuv + float2(0.0, uTime * 0.02), uTime);
    float topMask = pow(uv.y, 1.3);
    col += uSun * c * uIntensity * (0.35 + 0.65 * topMask);

    // Vertical god-rays, concentrated near the surface. A single noise lookup
    // (the second sparkle/ray octave was dropped — it added scattered "bubble"
    // specks and a second noise() call per pixel without reading as water).
    float ray = noise(float2(uv.x * 5.0 - uTime * 0.05, 0.0));
    ray = pow(ray, 2.2);
    col += uSun * ray * pow(uv.y, 2.0) * uRays;

    // Vignette.
    float vig = smoothstep(1.15, 0.25, length(uv - 0.5));
    col *= 0.82 + 0.18 * vig;

    return half4(half3(col), 1.0h);
}
