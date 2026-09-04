import AppKit
import CMPVBridge
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VideoPlayerModel: ObservableObject {
    struct MediaTrack: Identifiable, Equatable {
        enum Kind { case audio, subtitle }

        let id: Int64
        let kind: Kind
        let title: String?
        let language: String?
        let codec: String?

        var displayName: String {
            let fallback = kind == .audio ? "音轨 \(id)" : "字幕 \(id)"
            let main = title ?? language?.uppercased() ?? fallback
            let details = [title == nil ? nil : language?.uppercased(), codec?.uppercased()]
                .compactMap { $0 }
            return details.isEmpty ? main : "\(main) · \(details.joined(separator: " · "))"
        }
    }

    enum ShaderPreset: String, CaseIterable, Identifiable {
        case off
        case crtSoft
        case crtStrong
        case arcade
        case vhs
        case monochrome
        case communityLottes
        case communityAnime4K
        case communityGBA
        case sonyPVM20L4
        case sonyPVM2730
        case sonyBVMKurozumi
        case custom

        var id: String { rawValue }

        static let builtInPresets: [ShaderPreset] = [
            .off, .crtSoft, .crtStrong, .arcade, .vhs, .monochrome
        ]

        static let communityPresets: [ShaderPreset] = [
            .communityLottes, .communityAnime4K, .communityGBA
        ]

        static let sonyPresets: [ShaderPreset] = [
            .sonyPVM20L4, .sonyPVM2730, .sonyBVMKurozumi
        ]

        var name: String {
            switch self {
            case .off: "关闭效果"
            case .crtSoft: "柔和 CRT"
            case .crtStrong: "强扫描线"
            case .arcade: "街机彩罩"
            case .vhs: "VHS 磁带"
            case .monochrome: "黑白电视"
            case .communityLottes: "社区 · Lottes 原版"
            case .communityAnime4K: "社区 · Anime4K 修复"
            case .communityGBA: "社区 · GBA 色彩"
            case .sonyPVM20L4: "Sony 风格 · PVM 20L4"
            case .sonyPVM2730: "Sony 风格 · PVM 2730"
            case .sonyBVMKurozumi: "Sony 风格 · Kurozumi BVM"
            case .custom: "自定义 Shader"
            }
        }

        var resourceName: String? {
            switch self {
            case .off, .custom: nil
            case .crtSoft: "CRT-Soft"
            case .crtStrong: "CRT-Strong"
            case .arcade: "Arcade-Mask"
            case .vhs: "VHS"
            case .monochrome: "Monochrome-TV"
            case .communityLottes: "Community-Lottes"
            case .communityAnime4K: "Community-Anime4K-Restore"
            case .communityGBA: "Community-GBA"
            case .sonyPVM20L4: "Sony-PVM-20L4"
            case .sonyPVM2730: "Sony-PVM-2730"
            case .sonyBVMKurozumi: "Sony-BVM-Kurozumi"
            }
        }
    }

    nonisolated(unsafe) let context: OpaquePointer?

    @Published var isPlaying = false
    @Published var hasMedia = false
    @Published var currentTime = 0.0
    @Published var duration = 0.0
    @Published private(set) var videoAspectRatio = 4.0 / 3.0
    @Published var title = "等待信号"
    @Published var volume = 1.0 { didSet { rx_mpv_set_volume(context, volume) } }
    @Published private(set) var selectedShader: ShaderPreset
    @Published private(set) var customShaderName: String?
    @Published private(set) var audioTracks: [MediaTrack] = []
    @Published private(set) var subtitleTracks: [MediaTrack] = []
    @Published private(set) var selectedAudioID: Int64?
    @Published private(set) var selectedSubtitleID: Int64?

    private nonisolated(unsafe) var timer: Timer?
    private var trackRevision: UInt64 = 0

    private static let shaderPreferenceKey = "selectedShaderPreset"
    private static let customShaderPathKey = "customShaderPath"
    private static let subtitleExtensions: Set<String> = [
        "srt", "ass", "ssa", "vtt", "sub", "idx", "smi", "sami", "lrc"
    ]

    init() {
        let defaults = UserDefaults.standard
        let savedPreset = defaults.string(forKey: Self.shaderPreferenceKey)
            .flatMap(ShaderPreset.init(rawValue:)) ?? .crtSoft
        let customPath = defaults.string(forKey: Self.customShaderPathKey)
        selectedShader = savedPreset
        customShaderName = customPath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let shaderPath = Self.shaderPath(for: savedPreset, customPath: customPath)
        context = shaderPath?.withCString { rx_mpv_create($0) } ?? rx_mpv_create(nil)
        rx_mpv_set_volume(context, volume)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                rx_mpv_poll_events(self.context)
                let revision = rx_mpv_get_track_revision(self.context)
                if revision != self.trackRevision {
                    self.trackRevision = revision
                    self.refreshTracks()
                }
                self.currentTime = rx_mpv_get_time(self.context)
                self.duration = rx_mpv_get_duration(self.context)
                let aspect = rx_mpv_get_video_aspect(self.context)
                if self.hasMedia, aspect.isFinite, aspect >= 0.2, aspect <= 5.0,
                   abs(aspect - self.videoAspectRatio) > 0.001 {
                    self.videoAspectRatio = aspect
                }
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
        audioTracks = []
        subtitleTracks = []
        selectedAudioID = nil
        selectedSubtitleID = nil
        rx_mpv_set_pause(context, false)
        isPlaying = true
    }

    func handleDrop(_ url: URL) {
        if Self.subtitleExtensions.contains(url.pathExtension.lowercased()) {
            addSubtitle(url)
        } else {
            load(url)
        }
    }

    func addSubtitle(_ url: URL) {
        guard hasMedia else {
            title = "请先打开视频，再拖入字幕"
            return
        }
        let result = url.path.withCString { rx_mpv_add_subtitle(context, $0) }
        guard result >= 0 else {
            title = "无法加载字幕：\(url.lastPathComponent)"
            return
        }
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

    func selectAudioTrack(_ id: Int64) {
        guard rx_mpv_set_audio_track(context, id) >= 0 else { return }
        selectedAudioID = id
    }

    func selectSubtitleTrack(_ id: Int64?) {
        guard rx_mpv_set_subtitle_track(context, id ?? -1) >= 0 else { return }
        selectedSubtitleID = id
    }

    var audioTrackDisplayName: String {
        audioTracks.first(where: { $0.id == selectedAudioID })?.displayName ?? "音轨"
    }

    var subtitleTrackDisplayName: String {
        guard let selectedSubtitleID else { return "字幕关闭" }
        return subtitleTracks.first(where: { $0.id == selectedSubtitleID })?.displayName ?? "字幕"
    }

    func selectShader(_ preset: ShaderPreset) {
        if preset == .custom {
            importShader()
            return
        }
        applyShader(preset, path: Self.shaderPath(for: preset, customPath: nil))
    }

    func importShader() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "glsl") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择 mpv User Shader（.glsl）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.customShaderPathKey)
        customShaderName = url.lastPathComponent
        applyShader(.custom, path: url.path)
    }

    var shaderDisplayName: String {
        selectedShader == .custom ? (customShaderName ?? selectedShader.name) : selectedShader.name
    }

    private func applyShader(_ preset: ShaderPreset, path: String?) {
        let result = path?.withCString { rx_mpv_set_shader(context, $0) }
            ?? rx_mpv_set_shader(context, nil)
        guard result >= 0 else { return }
        selectedShader = preset
        UserDefaults.standard.set(preset.rawValue, forKey: Self.shaderPreferenceKey)
    }

    private func refreshTracks() {
        var audio: [MediaTrack] = []
        var subtitles: [MediaTrack] = []
        var activeAudio: Int64?
        var activeSubtitle: Int64?

        for index in 0..<rx_mpv_get_track_count(context) {
            let type = rx_mpv_get_track_type(context, index)
            guard type == 1 || type == 2 else { continue }
            let id = rx_mpv_get_track_id(context, index)
            guard id >= 0 else { continue }
            let kind: MediaTrack.Kind = type == 1 ? .audio : .subtitle
            let track = MediaTrack(
                id: id,
                kind: kind,
                title: trackString(index: index, field: "title"),
                language: trackString(index: index, field: "lang"),
                codec: trackString(index: index, field: "codec")
            )
            if kind == .audio { audio.append(track) } else { subtitles.append(track) }
            if rx_mpv_get_track_selected(context, index) {
                if kind == .audio { activeAudio = id } else { activeSubtitle = id }
            }
        }

        audioTracks = audio
        subtitleTracks = subtitles
        selectedAudioID = activeAudio
        selectedSubtitleID = activeSubtitle
    }

    private func trackString(index: Int64, field: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        let copied = field.withCString {
            rx_mpv_copy_track_string(context, index, $0, &buffer, buffer.count)
        }
        guard copied else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func shaderPath(for preset: ShaderPreset, customPath: String?) -> String? {
        if preset == .custom {
            guard let customPath, FileManager.default.fileExists(atPath: customPath) else { return nil }
            return customPath
        }
        guard let name = preset.resourceName else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "glsl")?.path
            ?? Bundle.main.resourceURL?.appendingPathComponent("\(name).glsl").path
    }

    static func timecode(_ value: Double) -> String {
        guard value.isFinite else { return "00:00" }
        let seconds = Int(value.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
