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
                    Button("导入 mpv Shader…") { model.importShader() }
                } label: {
                    Label(model.shaderDisplayName, systemImage: "sparkles.tv")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.white.opacity(0.65))
                Slider(value: $model.volume, in: 0...1)
                    .frame(width: 90)
                    .controlSize(.small)
                    .tint(.white)
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
