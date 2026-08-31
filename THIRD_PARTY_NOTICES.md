# Third-party notices

## CRT-Lottes shader

`Sources/RetroPlayer/Resources/CRT.glsl` is based on Timothy Lottes' CRT
shader and its mpv port from
[`hhirtz/mpv-retro-shaders`](https://github.com/hhirtz/mpv-retro-shaders).

The original shader is in the public domain. The mpv port is distributed under
the permissive notice retained at the top of `CRT.glsl`.

## Community shaders

`Community-Lottes.glsl` and `Community-GBA.glsl` are copied from
[`hhirtz/mpv-retro-shaders`](https://github.com/hhirtz/mpv-retro-shaders),
revision `f4ea211db4e2afb5f5dc5a3daf816749c9cd7f03`. Their public-domain and
permissive notices are retained verbatim in the files.

`Community-Anime4K-Restore.glsl` is Anime4K Restore CNN (M), copied from
[`bloc97/Anime4K`](https://github.com/bloc97/Anime4K), revision
`7684e9586f8dcc738af08a1cdceb024cc184f426`. It is distributed under the MIT
License; the full copyright and permission notice is retained in the shader.

## Sony CRT-style presets

`Sony-PVM-20L4.glsl` and `Sony-PVM-2730.glsl` are original RetroPlayer
implementations informed by the publicly documented Sony Megatron PVM preset
parameters and community Trinitron preset research. `Sony-BVM-Kurozumi.glsl`
uses the permissively licensed Lottes mpv port with RetroPlayer's flat-screen
Kurozumi-style parameter tuning; its original notice is retained in the file.

These are unofficial visual simulations. Sony product names identify the
reference display style only; Sony is not affiliated with RetroPlayer.

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
