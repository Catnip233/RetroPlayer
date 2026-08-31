// RetroPlayer's mpv-compatible Sony PVM 20L4 style preset.
// Inspired by the open Sony Megatron PVM presets and Trinitron community
// presets. This is an independent implementation, not Sony firmware.

//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer Sony PVM 20L4 Style

vec4 hook() {
    vec4 source = MAIN_tex(MAIN_pos);
    vec2 outputPixel = floor(MAIN_pos * target_size);
    float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Fine, high-TVL beam: dark gaps remain visible while highlights widen.
    float lineDistance = abs(fract(MAIN_pos.y * MAIN_size.y) - 0.5) * 2.0;
    float beamWidth = mix(0.34, 0.72, sqrt(clamp(luma, 0.0, 1.0)));
    float scanline = exp2(-3.2 * lineDistance * lineDistance / (beamWidth * beamWidth));
    scanline = mix(0.38, 1.12, scanline);

    // Sony-style aperture grille: continuous vertical RGB phosphor stripes.
    float stripe = mod(outputPixel.x, 3.0);
    vec3 grille = stripe < 1.0 ? vec3(1.22, 0.76, 0.76)
                : stripe < 2.0 ? vec3(0.76, 1.22, 0.76)
                               : vec3(0.76, 0.76, 1.22);

    vec3 color = source.rgb * scanline * grille * 1.15;
    color *= vec3(0.99, 1.0, 1.015); // slightly cool professional-monitor white
    vec3 effected = pow(max(color, vec3(0.0)), vec3(0.96));
    return vec4(mix(source.rgb, effected, 0.3), source.a);
}
