#if os(macOS)
import AppKit
import MonorailCore

/// The menu bar panel's background, following the Mac's own appearance settings:
/// Liquid Glass on macOS 26, frosted glass before it, solid with Reduce Transparency, and a firmer
/// edge with Increase Contrast. Under the glass there's always a soft layer of the window colour, so
/// white text stays readable over a bright wallpaper (and dark text over a dark one).
enum PanelBackground {
    static func make(_ content: NSView, style: MonorailCore.PanelGlass) -> NSView {
        let workspace = NSWorkspace.shared
        let solid = workspace.accessibilityDisplayShouldReduceTransparency || style == .solid
        let contrast = workspace.accessibilityDisplayShouldIncreaseContrast

        if #available(macOS 26.0, *), style == .automatic, !solid, !contrast {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 16
            let stack = NSView()
            let backing = LegibilityLayer(strength: 0.18)
            pin(backing, in: stack)
            pin(content, in: stack)
            glass.contentView = stack
            return glass
        }

        let glass = NSVisualEffectView()
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 16
        glass.layer?.cornerCurve = .continuous
        glass.layer?.masksToBounds = true
        glass.layer?.borderWidth = contrast ? 1 : 0.5
        glass.layer?.borderColor = (contrast ? NSColor.labelColor.withAlphaComponent(0.5) : NSColor.separatorColor).cgColor
        let strength: CGFloat = solid ? 1 : (style == .frosted || contrast ? 0.6 : 0.3)
        pin(LegibilityLayer(strength: strength), in: glass)
        pin(content, in: glass)
        return glass
    }

    private static func pin(_ view: NSView, in parent: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            view.topAnchor.constraint(equalTo: parent.topAnchor),
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
    }

    /// A wash of the window colour for the current appearance (dark in Dark Mode, light in Light).
    private final class LegibilityLayer: NSView {
        let strength: CGFloat
        init(strength: CGFloat) {
            self.strength = strength
            super.init(frame: .zero)
            wantsLayer = true
        }
        required init?(coder: NSCoder) { fatalError() }
        override var wantsUpdateLayer: Bool { true }
        override func updateLayer() {
            var colour = NSColor.windowBackgroundColor.cgColor
            effectiveAppearance.performAsCurrentDrawingAppearance { colour = NSColor.windowBackgroundColor.withAlphaComponent(strength).cgColor }
            layer?.backgroundColor = colour
        }
        override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
#endif
