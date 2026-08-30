import AppKit
import CMPVBridge
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VideoPlayerModel: ObservableObject {
    nonisolated(unsafe) let context: OpaquePointer?

    @Published var isPlaying = false
    @Published var hasMedia = false
    @Published var currentTime = 0.0
    @Published var duration = 0.0
    @Published var title = "等待信号"
    @Published var volume = 1.0 { didSet { rx_mpv_set_volume(context, volume) } }

    private nonisolated(unsafe) var timer: Timer?

    init() {
        let shaderPath = Bundle.main.resourceURL?.appendingPathComponent("CRT.glsl").path
        context = shaderPath?.withCString { rx_mpv_create($0) } ?? rx_mpv_create(nil)
        rx_mpv_set_volume(context, volume)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                rx_mpv_poll_events(self.context)
                self.currentTime = rx_mpv_get_time(self.context)
                self.duration = rx_mpv_get_duration(self.context)
                self.isPlaying = self.hasMedia && !rx_mpv_get_pause(self.context)
            }
        }
    }

    deinit {
        timer?.invalidate()
        rx_mpv_destroy(context)
    }

    func openMovie() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .audiovisualContent, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择本地视频，文件会直接播放，不做转换"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    func load(_ url: URL) {
        guard let context else { title = "播放内核不可用"; return }
        let result = url.path.withCString { rx_mpv_load(context, $0) }
        guard result >= 0 else { title = "无法打开影片"; return }
        title = url.deletingPathExtension().lastPathComponent
        hasMedia = true
        rx_mpv_set_pause(context, false)
        isPlaying = true
    }

    func togglePlayback() {
        guard hasMedia else { openMovie(); return }
        let paused = !rx_mpv_get_pause(context)
        rx_mpv_set_pause(context, paused)
        isPlaying = !paused
    }

    func seek(to seconds: Double) { rx_mpv_seek(context, seconds) }
    func skip(seconds: Double) { seek(to: min(max(0, currentTime + seconds), duration)) }
    func adjustVolume(by amount: Double) {
        volume = min(max(0, volume + amount), 1)
    }

    static func timecode(_ value: Double) -> String {
        guard value.isFinite else { return "00:00" }
        let seconds = Int(value.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
