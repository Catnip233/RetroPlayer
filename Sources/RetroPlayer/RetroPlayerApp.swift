import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct RetroPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var player = VideoPlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .frame(minWidth: 480, minHeight: 270)
        }
        .defaultSize(width: 960, height: 720)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开影片…") { player.openMovie() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("播放") {
                Button(player.isPlaying ? "暂停" : "播放") { player.togglePlayback() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("后退 10 秒") { player.skip(seconds: -10) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("前进 10 秒") { player.skip(seconds: 10) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Divider()
                Menu("播放速度") {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button(player.playbackRate == rate ? "✓ \(rate, specifier: "%.2g")×" : "\(rate, specifier: "%.2g")×") {
                            player.setPlaybackRate(rate)
                        }
                    }
                }
                Toggle("自动播放下一集", isOn: $player.autoPlayNext)
                Divider()
                Button("字幕提前 0.1 秒") { player.adjustSubtitleDelay(by: -0.1) }
                Button("字幕延后 0.1 秒") { player.adjustSubtitleDelay(by: 0.1) }
                Button("音频提前 0.1 秒") { player.adjustAudioDelay(by: -0.1) }
                Button("音频延后 0.1 秒") { player.adjustAudioDelay(by: 0.1) }
                Button("重置音画延迟") { player.resetDelays() }
                Divider()
                Text("按住 Tab 临时查看原画")
            }
            CommandMenu("画面效果") {
                ForEach(VideoPlayerModel.ShaderPreset.builtInPresets) { preset in
                    Button(player.selectedShader == preset ? "✓ \(preset.name)" : preset.name) {
                        player.selectShader(preset)
                    }
                }
                Divider()
                ForEach(VideoPlayerModel.ShaderPreset.communityPresets) { preset in
                    Button(player.selectedShader == preset ? "✓ \(preset.name)" : preset.name) {
                        player.selectShader(preset)
                    }
                }
                Divider()
                ForEach(VideoPlayerModel.ShaderPreset.sonyPresets) { preset in
                    Button(player.selectedShader == preset ? "✓ \(preset.name)" : preset.name) {
                        player.selectShader(preset)
                    }
                }
                Divider()
                Button("导入 mpv Shader…") { player.importShader() }
            }
        }
    }
}
