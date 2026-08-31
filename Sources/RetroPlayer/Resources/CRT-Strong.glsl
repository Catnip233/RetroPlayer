//!HOOK MAIN
//!BIND MAIN
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!DESC RetroPlayer Strong Scanlines

vec4 hook() {
    vec4 color = MAIN_tex(MAIN_pos);
    vec2 pixel = floor(MAIN_pos * target_size);

    // One visibly dark line followed by two bright lines.  floor/mod avoids
    // the half-pixel cosine cancellation that made the old preset look flat.
    float row = mod(pixel.y, 3.0);
    float scan = row < 1.0 ? 0.52 : 1.08;

    float column = mod(pixel.x, 3.0);
    vec3 grille = column < 1.0 ? vec3(1.10, 0.90, 0.90)
                : column < 2.0 ? vec3(0.90, 1.10, 0.90)
                               : vec3(0.90, 0.90, 1.10);
    color.rgb *= scan * grille * 1.16;
    color.rgb = pow(max(color.rgb, vec3(0.0)), vec3(0.96));
    return color;
}
