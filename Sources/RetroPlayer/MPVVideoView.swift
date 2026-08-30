import AppKit
import CMPVBridge
import OpenGL.GL3
import SwiftUI

struct MPVVideoView: NSViewRepresentable {
    @ObservedObject var model: VideoPlayerModel

    func makeNSView(context: Context) -> MPVOpenGLView {
        MPVOpenGLView(player: model.context)
    }

    func updateNSView(_ view: MPVOpenGLView, context: Context) {
        view.needsDisplay = true
    }
}

final class MPVOpenGLView: NSOpenGLView {
    private let player: OpaquePointer?
    private var displayTimer: Timer?

    init(player: OpaquePointer?) {
        self.player = player
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAColorSize), 24,
            UInt32(NSOpenGLPFAAlphaSize), 8,
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            0
        ]
        let format = NSOpenGLPixelFormat(attributes: attributes)!
        super.init(frame: .zero, pixelFormat: format)!
        wantsBestResolutionOpenGLSurface = true
    }

    required init?(coder: NSCoder) { nil }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()
        var interval: GLint = 1
        openGLContext?.setValues(&interval, for: .swapInterval)
        _ = rx_mpv_initialize_gl(player)
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.needsDisplay = true }
        }
        if let displayTimer { RunLoop.main.add(displayTimer, forMode: .common) }
    }

    override func reshape() {
        super.reshape()
        openGLContext?.update()
    }

    override func draw(_ dirtyRect: NSRect) {
        openGLContext?.makeCurrentContext()
        let size = convertToBacking(bounds).size
        glClearColor(0.003, 0.003, 0.003, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        rx_mpv_render(player, 0, Int32(size.width), Int32(size.height))
        openGLContext?.flushBuffer()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            displayTimer?.invalidate()
            displayTimer = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }
}
