import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: VideoPlayerModel
    @State private var isTargeted = false
    @State private var showControls = true
    @State private var controlsHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black

            MPVVideoView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !model.hasMedia {
                emptyState
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        revealControls()
                        model.togglePlayback()
                    }
            }

            if isTargeted {
                Rectangle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }

            if let message = model.shaderStatusMessage {
                VStack {
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.82), in: Capsule())
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.top, 36)
                .allowsHitTesting(false)
            }

            if showControls {
                VStack {
                    Spacer()
                    controls
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowAspectRatioSetter(aspectRatio: model.videoAspectRatio))
        .background(WindowButtonsVisibilitySetter(isVisible: showControls || !model.hasMedia))
        .background(WindowCloseTerminator())
        .background(MouseActivityMonitor { revealControls() })
        .background(OriginalPreviewKeyMonitor { model.setOriginalPreview($0) })
        .background(
            KeyboardEventMonitor { keyCode in
                switch keyCode {
                case 49: model.togglePlayback()       // Space
                case 123: model.skip(seconds: -10)    // Left arrow
                case 124: model.skip(seconds: 10)     // Right arrow
                case 125: model.adjustVolume(by: -0.05) // Down arrow
                case 126: model.adjustVolume(by: 0.05)  // Up arrow
                default: return false
                }
                return true
            }
        )
        .preferredColorScheme(.dark)
        .onChange(of: model.hasMedia) { _, hasMedia in
            if hasMedia {
                revealControls()
            } else {
                controlsHideTask?.cancel()
                setWindowButtonsVisible(true)
                withAnimation(.easeOut(duration: 0.15)) { showControls = true }
            }
        }
        .onDisappear { controlsHideTask?.cancel() }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else { url = item as? URL }
                if let url { Task { @MainActor in model.handleDrop(url) } }
            }
            return true
        }
    }

    private func revealControls() {
        controlsHideTask?.cancel()
        setWindowButtonsVisible(true)
        if !showControls {
            withAnimation(.easeOut(duration: 0.15)) { showControls = true }
        }
        scheduleControlsHide()
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        guard model.hasMedia else {
            showControls = true
            return
        }

        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, model.hasMedia else { return }
            setWindowButtonsVisible(false)
            withAnimation(.easeOut(duration: 0.2)) { showControls = false }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Button(action: model.openMovie) {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 34, weight: .thin))
                    Text("拖入视频")
                        .font(.system(size: 15, weight: .semibold))
                    Text("自动贴合视频比例，无额外黑边")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .foregroundStyle(.white.opacity(0.76))
            }
            .buttonStyle(.plain)

            if !model.recentItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近播放")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.38))
                    ForEach(model.recentItems.prefix(3)) { item in
                        Button {
                            model.openRecent(item)
                        } label: {
                            HStack {
                                Text(item.title).lineLimit(1)
                                Spacer()
                                if item.progress > 0 {
                                    Text(VideoPlayerModel.timecode(item.progress))
                                        .font(.system(size: 9, design: .monospaced))
                                }
                            }
                            .frame(width: 260)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.62))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(model.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text("\(VideoPlayerModel.timecode(model.currentTime)) / \(VideoPlayerModel.timecode(model.duration))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Slider(
                value: Binding(get: { model.currentTime }, set: { model.seek(to: $0) }),
                in: 0...max(model.duration, 0.01)
            )
            .controlSize(.small)
            .tint(.white)

            HStack(spacing: 8) {
                iconButton("gobackward.10") { model.skip(seconds: -10) }
                iconButton(model.isPlaying ? "pause.fill" : "play.fill", prominent: true) { model.togglePlayback() }
                iconButton("goforward.10") { model.skip(seconds: 10) }

                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            model.setPlaybackRate(rate)
                        } label: {
                            if abs(model.playbackRate - rate) < 0.001 {
                                Label(String(format: "%.2g×", rate), systemImage: "checkmark")
                            } else {
                                Text(String(format: "%.2g×", rate))
                            }
                        }
                    }
                } label: {
                    Text(String(format: "%.2g×", model.playbackRate))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Menu {
                    if model.audioTracks.isEmpty {
                        Text("没有可用音轨")
                    } else {
                        ForEach(model.audioTracks) { track in
                            Button {
                                model.selectAudioTrack(track.id)
                            } label: {
                                if model.selectedAudioID == track.id {
                                    Label(track.displayName, systemImage: "checkmark")
                                } else {
                                    Text(track.displayName)
                                }
                            }
                        }
                    }
                    Divider()
                    Text(String(format: "音频延迟 %+.1f 秒", model.audioDelay))
                    Button("音频提前 0.1 秒") { model.adjustAudioDelay(by: -0.1) }
                    Button("音频延后 0.1 秒") { model.adjustAudioDelay(by: 0.1) }
                    Button("重置音频延迟") { model.audioDelay = 0 }
                } label: {
                    Label("音轨", systemImage: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .help(model.audioTrackDisplayName)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Menu {
                    Button {
                        model.selectSubtitleTrack(nil)
                    } label: {
                        if model.selectedSubtitleID == nil {
                            Label("关闭字幕", systemImage: "checkmark")
                        } else {
                            Text("关闭字幕")
                        }
                    }
                    if !model.subtitleTracks.isEmpty {
                        Divider()
                        ForEach(model.subtitleTracks) { track in
                            Button {
                                model.selectSubtitleTrack(track.id)
                            } label: {
                                if model.selectedSubtitleID == track.id {
                                    Label(track.displayName, systemImage: "checkmark")
                                } else {
                                    Text(track.displayName)
                                }
                            }
                        }
                    }
                    Divider()
                    Menu("字幕字体") {
                        ForEach(["Songti SC", "STKaiti", "Hiragino Sans GB", "PingFang SC", "Arial"], id: \.self) { font in
                            Button(model.subtitleFont == font ? "✓ \(font)" : font) {
                                model.subtitleFont = font
                            }
                        }
                    }
                    Menu("字幕大小 · \(Int(model.subtitleSize))") {
                        ForEach([28.0, 34.0, 40.0, 46.0, 54.0, 64.0], id: \.self) { size in
                            Button(model.subtitleSize == size ? "✓ \(Int(size))" : "\(Int(size))") {
                                model.subtitleSize = size
                            }
                        }
                    }
                    Menu("字幕位置 · \(Int(model.subtitlePosition))%") {
                        ForEach([70.0, 78.0, 86.0, 92.0, 96.0], id: \.self) { position in
                            Button(model.subtitlePosition == position ? "✓ \(Int(position))%" : "\(Int(position))%") {
                                model.subtitlePosition = position
                            }
                        }
                    }
                    Menu(String(format: "描边 · %.1f", model.subtitleOutline)) {
                        ForEach([0.0, 1.0, 2.2, 3.0, 4.0], id: \.self) { outline in
                            Button(model.subtitleOutline == outline ? "✓ \(outline, specifier: "%.1f")" : "\(outline, specifier: "%.1f")") {
                                model.subtitleOutline = outline
                            }
                        }
                    }
                    Divider()
                    Text(String(format: "字幕延迟 %+.1f 秒", model.subtitleDelay))
                    Button("字幕提前 0.1 秒") { model.adjustSubtitleDelay(by: -0.1) }
                    Button("字幕延后 0.1 秒") { model.adjustSubtitleDelay(by: 0.1) }
                    Button("重置字幕延迟") { model.subtitleDelay = 0 }
                } label: {
                    Label("字幕", systemImage: model.selectedSubtitleID == nil ? "captions.bubble" : "captions.bubble.fill")
                        .font(.system(size: 12, weight: .medium))
                        .help(model.subtitleTrackDisplayName)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Menu {
                    Section("内置效果") {
                        ForEach(VideoPlayerModel.ShaderPreset.builtInPresets) { preset in
                            Button {
                                model.selectShader(preset)
                            } label: {
                                if model.selectedShader == preset {
                                    Label(preset.name, systemImage: "checkmark")
                                } else {
                                    Text(preset.name)
                                }
                            }
                        }
                    }
                    Section("社区开源") {
                        ForEach(VideoPlayerModel.ShaderPreset.communityPresets) { preset in
                            Button {
                                model.selectShader(preset)
                            } label: {
                                if model.selectedShader == preset {
                                    Label(preset.name, systemImage: "checkmark")
                                } else {
                                    Text(preset.name)
                                }
                            }
                        }
                    }
                    Section("Sony CRT 风格") {
                        ForEach(VideoPlayerModel.ShaderPreset.sonyPresets) { preset in
                            Button {
                                model.selectShader(preset)
                            } label: {
                                if model.selectedShader == preset {
                                    Label(preset.name, systemImage: "checkmark")
                                } else {
                                    Text(preset.name)
                                }
                            }
                        }
                    }
                    Divider()
                    Menu("效果强度 · \(Int(model.shaderStrength * 100))%") {
                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { strength in
                            Button(model.shaderStrength == strength ? "✓ \(Int(strength * 100))%" : "\(Int(strength * 100))%") {
                                model.shaderStrength = strength
                            }
                        }
                    }
                    Button("导入 mpv Shader…") { model.importShader() }
                } label: {
                    Label(model.shaderDisplayName, systemImage: "sparkles.tv")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in model.setOriginalPreview(true) }
                            .onEnded { _ in model.setOriginalPreview(false) }
                    )
                    .help("按住查看原画（也可按住 Tab）")

                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.white.opacity(0.65))
                Slider(value: $model.volume, in: 0...1)
                    .frame(width: 90)
                    .controlSize(.small)
                    .tint(.white)

                Menu {
                    Toggle("自动播放下一集", isOn: $model.autoPlayNext)
                    if !model.recentItems.isEmpty {
                        Divider()
                        ForEach(model.recentItems) { item in
                            Button(item.progress > 0 ? "\(item.title) · \(VideoPlayerModel.timecode(item.progress))" : item.title) {
                                model.openRecent(item)
                            }
                        }
                        Divider()
                        Button("清除最近播放记录") { model.clearRecentItems() }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                iconButton("folder") { model.openMovie() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color.black.opacity(0.78))
    }

    private func iconButton(_ symbol: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 30)
                .background(prominent ? Color.white : Color.white.opacity(0.10))
                .foregroundStyle(prominent ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}

private struct MouseActivityMonitor: NSViewRepresentable {
    let handler: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(handler: handler) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: events) { event in
            context.coordinator.handler()
            return event
        }
        DispatchQueue.main.async { view.window?.acceptsMouseMovedEvents = true }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.handler = handler
        view.window?.acceptsMouseMovedEvents = true
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }

    final class Coordinator {
        var handler: () -> Void
        var monitor: Any?

        init(handler: @escaping () -> Void) {
            self.handler = handler
        }
    }
}

private struct OriginalPreviewKeyMonitor: NSViewRepresentable {
    let handler: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(handler: handler) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            guard event.keyCode == 48,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
            else { return event }
            if !event.isARepeat { context.coordinator.handler(event.type == .keyDown) }
            return nil
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.handler = handler
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }

    final class Coordinator {
        var handler: (Bool) -> Void
        var monitor: Any?

        init(handler: @escaping (Bool) -> Void) {
            self.handler = handler
        }
    }
}

private struct WindowButtonsVisibilitySetter: NSViewRepresentable {
    let isVisible: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        updateButtons(for: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        updateButtons(for: view)
    }

    private func updateButtons(for view: NSView) {
        let shouldHide = !isVisible
        applyVisibility(to: view.window, shouldHide: shouldHide)
        DispatchQueue.main.async {
            applyVisibility(to: view.window, shouldHide: shouldHide)
        }
    }

    private func applyVisibility(to window: NSWindow?, shouldHide: Bool) {
        setWindowButtonsVisible(!shouldHide, in: window)
    }
}

@MainActor
private func setWindowButtonsVisible(_ visible: Bool, in targetWindow: NSWindow? = nil) {
    guard let window = targetWindow ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow else { return }
    let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    let buttons = types.compactMap { window.standardWindowButton($0) }

    for button in buttons {
        button.alphaValue = visible ? 1 : 0
        button.isEnabled = visible
        button.isHidden = !visible
    }

    if let container = buttons.first?.superview {
        container.alphaValue = visible ? 1 : 0
        container.isHidden = !visible
    }
}

private struct WindowCloseTerminator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.observe(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.observe(window: view.window)
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observer: NSObjectProtocol?

        func observe(window newWindow: NSWindow?) {
            guard let newWindow, newWindow !== window else { return }
            stopObserving()
            window = newWindow
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: newWindow,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    NSApplication.shared.terminate(nil)
                }
            }
        }

        func stopObserving() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            window = nil
        }

        deinit { stopObserving() }
    }
}

private struct KeyboardEventMonitor: NSViewRepresentable {
    let handler: (UInt16) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(handler: handler) }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !modifiers.contains(.command),
                  !modifiers.contains(.control),
                  !modifiers.contains(.option),
                  context.coordinator.handler(event.keyCode)
            else { return event }
            return nil
        }
        return NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.handler = handler
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }

    final class Coordinator {
        var handler: (UInt16) -> Bool
        var monitor: Any?

        init(handler: @escaping (UInt16) -> Bool) {
            self.handler = handler
        }
    }
}

private struct WindowAspectRatioSetter: NSViewRepresentable {
    let aspectRatio: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyAspectRatio(to: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            applyAspectRatio(to: view.window, coordinator: context.coordinator)
        }
    }

    private func applyAspectRatio(to window: NSWindow?, coordinator: Coordinator) {
        guard aspectRatio.isFinite, aspectRatio > 0,
              let window,
              abs(coordinator.lastAspectRatio - aspectRatio) > 0.001
        else { return }

        coordinator.lastAspectRatio = aspectRatio
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1)

        let currentSize = window.contentView?.bounds.size ?? window.contentLayoutRect.size
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let maximumWidth = max(480, (visibleFrame?.width ?? 1200) - 48)
        let frameInset = max(0, window.frame.height - currentSize.height)
        let maximumHeight = max(270, (visibleFrame?.height ?? 900) - frameInset - 48)

        var width = min(max(currentSize.width, 480), maximumWidth)
        var height = width / aspectRatio
        if height > maximumHeight {
            height = maximumHeight
            width = height * aspectRatio
        }

        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.setContentSize(NSSize(width: width, height: height))
        window.setFrameTopLeftPoint(topLeft)
    }

    final class Coordinator {
        var lastAspectRatio = 0.0
    }
}
