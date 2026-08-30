#ifndef CMPVBridge_h
#define CMPVBridge_h

#include <stdbool.h>
typedef struct RXMPV RXMPV;

RXMPV *rx_mpv_create(const char *shader_path);
void rx_mpv_destroy(RXMPV *player);
int rx_mpv_initialize_gl(RXMPV *player);
void rx_mpv_render(RXMPV *player, int framebuffer, int width, int height);
void rx_mpv_poll_events(RXMPV *player);
int rx_mpv_load(RXMPV *player, const char *path);
void rx_mpv_set_pause(RXMPV *player, bool paused);
bool rx_mpv_get_pause(RXMPV *player);
void rx_mpv_seek(RXMPV *player, double seconds);
double rx_mpv_get_time(RXMPV *player);
double rx_mpv_get_duration(RXMPV *player);
void rx_mpv_set_volume(RXMPV *player, double volume);
void rx_mpv_set_shader_options(RXMPV *player, const char *options);

#endif
