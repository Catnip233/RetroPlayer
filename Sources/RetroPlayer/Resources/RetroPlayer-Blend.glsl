//!HOOK MAIN
//!BIND HOOKED
//!BIND RETROPLAYER_ORIGINAL
//!DESC RetroPlayer global shader strength
//!PARAM retroplayer_strength
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
//!DEFAULT 1.0

vec4 hook() {
    vec4 original = RETROPLAYER_ORIGINAL_tex(RETROPLAYER_ORIGINAL_pos);
    vec4 filtered = HOOKED_tex(HOOKED_pos);
    return mix(original, filtered, retroplayer_strength);
}
