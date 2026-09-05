#ifndef CMPVBridge_h
#define CMPVBridge_h

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
typedef struct RXMPV RXMPV;

RXMPV *rx_mpv_create(const char *shader_path);
void rx_mpv_destroy(RXMPV *player);
int rx_mpv_initialize_gl(RXMPV *player);
void rx_mpv_render(RXMPV *player, int framebuffer, int width, int height);
enum {
    RX_MPV_EVENT_FILE_LOADED = 1 << 0,
    RX_MPV_EVENT_END_FILE = 1 << 1,
    RX_MPV_EVENT_PLAYBACK_ERROR = 1 << 2,
    RX_MPV_EVENT_SHADER_ERROR = 1 << 3
};
uint32_t rx_mpv_poll_events(RXMPV *player);
int rx_mpv_load(RXMPV *player, const char *path);
void rx_mpv_set_pause(RXMPV *player, bool paused);
bool rx_mpv_get_pause(RXMPV *player);
bool rx_mpv_get_eof_reached(RXMPV *player);
void rx_mpv_seek(RXMPV *player, double seconds);
double rx_mpv_get_time(RXMPV *player);
double rx_mpv_get_duration(RXMPV *player);
double rx_mpv_get_video_aspect(RXMPV *player);
void rx_mpv_set_volume(RXMPV *player, double volume);
int rx_mpv_set_shader(RXMPV *player, const char *shader_path);
int rx_mpv_set_shader_pipeline(RXMPV *player, const char *capture_path,
                               const char *shader_path, const char *blend_path);
void rx_mpv_set_shader_options(RXMPV *player, const char *options);
int rx_mpv_set_double_property(RXMPV *player, const char *name, double value);
double rx_mpv_get_double_property(RXMPV *player, const char *name);
int rx_mpv_set_string_property(RXMPV *player, const char *name, const char *value);
uint64_t rx_mpv_get_track_revision(RXMPV *player);
int64_t rx_mpv_get_track_count(RXMPV *player);
int rx_mpv_get_track_type(RXMPV *player, int64_t index);
int64_t rx_mpv_get_track_id(RXMPV *player, int64_t index);
bool rx_mpv_get_track_selected(RXMPV *player, int64_t index);
bool rx_mpv_copy_track_string(RXMPV *player, int64_t index, const char *field,
                              char *buffer, size_t buffer_size);
int rx_mpv_set_audio_track(RXMPV *player, int64_t track_id);
int rx_mpv_set_subtitle_track(RXMPV *player, int64_t track_id);
int rx_mpv_add_subtitle(RXMPV *player, const char *path);

#endif
