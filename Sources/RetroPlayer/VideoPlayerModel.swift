import AppKit
import CMPVBridge
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VideoPlayerModel: ObservableObject {
    struct RecentItem: Codable, Identifiable, Equatable {
        let path: String
        var title: String
        var lastOpened: Date
        var progress: Double

        var id: String { path }
        var url: URL { URL(fileURLWithPath: path) }
    }

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
    @Published var playbackRate = 1.0 { didSet { setDoubleProperty("speed", playbackRate) } }
    @Published var subtitleFont = "Songti SC" { didSet { setStringProperty("sub-font", subtitleFont); savePreferences() } }
    @Published var subtitleSize = 40.0 { didSet { setDoubleProperty("sub-font-size", subtitleSize); savePreferences() } }
    @Published var subtitlePosition = 92.0 { didSet { setDoubleProperty("sub-pos", subtitlePosition); savePreferences() } }
    @Published var subtitleOutline = 2.2 { didSet { setDoubleProperty("sub-outline-size", subtitleOutline); savePreferences() } }
    @Published var subtitleDelay = 0.0 { didSet { setDoubleProperty("sub-delay", subtitleDelay) } }
    @Published var audioDelay = 0.0 { didSet { setDoubleProperty("audio-delay", audioDelay) } }
    @Published var shaderStrength = 1.0 { didSet { applyShaderStrength(); savePreferences() } }
    @Published var autoPlayNext = true { didSet { savePreferences() } }
    @Published private(set) var selectedShader: ShaderPreset
    @Published private(set) var customShaderName: String?
    @Published private(set) var recentItems: [RecentItem] = []
    @Published private(set) var shaderStatusMessage: String?
    @Published private(set) var audioTracks: [MediaTrack] = []
    @Published private(set) var subtitleTracks: [MediaTrack] = []
    @Published private(set) var selectedAudioID: Int64?
    @Published private(set) var selectedSubtitleID: Int64?

    private nonisolated(unsafe) var timer: Timer?
    private var trackRevision: UInt64 = 0
    private var currentURL: URL?
    private var pendingResumeTime: Double?
    private var progressByPath: [String: Double] = [:]
    private var lastProgressSave = Date.distantPast
    private var previewingOriginal = false
    private var shaderFallback: (preset: ShaderPreset, path: String?)?
    private var shaderValidationDeadline = Date.distantPast
    private var shaderMessageDeadline = Date.distantPast
    private var handledEndOfFile = false

    private static let shaderPreferenceKey = "selectedShaderPreset"
    private static let customShaderPathKey = "customShaderPath"
    private static let recentItemsKey = "recentItems"
    private static let progressKey = "playbackProgress"
    private static let subtitleFontKey = "subtitleFont"
    private static let subtitleSizeKey = "subtitleSize"
    private static let subtitlePositionKey = "subtitlePosition"
    private static let subtitleOutlineKey = "subtitleOutline"
    private static let shaderStrengthKey = "shaderStrength"
    private static let autoPlayNextKey = "autoPlayNext"
    private static let videoExtensions: Set<String> = [
        "mkv", "mp4", "mov", "m4v", "avi", "webm", "ts", "m2ts", "flv", "wmv"
    ]
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
        subtitleFont = defaults.string(forKey: Self.subtitleFontKey) ?? "Songti SC"
        subtitleSize = defaults.object(forKey: Self.subtitleSizeKey) as? Double ?? 40
        subtitlePosition = defaults.object(forKey: Self.subtitlePositionKey) as? Double ?? 92
        subtitleOutline = defaults.object(forKey: Self.subtitleOutlineKey) as? Double ?? 2.2
        shaderStrength = defaults.object(forKey: Self.shaderStrengthKey) as? Double ?? 1
        autoPlayNext = defaults.object(forKey: Self.autoPlayNextKey) as? Bool ?? true
        if let data = defaults.data(forKey: Self.recentItemsKey),
           let items = try? JSONDecoder().decode([RecentItem].self, from: data) {
            recentItems = items.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        if let data = defaults.data(forKey: Self.progressKey),
           let progress = try? JSONDecoder().decode([String: Double].self, from: data) {
            progressByPath = progress
        }
        let shaderPath = Self.shaderPath(for: savedPreset, customPath: customPath)
        context = rx_mpv_create(nil)
        rx_mpv_set_volume(context, volume)
        applyPlaybackPreferences()
        _ = setShaderPipeline(path: shaderPath)
        applyShaderStrength()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let events = rx_mpv_poll_events(self.context)
                if events & UInt32(RX_MPV_EVENT_FILE_LOADED) != 0 { self.handleFileLoaded() }
                if events & UInt32(RX_MPV_EVENT_END_FILE) != 0 { self.handleEndOfFile() }
                if events & UInt32(RX_MPV_EVENT_PLAYBACK_ERROR) != 0 { self.title = "视频播放失败" }
                if events & UInt32(RX_MPV_EVENT_SHADER_ERROR) != 0 { self.handleShaderFailure() }
                if self.shaderFallback != nil, Date() > self.shaderValidationDeadline {
                    self.shaderFallback = nil
                }
                if self.shaderStatusMessage != nil, Date() > self.shaderMessageDeadline {
                    self.shaderStatusMessage = nil
                }
                let revision = rx_mpv_get_track_revision(self.context)
                if revision != self.trackRevision {
                    self.trackRevision = revision
                    self.refreshTracks()
                }
                self.currentTime = rx_mpv_get_time(self.context)
                self.duration = rx_mpv_get_duration(self.context)
                if self.hasMedia, rx_mpv_get_eof_reached(self.context) {
                    self.handleEndOfFile()
                }
                let aspect = rx_mpv_get_video_aspect(self.context)
                if self.hasMedia, aspect.isFinite, aspect >= 0.2, aspect <= 5.0,
                   abs(aspect - self.videoAspectRatio) > 0.001 {
                    self.videoAspectRatio = aspect
                }
                self.isPlaying = self.hasMedia && !rx_mpv_get_pause(self.context)
                if Date().timeIntervalSince(self.lastProgressSave) >= 5 {
                    self.saveCurrentProgress()
                }
            }
        }
    }

    deinit {
        MainActor.assumeIsolated { saveCurrentProgress() }
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
        saveCurrentProgress()
        let normalizedURL = url.standardizedFileURL
        let result = normalizedURL.path.withCString { rx_mpv_load(context, $0) }
        guard result >= 0 else { title = "无法打开影片"; return }
        currentURL = normalizedURL
        handledEndOfFile = false
        pendingResumeTime = progressByPath[normalizedURL.path]
        title = normalizedURL.deletingPathExtension().lastPathComponent
        hasMedia = true
        audioTracks = []
        subtitleTracks = []
        selectedAudioID = nil
        selectedSubtitleID = nil
        rx_mpv_set_pause(context, false)
        isPlaying = true
        addRecentItem(normalizedURL)
    }

    func openRecent(_ item: RecentItem) {
        guard FileManager.default.fileExists(atPath: item.path) else {
            recentItems.removeAll { $0.id == item.id }
            saveHistory()
            return
        }
        load(item.url)
    }

    func clearRecentItems() {
        recentItems = []
        saveHistory()
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

    func setPlaybackRate(_ rate: Double) {
        playbackRate = min(max(rate, 0.25), 4)
    }

    func adjustSubtitleDelay(by amount: Double) {
        subtitleDelay = min(max(subtitleDelay + amount, -30), 30)
    }

    func adjustAudioDelay(by amount: Double) {
        audioDelay = min(max(audioDelay + amount, -30), 30)
    }

    func resetDelays() {
        subtitleDelay = 0
        audioDelay = 0
    }

    func setOriginalPreview(_ active: Bool) {
        guard active != previewingOriginal else { return }
        previewingOriginal = active
        if active {
            _ = rx_mpv_set_shader(context, nil)
        } else {
            let customPath = UserDefaults.standard.string(forKey: Self.customShaderPathKey)
            _ = setShaderPipeline(path: Self.shaderPath(for: selectedShader, customPath: customPath))
            applyShaderStrength()
        }
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
        let customPath = UserDefaults.standard.string(forKey: Self.customShaderPathKey)
        let oldPath = Self.shaderPath(for: selectedShader, customPath: customPath)
        shaderFallback = (selectedShader, oldPath)
        let result = setShaderPipeline(path: path)
        guard result >= 0 else {
            handleShaderFailure()
            return
        }
        selectedShader = preset
        shaderStatusMessage = nil
        shaderValidationDeadline = Date().addingTimeInterval(3)
        applyShaderStrength()
        UserDefaults.standard.set(preset.rawValue, forKey: Self.shaderPreferenceKey)
    }

    private func handleFileLoaded() {
        applyPlaybackPreferences()
        if let resume = pendingResumeTime, resume >= 3 {
            let knownDuration = rx_mpv_get_duration(context)
            if knownDuration <= 0 || resume < knownDuration - 15 {
                rx_mpv_seek(context, resume)
            }
        }
        pendingResumeTime = nil
    }

    private func handleEndOfFile() {
        guard !handledEndOfFile, let finishedURL = currentURL else { return }
        handledEndOfFile = true
        progressByPath.removeValue(forKey: finishedURL.path)
        updateRecentProgress(path: finishedURL.path, progress: 0)
        persistProgress()

        if autoPlayNext, let nextURL = nextVideo(after: finishedURL) {
            load(nextURL)
        } else {
            rx_mpv_set_pause(context, true)
            isPlaying = false
        }
    }

    private func nextVideo(after url: URL) -> URL? {
        let directory = url.deletingLastPathComponent()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let videos = files
            .filter { Self.videoExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard let index = videos.firstIndex(where: { $0.standardizedFileURL == url.standardizedFileURL }),
              videos.indices.contains(index + 1)
        else { return nil }
        return videos[index + 1]
    }

    private func saveCurrentProgress() {
        lastProgressSave = Date()
        guard let url = currentURL, hasMedia, currentTime.isFinite, currentTime >= 1 else { return }
        let value = duration > 0 && currentTime >= duration - 10 ? 0 : currentTime
        if value > 0 { progressByPath[url.path] = value }
        else { progressByPath.removeValue(forKey: url.path) }
        updateRecentProgress(path: url.path, progress: value)
        persistProgress()
    }

    private func addRecentItem(_ url: URL) {
        recentItems.removeAll { $0.path == url.path }
        recentItems.insert(
            RecentItem(
                path: url.path,
                title: url.deletingPathExtension().lastPathComponent,
                lastOpened: Date(),
                progress: progressByPath[url.path] ?? 0
            ),
            at: 0
        )
        if recentItems.count > 15 { recentItems.removeLast(recentItems.count - 15) }
        saveHistory()
    }

    private func updateRecentProgress(path: String, progress: Double) {
        guard let index = recentItems.firstIndex(where: { $0.path == path }) else { return }
        recentItems[index].progress = progress
        saveHistory()
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(recentItems) else { return }
        UserDefaults.standard.set(data, forKey: Self.recentItemsKey)
    }

    private func persistProgress() {
        guard let data = try? JSONEncoder().encode(progressByPath) else { return }
        UserDefaults.standard.set(data, forKey: Self.progressKey)
    }

    private func applyPlaybackPreferences() {
        setDoubleProperty("speed", playbackRate)
        setStringProperty("sub-font", subtitleFont)
        setDoubleProperty("sub-font-size", subtitleSize)
        setDoubleProperty("sub-pos", subtitlePosition)
        setDoubleProperty("sub-outline-size", subtitleOutline)
        setDoubleProperty("sub-delay", subtitleDelay)
        setDoubleProperty("audio-delay", audioDelay)
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(subtitleFont, forKey: Self.subtitleFontKey)
        defaults.set(subtitleSize, forKey: Self.subtitleSizeKey)
        defaults.set(subtitlePosition, forKey: Self.subtitlePositionKey)
        defaults.set(subtitleOutline, forKey: Self.subtitleOutlineKey)
        defaults.set(shaderStrength, forKey: Self.shaderStrengthKey)
        defaults.set(autoPlayNext, forKey: Self.autoPlayNextKey)
    }

    private func setDoubleProperty(_ name: String, _ value: Double) {
        name.withCString { property in
            _ = rx_mpv_set_double_property(context, property, value)
        }
    }

    private func setStringProperty(_ name: String, _ value: String) {
        name.withCString { property in
            value.withCString { stringValue in
                _ = rx_mpv_set_string_property(context, property, stringValue)
            }
        }
    }

    private func setShaderPipeline(path: String?) -> Int32 {
        guard let path else { return rx_mpv_set_shader(context, nil) }
        guard let capture = Bundle.main.url(forResource: "RetroPlayer-Capture", withExtension: "glsl")?.path
                ?? Bundle.main.resourceURL?.appendingPathComponent("RetroPlayer-Capture.glsl").path,
              let blend = Bundle.main.url(forResource: "RetroPlayer-Blend", withExtension: "glsl")?.path
                ?? Bundle.main.resourceURL?.appendingPathComponent("RetroPlayer-Blend.glsl").path
        else {
            return path.withCString { rx_mpv_set_shader(context, $0) }
        }
        return capture.withCString { capturePath in
            path.withCString { shaderPath in
                blend.withCString { blendPath in
                    rx_mpv_set_shader_pipeline(context, capturePath, shaderPath, blendPath)
                }
            }
        }
    }

    private func applyShaderStrength() {
        let options = String(format: "retroplayer_strength=%.3f", min(max(shaderStrength, 0), 1))
        options.withCString { rx_mpv_set_shader_options(context, $0) }
    }

    private func handleShaderFailure() {
        guard Date() <= shaderValidationDeadline || shaderFallback != nil else { return }
        let fallback = shaderFallback ?? (.off, nil)
        shaderFallback = nil
        shaderValidationDeadline = .distantPast
        _ = setShaderPipeline(path: fallback.path)
        selectedShader = fallback.preset
        UserDefaults.standard.set(fallback.preset.rawValue, forKey: Self.shaderPreferenceKey)
        shaderStatusMessage = "Shader 加载失败，已自动恢复为 \(fallback.preset.name)"
        shaderMessageDeadline = Date().addingTimeInterval(5)
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
