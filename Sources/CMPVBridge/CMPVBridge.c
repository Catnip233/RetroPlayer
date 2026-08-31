#include "CMPVBridge.h"
#include <mpv/client.h>
#include <mpv/render.h>
#include <mpv/render_gl.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct RXMPV { mpv_handle *handle; mpv_render_context *render; };

static void *rx_get_proc_address(void *context, const char *name) {
    (void)context;
    return dlsym(RTLD_DEFAULT, name);
}

RXMPV *rx_mpv_create(const char *shader_path) {
    RXMPV *player = calloc(1, sizeof(RXMPV));
    if (!player) return NULL;
    player->handle = mpv_create();
    if (!player->handle) { free(player); return NULL; }
    mpv_set_option_string(player->handle, "vo", "libmpv");
    mpv_set_option_string(player->handle, "terminal", "no");
    mpv_set_option_string(player->handle, "msg-level", "all=no");
    mpv_set_option_string(player->handle, "hwdec", "auto-safe");
    mpv_set_option_string(player->handle, "keep-open", "yes");
    mpv_set_option_string(player->handle, "osc", "no");
    // Phone-formatted uploads often contain a 4:3 picture centered inside a
    // portrait frame. Crop the decoded frame to its centered 4:3 region so
    // the baked-in black bars never reach the monitor surface.
    mpv_set_option_string(player->handle, "video-crop", "4:3");
    mpv_set_option_string(player->handle, "sub-auto", "fuzzy");
    mpv_set_option_string(player->handle, "sub-visibility", "yes");
    mpv_set_option_string(player->handle, "sub-font", "Songti SC");
    mpv_set_option_string(player->handle, "sub-bold", "yes");
    mpv_set_option_string(player->handle, "sub-font-size", "40");
    mpv_set_option_string(player->handle, "sub-color", "#FFF2E2C4");
    mpv_set_option_string(player->handle, "sub-outline-color", "#E6000000");
    mpv_set_option_string(player->handle, "sub-outline-size", "2.2");
    mpv_set_option_string(player->handle, "sub-shadow-offset", "1.4");
    mpv_set_option_string(player->handle, "sub-ass-override", "force");
    mpv_set_option_string(player->handle, "audio-client-name", "RetroPlayer");
    // `glsl-shaders-append` is a command-line/config action and libmpv's
    // embedding API rejects it with MPV_ERROR_OPTION_NOT_FOUND. Set the
    // underlying string-list option directly so the bundled shader is loaded.
    if (shader_path && shader_path[0]) mpv_set_option_string(player->handle, "glsl-shaders", shader_path);
    if (mpv_initialize(player->handle) < 0) {
        mpv_terminate_destroy(player->handle); free(player); return NULL;
    }
    return player;
}

void rx_mpv_destroy(RXMPV *player) {
    if (!player) return;
    if (player->render) mpv_render_context_free(player->render);
    if (player->handle) mpv_terminate_destroy(player->handle);
    free(player);
}

int rx_mpv_initialize_gl(RXMPV *player) {
    if (!player || !player->handle) return -1;
    if (player->render) return 0;
    mpv_opengl_init_params gl = { rx_get_proc_address, NULL };
    const char *api = MPV_RENDER_API_TYPE_OPENGL;
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_API_TYPE, (void *)api },
        { MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl },
        { MPV_RENDER_PARAM_INVALID, NULL }
    };
    return mpv_render_context_create(&player->render, player->handle, params);
}

void rx_mpv_render(RXMPV *player, int framebuffer, int width, int height) {
    if (!player || !player->render || width < 1 || height < 1) return;
    mpv_opengl_fbo fbo = { framebuffer, width, height, 0 };
    int flip = 1;
    mpv_render_param params[] = {
        { MPV_RENDER_PARAM_OPENGL_FBO, &fbo },
        { MPV_RENDER_PARAM_FLIP_Y, &flip },
        { MPV_RENDER_PARAM_INVALID, NULL }
    };
    mpv_render_context_render(player->render, params);
}

static void rx_select_first_subtitle(RXMPV *player) {
    int64_t count = 0;
    if (mpv_get_property(player->handle, "track-list/count", MPV_FORMAT_INT64, &count) < 0) return;
    int64_t first_subtitle = -1;
    for (int64_t i = 0; i < count; i++) {
        char property[96];
        snprintf(property, sizeof(property), "track-list/%lld/type", (long long)i);
        char *type = mpv_get_property_string(player->handle, property);
        bool is_subtitle = type && strcmp(type, "sub") == 0;
        mpv_free(type);
        if (!is_subtitle) continue;

        snprintf(property, sizeof(property), "track-list/%lld/id", (long long)i);
        int64_t track_id = -1;
        mpv_get_property(player->handle, property, MPV_FORMAT_INT64, &track_id);
        if (first_subtitle < 0) first_subtitle = track_id;

        snprintf(property, sizeof(property), "track-list/%lld/selected", (long long)i);
        int selected = 0;
        mpv_get_property(player->handle, property, MPV_FORMAT_FLAG, &selected);
        if (selected) return;
    }
    if (first_subtitle >= 0) {
        mpv_set_property(player->handle, "sid", MPV_FORMAT_INT64, &first_subtitle);
        int visible = 1;
        mpv_set_property(player->handle, "sub-visibility", MPV_FORMAT_FLAG, &visible);
    }
}

void rx_mpv_poll_events(RXMPV *player) {
    if (!player || !player->handle) return;
    for (;;) {
        mpv_event *event = mpv_wait_event(player->handle, 0);
        if (event->event_id == MPV_EVENT_NONE) break;
        if (event->event_id == MPV_EVENT_FILE_LOADED) rx_select_first_subtitle(player);
    }
}

int rx_mpv_load(RXMPV *player, const char *path) {
    if (!player || !player->handle || !path) return -1;
    const char *command[] = { "loadfile", path, "replace", NULL };
    return mpv_command(player->handle, command);
}

void rx_mpv_set_pause(RXMPV *player, bool paused) {
    if (!player || !player->handle) return;
    int value = paused ? 1 : 0;
    mpv_set_property(player->handle, "pause", MPV_FORMAT_FLAG, &value);
}

bool rx_mpv_get_pause(RXMPV *player) {
    int value = 1;
    if (player && player->handle) mpv_get_property(player->handle, "pause", MPV_FORMAT_FLAG, &value);
    return value != 0;
}

void rx_mpv_seek(RXMPV *player, double seconds) {
    if (!player || !player->handle) return;
    char value[64];
    snprintf(value, sizeof(value), "%.6f", seconds);
    const char *command[] = { "seek", value, "absolute+exact", NULL };
    mpv_command(player->handle, command);
}

static double rx_get_double(RXMPV *player, const char *property) {
    double value = 0;
    if (player && player->handle) mpv_get_property(player->handle, property, MPV_FORMAT_DOUBLE, &value);
    return value;
}

double rx_mpv_get_time(RXMPV *player) { return rx_get_double(player, "time-pos"); }
double rx_mpv_get_duration(RXMPV *player) { return rx_get_double(player, "duration"); }

void rx_mpv_set_volume(RXMPV *player, double volume) {
    if (!player || !player->handle) return;
    double value = volume * 100.0;
    mpv_set_property(player->handle, "volume", MPV_FORMAT_DOUBLE, &value);
}

int rx_mpv_set_shader(RXMPV *player, const char *shader_path) {
    if (!player || !player->handle) return -1;
    // glsl-shaders is a writable string-list property.  An empty string clears
    // the list and restores unfiltered video; a path replaces the active list.
    return mpv_set_property_string(player->handle, "glsl-shaders",
                                   shader_path ? shader_path : "");
}

void rx_mpv_set_shader_options(RXMPV *player, const char *options) {
    if (player && player->handle && options) mpv_set_property_string(player->handle, "glsl-shader-opts", options);
}
