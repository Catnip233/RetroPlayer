import SwiftUI

@main
struct RetroPlayerApp: App {
    @StateObject private var player = VideoPlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .frame(minWidth: 640, minHeight: 480)
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
        }
    }
}
