//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer Arcade RGB Mask

vec4 hook() {
    vec4 color = MAIN_tex(MAIN_pos);
    vec2 pixel = floor(MAIN_pos * target_size);
    float column = mod(pixel.x, 3.0);
    vec3 mask = column < 1.0 ? vec3(1.22, 0.78, 0.78)
              : column < 2.0 ? vec3(0.78, 1.22, 0.78)
                             : vec3(0.78, 0.78, 1.22);
    float scan = mix(0.78, 1.10, step(1.0, mod(pixel.y, 2.0)));
    color.rgb *= mask * scan * 1.08;
    color.rgb = pow(max(color.rgb, vec3(0.0)), vec3(0.92));
    return color;
}
