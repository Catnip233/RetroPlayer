<p align="center">
  <img src="AppResources/RetroPlayer-icon.png" width="180" alt="RetroPlayer logo">
</p>

# RetroPlayer

RetroPlayer 是一款面向老动画与经典 4:3 影像的原生 macOS 播放器。它使用
libmpv 直接播放 MKV 等本地文件，并通过 GPU CRT-Lottes shader 提供扫描线、
轻微荧光溢出和荫罩效果，不做音视频转码。

## 功能

- MKV、Opus、FLAC、ASS 等格式由 libmpv 直接解码
- 自动加载内嵌及同目录字幕
- 居中裁切竖屏封装视频的上下黑边，以 4:3 显示
- 无屏幕弯曲的柔和 CRT-Lottes 效果
- 拖放视频、进度控制、音量控制及原生 macOS 文件选择器
- 默认音量 100%

## 快捷键

- `⌘O`：打开影片
- `Space`：播放 / 暂停
- `←` / `→`：后退 / 前进 10 秒
- `↑` / `↓`：音量增加 / 减少 5%

## 环境要求

- Apple Silicon Mac
- macOS 26
- Xcode 26
- Homebrew 安装的 mpv / libmpv

```bash
brew install mpv
```

## 运行

当前本机测试版需要 macOS 26，以及完整安装的 Xcode 26。

```bash
swift run RetroPlayer
```

也可以在 Xcode 中打开 `Package.swift`，选择 `RetroPlayer` scheme 后运行。

如果 `xcode-select -p` 仍指向 Command Line Tools，请在 Xcode 设置中选择完整
Xcode 工具链，或运行：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 打包

```bash
zsh scripts/package_app.sh
```

应用会生成在 `outputs/RetroPlayer.app`。脚本使用 ad-hoc 本地签名，适合开发
测试；公开分发仍需 Apple Developer ID 签名与公证。

## 开源许可

RetroPlayer 自有代码使用 [MIT License](LICENSE)。第三方组件说明见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
