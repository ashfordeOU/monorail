#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// Drag a window towards the top of the screen and a strip of layouts drops
/// down; let go over a zone to snap the window there. With edge snapping on, a floating window
/// pushed against a screen edge or corner snaps to a half or quarter (the top edge maximises),
/// with a preview of where it will go.
final class SnapPicker {
    /// Snaps the dragged window to a zone, on the display at a point (Accessibility coordinates).
    var snap: (WindowID, SnapPosition, CGPoint?) -> Void = { _, _, _ in }
    var isEnabled = true
    /// Edge and corner snapping for floating windows.
    var edgeSnapping = false
    /// Leave edge drags to macOS when its own edge tiling is on (macOS 15 and later).
    var defersToMacOS = true
    /// True for windows edge snapping applies to: floating ones (the strip places tiled windows).
    var isFloating: (WindowID) -> Bool = { _ in false }
    /// The gap around snapped windows, for the preview.
    var gap: () -> Double = { 8 }

    private let model = SnapPickerModel()
    private var panel: NSPanel?
    private var timer: Timer?
    private var dragging: WindowID?
    private var edgeSnapThisDrag = false
    private var edgeZone: (position: SnapPosition, point: CGPoint)?
    private let edgePreview = EdgeSnapPreview()

    /// The layouts offered, each a set of zones.
    static let groups: [[SnapPosition]] = [
        [.leftHalf, .rightHalf],
        [.firstThird, .centerThird, .lastThird],
        [.firstTwoThirds, .lastThird],
        [.firstThird, .lastTwoThirds],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.maximize],
    ]
    static let groupSize = CGSize(width: 76, height: 48)
    static let spacing: CGFloat = 10
    static let padding: CGFloat = 12
    static var panelSize: CGSize {
        let count = CGFloat(groups.count)
        return CGSize(
            width: padding * 2 + count * groupSize.width + (count - 1) * spacing,
            height: padding * 2 + groupSize.height)
    }

    /// Each zone's rectangle in the panel (top-left origin).
    static let zones: [(position: SnapPosition, group: Int, rect: CGRect)] = {
        var result: [(position: SnapPosition, group: Int, rect: CGRect)] = []
        for (g, group) in groups.enumerated() {
            let box = CGRect(
                x: padding + CGFloat(g) * (groupSize.width + spacing), y: padding,
                width: groupSize.width, height: groupSize.height)
            for position in group {
                let unit = position.unit
                let rect = CGRect(
                    x: box.minX + CGFloat(unit.minX) * box.width, y: box.minY + CGFloat(unit.minY) * box.height,
                    width: CGFloat(unit.width) * box.width, height: CGFloat(unit.height) * box.height)
                result.append((position: position, group: g, rect: rect.insetBy(dx: 1.5, dy: 1.5)))
            }
        }
        return result
    }()

    /// Called when the user starts dragging a window.
    func windowDragStarted(_ id: WindowID) {
        guard isEnabled || edgeSnapping, dragging == nil, NSEvent.pressedMouseButtons != 0 else { return }
        edgeSnapThisDrag = edgeSnapping && isFloating(id) && !(defersToMacOS && SystemEdgeTiling.isOn)
        guard isEnabled || edgeSnapThisDrag else { return }
        dragging = id
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.track() }
    }

    private func track() {
        guard let id = dragging else { return }
        let mouse = NSEvent.mouseLocation
        // The pointer can sit exactly on a screen's top or right edge: count that as on the screen.
        guard let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(mouse) }) else { return }
        let visible = screen.visibleFrame
        let size = Self.panelSize
        let origin = CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 6)

        if NSEvent.pressedMouseButtons == 0 {
            // Dropped: snap if over a zone.
            let zone = model.hovered.map { Self.zones[$0].position }
            let edge = edgeZone
            finish()
            if let zone {
                snap(id, zone, nil)
            } else if let edge {
                snap(id, edge.position, edge.point)
            }
            return
        }

        // Pushing against an edge or corner wins over the layouts strip.
        if edgeSnapThisDrag, let found = Self.edgePosition(mouse, on: screen) {
            if edgeZone?.position != found.position || edgeZone.map({ !screen.frame.contains(Self.appKitPoint($0.point)) }) == true {
                edgeZone = found
                edgePreview.show(found.position, on: screen, gap: gap())
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            hide()
            return
        }
        if edgeZone != nil {
            edgeZone = nil
            edgePreview.hide()
        }
        guard isEnabled else { return }

        let isShown = panel?.isVisible == true
        let near = mouse.y >= visible.maxY - 60 && abs(mouse.x - visible.midX) <= size.width / 2 + 80
        let stillNear = mouse.y >= visible.maxY - size.height - 70
        if !isShown && near {
            show(at: origin, size: size)
        } else if isShown && !stillNear {
            hide()
        }
        guard panel?.isVisible == true, let frame = panel?.frame else { return }
        let local = CGPoint(x: mouse.x - frame.minX, y: frame.maxY - mouse.y)
        let hovered = Self.zones.firstIndex { $0.rect.contains(local) }
        if model.hovered != hovered {
            model.hovered = hovered
            if hovered != nil { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        }
    }

    private func show(at origin: CGPoint, size: CGSize) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func hide() {
        model.hovered = nil
        panel?.orderOut(nil)
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        dragging = nil
        edgeZone = nil
        edgePreview.hide()
        hide()
    }

    /// The snap position for the pointer at `mouse` (AppKit coordinates) on `screen`, and the
    /// pointer in Accessibility coordinates (which display to snap on).
    private static func edgePosition(_ mouse: NSPoint, on screen: NSScreen) -> (position: SnapPosition, point: CGPoint)? {
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height, let index = screens.firstIndex(of: screen) else { return nil }
        let frames = screens.map { Rect(x: $0.frame.minX, y: primaryHeight - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        let point = CGPoint(x: mouse.x, y: primaryHeight - mouse.y)
        guard let position = EdgeSnapZones.position(x: point.x, y: point.y, in: frames[index],
                                                    sharedEdges: DisplayTargets.sharedEdges(of: index, in: frames))
        else { return nil }
        // Snap on the display itself: a point just inside it, whichever edge the pointer is on.
        let inside = CGPoint(x: min(max(point.x, frames[index].minX + 1), frames[index].maxX - 2),
                             y: min(max(point.y, frames[index].minY + 1), frames[index].maxY - 2))
        return (position, inside)
    }

    private static func appKitPoint(_ point: CGPoint) -> NSPoint {
        NSPoint(x: point.x, y: (NSScreen.screens.first?.frame.height ?? 0) - point.y)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: SnapPickerView(model: model))
        return panel
    }
}

final class SnapPickerModel: ObservableObject {
    /// Index into `SnapPicker.zones`.
    @Published var hovered: Int?
}

struct SnapPickerView: View {
    @ObservedObject var model: SnapPickerModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.12))
            ForEach(Array(SnapPicker.groups.indices), id: \.self) { g in
                let box = CGRect(
                    x: SnapPicker.padding + CGFloat(g) * (SnapPicker.groupSize.width + SnapPicker.spacing),
                    y: SnapPicker.padding, width: SnapPicker.groupSize.width, height: SnapPicker.groupSize.height)
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: box.width, height: box.height)
                    .offset(x: box.minX, y: box.minY)
            }
            ForEach(Array(SnapPicker.zones.enumerated()), id: \.offset) { index, zone in
                let on = model.hovered == index
                RoundedRectangle(cornerRadius: 5)
                    .fill(on ? Color.accentColor : Color.primary.opacity(0.18))
                    .frame(width: zone.rect.width, height: zone.rect.height)
                    .offset(x: zone.rect.minX, y: zone.rect.minY)
                    .animation(.easeOut(duration: 0.1), value: on)
            }
        }
        .frame(width: SnapPicker.panelSize.width, height: SnapPicker.panelSize.height)
    }
}
/// The translucent rectangle showing where an edge-snapped window will go.
final class EdgeSnapPreview {
    private var panel: NSPanel?

    /// Shows `position` on `screen`'s usable area.
    func show(_ position: SnapPosition, on screen: NSScreen, gap: Double) {
        let visible = screen.visibleFrame
        // SnapPosition's units run from the top; AppKit's frames from the bottom.
        let flipped = Rect(x: visible.minX, y: 0, width: visible.width, height: visible.height)
        let target = position.frame(in: flipped, gap: gap)
        let frame = NSRect(x: target.x, y: visible.maxY - target.y - target.height, width: target.width, height: target.height)
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = PreviewView()
        return panel
    }

    private final class PreviewView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)
            NSColor.controlAccentColor.withAlphaComponent(0.2).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 3
            path.stroke()
        }
    }
}

/// macOS 15 and later tile a window dragged to a screen edge by themselves (System Settings →
/// Desktop & Dock → "Drag windows to screen edges to tile").
enum SystemEdgeTiling {
    static var isOn: Bool {
        guard #available(macOS 15.0, *) else { return false }
        // Absent means the default, which is on.
        return UserDefaults(suiteName: "com.apple.WindowManager")?.object(forKey: "EnableTilingByEdgeDrag") as? Bool ?? true
    }

    /// Opens Desktop & Dock in System Settings, where it is turned on or off.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif
