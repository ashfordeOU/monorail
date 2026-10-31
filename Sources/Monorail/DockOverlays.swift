#if os(macOS)
import AppKit
import MonorailCore

/// Accessibility coordinates (top-left origin) to AppKit screen coordinates.
private func appKitRect(_ rect: CGRect) -> CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
}

/// The highlight showing where a dragged window will land.
final class DockPreview {
    private var panel: NSPanel?
    private var shown: CGRect?

    func show(_ rect: CGRect?, edge: SplitTree.Edge?) {
        guard let rect else {
            panel?.orderOut(nil)
            shown = nil
            return
        }
        guard rect != shown else { return }
        shown = rect
        let panel = self.panel ?? makePanel()
        self.panel = panel
        (panel.contentView as? PreviewView)?.isTab = edge == .center
        panel.contentView?.needsDisplay = true
        let frame = appKitRect(rect.insetBy(dx: 6, dy: 6))
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = PreviewView()
        return panel
    }

    private final class PreviewView: NSView {
        var isTab = false
        override func draw(_ dirtyRect: NSRect) {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 3
            path.stroke()
            let label = isTab ? "Tab group" : "Dock here"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.controlAccentColor,
            ]
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
        }
    }
}

/// Thin handles in the gaps between windows: drag one to resize the windows on both sides.
final class GapHandles {
    var handles: () -> [Engine.GapHandle] = { [] }
    var drag: (Engine.GapHandle, Double, Bool) -> Void = { _, _, _ in }
    private var panels: [NSPanel] = []
    private var current: [Engine.GapHandle] = []
    private var pending: DispatchWorkItem?
    private var dragging = false

    /// Refreshes the handles a moment after the layout settles (cheap when nothing changed).
    func refresh() {
        guard !dragging else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.apply() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func hide() {
        pending?.cancel()
        panels.forEach { $0.orderOut(nil) }
        current = []
    }

    private func apply() {
        let next = handles()
        guard next != current else { return }
        current = next
        while panels.count < next.count { panels.append(makePanel()) }
        for (index, panel) in panels.enumerated() {
            guard index < next.count else {
                panel.orderOut(nil)
                continue
            }
            let handle = next[index]
            (panel.contentView as? HandleView)?.handle = handle
            panel.setFrame(appKitRect(handle.frame), display: false)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = HandleView()
        view.onDrag = { [weak self] handle, delta, ended in
            guard let self else { return }
            self.dragging = !ended
            self.drag(handle, delta, ended)
            if ended { self.current = []; self.refresh() }
        }
        panel.contentView = view
        return panel
    }

    private final class HandleView: NSView {
        var handle: Engine.GapHandle?
        var onDrag: (Engine.GapHandle, Double, Bool) -> Void = { _, _, _ in }
        private var last: CGPoint?
        private var hovering = false

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: handle?.axis == .vertical ? .resizeUpDown : .resizeLeftRight)
        }

        override func updateTrackingAreas() {
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
        override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }

        override func draw(_ dirtyRect: NSRect) {
            // Invisible until the pointer is over it, then a short pill.
            guard hovering || last != nil, let handle else { return }
            let pill: CGRect
            if handle.axis == .horizontal {
                pill = CGRect(x: bounds.midX - 2, y: bounds.midY - 22, width: 4, height: 44)
            } else {
                pill = CGRect(x: bounds.midX - 22, y: bounds.midY - 2, width: 44, height: 4)
            }
            NSColor.controlAccentColor.withAlphaComponent(0.9).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 2, yRadius: 2).fill()
        }

        override func mouseDown(with event: NSEvent) { last = NSEvent.mouseLocation }

        override func mouseDragged(with event: NSEvent) {
            guard let handle, let last else { return }
            let now = NSEvent.mouseLocation
            // AppKit's y grows upwards; the layout's grows downwards.
            let delta = handle.axis == .horizontal ? now.x - last.x : last.y - now.y
            self.last = now
            if abs(delta) >= 0.5 { onDrag(handle, Double(delta), false) }
        }

        override func mouseUp(with event: NSEvent) {
            if let handle { onDrag(handle, 0, true) }
            last = nil
            needsDisplay = true
        }
    }
}
#endif
