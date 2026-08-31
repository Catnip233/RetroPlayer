//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer VHS

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 hook() {
    vec2 uv = MAIN_pos;
    float line = floor(uv.y * target_size.y);
    // Keep geometry almost straight: less than half a pixel of horizontal
    // displacement at a typical 960 px window.
    float wobble = sin(uv.y * 72.0) * 0.00012 + (hash(vec2(line, 7.0)) - 0.5) * 0.00020;
    vec2 shifted = clamp(uv + vec2(wobble, 0.0), vec2(0.0), vec2(1.0));
    float offset = 1.1 / target_size.x;
    vec3 color;
    color.r = MAIN_tex(clamp(shifted + vec2(offset, 0.0), vec2(0.0), vec2(1.0))).r;
    color.g = MAIN_tex(shifted).g;
    color.b = MAIN_tex(clamp(shifted - vec2(offset, 0.0), vec2(0.0), vec2(1.0))).b;
    float noise = (hash(vec2(floor(uv.x * 420.0), line)) - 0.5) * 0.028;
    float scan = mod(floor(uv.y * target_size.y), 2.0) < 1.0 ? 0.97 : 1.0;
    color = (color + noise) * scan;
    color = mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, 0.88);
    return vec4(color, 1.0);
}
