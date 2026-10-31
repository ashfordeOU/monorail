#if os(macOS)
import AVFoundation
import AppKit
import MonorailCore
import ScreenCaptureKit

/// A live copy of part of the screen (or one window) in a window of its own,
/// for sharing exactly one slide, mirroring a window to another display, or
/// zooming in during a demo. Uses ScreenCaptureKit; needs Screen Recording.
final class ScreenMirror: NSObject, SCStreamOutput, SCStreamDelegate {
    enum Source {
        /// A region of the display (accessibility coordinates, top-left origin).
        case region(CGRect)
        case window(WindowID)
        /// A box around the pointer, magnified.
        case pointer(zoom: CGFloat)
    }

    private var stream: SCStream?
    private let layer = AVSampleBufferDisplayLayer()
    private(set) var window: NSWindow?
    private var source: Source = .region(.zero)
    private var followTimer: Timer?
    private var display: SCDisplay?
    var onClose: () -> Void = {}

    var isRunning: Bool { stream != nil }

    /// Opens a window showing `source`. `title` names it for screen-share pickers.
    func start(_ source: Source, title: String, frame: NSRect, floating: Bool, excludeFromCapture: Bool = false) {
        stop()
        self.source = source
        let window = NSWindow(contentRect: frame, styleMask: floating ? [.borderless] : [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        if floating {
            window.level = .floating
            window.hasShadow = true
            window.ignoresMouseEvents = true
            window.isOpaque = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        if excludeFromCapture { window.sharingType = .none }
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        if floating {
            view.layer?.cornerRadius = 16
            view.layer?.masksToBounds = true
            view.layer?.borderWidth = 2
            view.layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        }
        window.contentView = view
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification,
                                               object: window)
        window.orderFrontRegardless()
        self.window = window
        Task { await self.startStream() }
    }

    @objc private func windowWillClose() {
        stop()
        onClose()
    }

    func stop() {
        followTimer?.invalidate()
        followTimer = nil
        if let stream { stream.stopCapture { _ in } }
        stream = nil
        if let window {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
            window.orderOut(nil)
        }
        window = nil
        layer.flushAndRemoveImage()
    }

    private func startStream() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let ownApp = content.applications.first { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let configuration = SCStreamConfiguration()
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 5
            configuration.showsCursor = true
            let filter: SCContentFilter
            switch source {
            case .window(let id):
                guard let scWindow = content.windows.first(where: { $0.windowID == id }) else { return }
                filter = SCContentFilter(desktopIndependentWindow: scWindow)
                configuration.width = Int(scWindow.frame.width * 2)
                configuration.height = Int(scWindow.frame.height * 2)
            case .region(let rect):
                guard let display = content.displays.first(where: { $0.frame.intersects(rect) }) ?? content.displays.first
                else { return }
                self.display = display
                filter = SCContentFilter(display: display, excludingApplications: ownApp.map { [$0] } ?? [], exceptingWindows: [])
                let local = CGRect(x: rect.minX - display.frame.minX, y: rect.minY - display.frame.minY,
                                   width: rect.width, height: rect.height)
                configuration.sourceRect = local
                configuration.width = Int(rect.width * 2)
                configuration.height = Int(rect.height * 2)
            case .pointer(let zoom):
                guard let display = content.displays.first else { return }
                self.display = display
                filter = SCContentFilter(display: display, excludingApplications: ownApp.map { [$0] } ?? [], exceptingWindows: [])
                let size = (window?.frame.size ?? CGSize(width: 520, height: 340))
                configuration.width = Int(size.width * 2)
                configuration.height = Int(size.height * 2)
                configuration.sourceRect = pointerRect(zoom: zoom, size: size, display: display)
            }
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
            try await stream.startCapture()
            await MainActor.run {
                self.stream = stream
                if case .pointer(let zoom) = self.source { self.follow(zoom: zoom, configuration: configuration) }
            }
        } catch {
            log.error("Screen mirror failed: \(error.localizedDescription)")
            await MainActor.run {
                self.stop()
                NotificationCenter.default.post(name: .monorailNeedsScreenRecording, object: nil)
            }
        }
    }

    /// The box around the pointer, in the display's own coordinates.
    private func pointerRect(zoom: CGFloat, size: CGSize, display: SCDisplay) -> CGRect {
        let mouse = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: mouse.x - display.frame.minX, y: primaryHeight - mouse.y - display.frame.minY)
        let w = size.width / zoom, h = size.height / zoom
        let x = min(max(point.x - w / 2, 0), display.frame.width - w)
        let y = min(max(point.y - h / 2, 0), display.frame.height - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func follow(zoom: CGFloat, configuration: SCStreamConfiguration) {
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, let stream = self.stream, let display = self.display, let window = self.window else { return }
            // The lens sits beside the pointer, out of its way.
            let mouse = NSEvent.mouseLocation
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: mouse.x + 30, y: mouse.y - size.height - 30))
            configuration.sourceRect = self.pointerRect(zoom: zoom, size: size, display: display)
            stream.updateConfiguration(configuration) { _ in }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        // Only complete frames carry an image.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let raw = attachments.first?[.status] as? Int, let status = SCFrameStatus(rawValue: raw), status != .complete
        {
            return
        }
        if layer.status == .failed { layer.flush() }
        layer.enqueue(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.stop() }
    }
}

extension Notification.Name {
    static let monorailNeedsScreenRecording = Notification.Name("monorailNeedsScreenRecording")
}

/// Draw on the screen: a pen over everything, Esc or the shortcut to finish.
final class AnnotationOverlay {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    var isShown: Bool { !windows.isEmpty }

    func toggle(color: NSColor) {
        isShown ? hide() : show(color: color)
    }

    func show(color: NSColor) {
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.01)
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let canvas = DrawingView(frame: NSRect(origin: .zero, size: screen.frame.size))
            canvas.color = color
            window.contentView = canvas
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.hide(); return nil }
            if event.charactersIgnoringModifiers == "c" { self?.windows.forEach { ($0.contentView as? DrawingView)?.clear() }; return nil }
            return event
        }
        NSCursor.crosshair.push()
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        NSCursor.pop()
    }

    private final class DrawingView: NSView {
        var color: NSColor = .systemPink
        private var strokes: [NSBezierPath] = []

        override func mouseDown(with event: NSEvent) {
            let path = NSBezierPath()
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: convert(event.locationInWindow, from: nil))
            strokes.append(path)
        }

        override func mouseDragged(with event: NSEvent) {
            strokes.last?.line(to: convert(event.locationInWindow, from: nil))
            needsDisplay = true
        }

        func clear() {
            strokes.removeAll()
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
            shadow.shadowBlurRadius = 3
            shadow.set()
            color.setStroke()
            strokes.forEach { $0.stroke() }
        }
    }
}

/// Shows the keys you press and where you click, for tutorials and webinars.
final class KeystrokeOverlay {
    private var panel: NSPanel?
    private var clickMonitor: Any?
    private var hideTimer: Timer?
    private var text = ""
    private let ripple = PointerLocator()
    private(set) var isOn = false

    func toggle() {
        isOn.toggle()
        if isOn {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.ripple.show(color: .systemYellow)
            }
        } else {
            if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
            clickMonitor = nil
            panel?.orderOut(nil)
        }
    }

    /// Called for every key press while on.
    func show(key: String) {
        guard isOn else { return }
        text = text.count > 24 ? key : (text.isEmpty ? key : text + "  " + key)
        let panel = self.panel ?? FocusFlash.makePanel()
        self.panel = panel
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        let size = label.fittingSize
        let box = NSView(frame: NSRect(x: 0, y: 0, width: size.width + 48, height: size.height + 24))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        box.layer?.cornerRadius = 14
        label.frame = NSRect(x: 24, y: 12, width: size.width, height: size.height)
        box.addSubview(label)
        panel.contentView = box
        let screen = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrame(NSRect(x: screen.midX - box.frame.width / 2, y: screen.minY + 60,
                              width: box.frame.width, height: box.frame.height), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            self?.text = ""
            self?.panel?.orderOut(nil)
        }
    }
}

/// Presenter notes: a panel only you see, even while sharing the whole screen.
final class PresenterNotes {
    private var window: NSPanel?
    var text: () -> String = { "" }
    var save: (String) -> Void = { _ in }

    func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
            return
        }
        let panel = window ?? makePanel()
        window = panel
        (panel.contentView as? NSScrollView).flatMap { $0.documentView as? NSTextView }?.string = text()
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
                            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = "Presenter notes · hidden from screen shares"
        panel.level = .floating
        panel.sharingType = .none
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let scroll = NSTextView.scrollableTextView()
        if let view = scroll.documentView as? NSTextView {
            view.font = .systemFont(ofSize: 16)
            view.isRichText = false
            view.delegate = delegate
        }
        delegate.onChange = { [weak self] text in self?.save(text) }
        panel.contentView = scroll
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - 400, y: screen.maxY - 290))
        }
        return panel
    }

    private let delegate = TextDelegate()

    private final class TextDelegate: NSObject, NSTextViewDelegate {
        var onChange: (String) -> Void = { _ in }
        func textDidChange(_ notification: Notification) {
            if let view = notification.object as? NSTextView { onChange(view.string) }
        }
    }
}

/// A round camera preview that floats over everything, for calls and recordings.
final class CameraTile {
    private var window: NSPanel?
    private var session: AVCaptureSession?

    func toggle() {
        if window != nil { hide() } else { show() }
    }

    private func show() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard granted else {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    return
                }
                self?.start()
            }
        }
    }

    private func start() {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        if session.canAddInput(input) { session.addInput(input) }
        let size: CGFloat = 200
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        view.layer?.cornerRadius = size / 2
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 3
        view.layer?.borderColor = NSColor.white.cgColor
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        view.layer?.addSublayer(preview)
        panel.contentView = view
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - size - 24, y: screen.minY + 24))
        }
        panel.orderFrontRegardless()
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        self.session = session
        window = panel
    }

    private func hide() {
        session?.stopRunning()
        session = nil
        window?.orderOut(nil)
        window = nil
    }
}
#endif
