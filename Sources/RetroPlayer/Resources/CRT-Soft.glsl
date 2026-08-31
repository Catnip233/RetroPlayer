//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer Soft CRT

vec4 hook() {
    vec4 source = MAIN_tex(MAIN_pos);
    vec2 pixel = floor(MAIN_pos * target_size);

    // A restrained two-line scan pattern.  It preserves the original image
    // instead of turning every other line black.
    float scan = mod(pixel.y, 2.0) < 1.0 ? 0.94 : 1.02;

    // Very light RGB phosphor variation, intentionally too subtle to read as
    // a coarse arcade mask at normal viewing distance.
    float column = mod(pixel.x, 3.0);
    vec3 mask = column < 1.0 ? vec3(1.025, 0.99, 0.99)
              : column < 2.0 ? vec3(0.99, 1.025, 0.99)
                             : vec3(0.99, 0.99, 1.025);

    vec3 color = source.rgb * scan * mask * 1.025;
    color = pow(max(color, vec3(0.0)), vec3(0.985));
    return vec4(color, source.a);
}
