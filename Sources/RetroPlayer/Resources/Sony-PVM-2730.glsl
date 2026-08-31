// RetroPlayer's mpv-compatible Sony PVM 2730 style preset.
// Beam/convergence direction follows the public Sony Megatron PVM 2730 SDR
// preset. This is an independent implementation, not Sony firmware.

//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer Sony PVM 2730 Style

vec4 hook() {
    vec2 uv = MAIN_pos;
    vec2 onePixel = 1.0 / target_size;
    vec4 source = MAIN_tex(uv);

    // The larger 27-inch tube is represented with a softer horizontal beam
    // and a tiny red-channel vertical convergence offset.
    vec3 center = source.rgb;
    vec3 left = MAIN_tex(clamp(uv - vec2(onePixel.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
    vec3 right = MAIN_tex(clamp(uv + vec2(onePixel.x, 0.0), vec2(0.0), vec2(1.0))).rgb;
    vec3 color = mix(center, (left + center * 2.0 + right) * 0.25, 0.20);
    color.r = MAIN_tex(clamp(uv - vec2(0.0, 0.14 / MAIN_size.y), vec2(0.0), vec2(1.0))).r;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float lineDistance = abs(fract(uv.y * MAIN_size.y) - 0.5) * 2.0;
    float beamWidth = mix(0.48, 0.86, sqrt(clamp(luma, 0.0, 1.0)));
    float scanline = exp2(-2.4 * lineDistance * lineDistance / (beamWidth * beamWidth));
    scanline = mix(0.52, 1.08, scanline);

    // Wider, softer grille than the 20L4 preset.
    float stripe = mod(floor(uv.x * target_size.x / 2.0), 3.0);
    vec3 grille = stripe < 1.0 ? vec3(1.15, 0.84, 0.84)
                : stripe < 2.0 ? vec3(0.84, 1.15, 0.84)
                               : vec3(0.84, 0.84, 1.15);

    color *= scanline * grille * 1.11;
    vec3 effected = pow(max(color, vec3(0.0)), vec3(0.975));
    return vec4(mix(source.rgb, effected, 0.3), source.a);
}
