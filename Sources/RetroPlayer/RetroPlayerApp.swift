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
