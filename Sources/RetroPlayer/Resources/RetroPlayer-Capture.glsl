//!HOOK MAIN
//!BIND HOOKED
//!SAVE RETROPLAYER_ORIGINAL
//!DESC RetroPlayer original frame capture

vec4 hook() {
    return HOOKED_tex(HOOKED_pos);
}
