import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: VideoPlayerModel
    @State private var isTargeted = false
    @State private var showControls = true

    var body: some View {
        ZStack {
            Color.black

            MPVVideoView(model: model)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(Rectangle())

            if !model.hasMedia {
                emptyState
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.togglePlayback() }
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
        .background(WindowAspectRatioSetter())
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
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) { showControls = inside || !model.hasMedia }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else { url = item as? URL }
                if let url { Task { @MainActor in model.load(url) } }
            }
            return true
        }
    }

    private var emptyState: some View {
        Button(action: model.openMovie) {
            VStack(spacing: 10) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 34, weight: .thin))
                Text("拖入视频")
                    .font(.system(size: 15, weight: .semibold))
                Text("自动裁掉上下黑边，居中显示 4:3 画面")
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
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.contentAspectRatio = NSSize(width: 4, height: 3)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            view.window?.contentAspectRatio = NSSize(width: 4, height: 3)
        }
    }
}
