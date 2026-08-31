//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer Monochrome TV

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(41.0, 289.0))) * 45758.5453);
}

vec4 hook() {
    vec4 source = MAIN_tex(MAIN_pos);
    float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
    luma = smoothstep(0.02, 0.98, luma);
    vec2 pixel = MAIN_pos * target_size;
    float scan = 0.80 + 0.20 * cos(3.14159265 * pixel.y);
    float grain = (hash(floor(pixel * vec2(0.45, 1.0))) - 0.5) * 0.035;
    vec3 phosphor = vec3(0.93, 1.0, 0.94) * (luma * scan + grain);
    return vec4(phosphor, source.a);
}
