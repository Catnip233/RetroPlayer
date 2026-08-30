# Third-party notices

## CRT-Lottes shader

`Sources/RetroPlayer/Resources/CRT.glsl` is based on Timothy Lottes' CRT
shader and its mpv port from
[`hhirtz/mpv-retro-shaders`](https://github.com/hhirtz/mpv-retro-shaders).

The original shader is in the public domain. The mpv port is distributed under
the permissive notice retained at the top of `CRT.glsl`.

## mpv / libmpv

RetroPlayer's source build links to Homebrew's libmpv. Packaged app releases
bundle libmpv and its required dynamic libraries under `Contents/Frameworks`;
license texts available from the installed packages are copied into
`Contents/Resources/Licenses`. See the
[`mpv-player/mpv`](https://github.com/mpv-player/mpv) project for its licensing
terms.

The bundled Homebrew dependency set includes GPL-licensed components, notably
FFmpeg, x264, and x265. Distribution and use of the packaged binary are also
subject to those third-party license terms. Corresponding upstream source is
available from:

- [mpv](https://github.com/mpv-player/mpv)
- [FFmpeg](https://github.com/FFmpeg/FFmpeg)
- [x264](https://code.videolan.org/videolan/x264)
- [x265](https://bitbucket.org/multicoreware/x265_git)
