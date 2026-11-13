#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// Live notch: on a MacBook with a notch, what's happening now sits beside it, black like the notch
/// itself: screen sharing, a meeting, a recording mode, a focus timer, low battery, an AI limit
/// running low, charging, Stay Awake. Nothing shows when nothing's happening. Click to open the panel.
final class NotchLive {
    static let shared = NotchLive()

    /// What's going on (set by the app delegate).
    var activities: () -> [NotchActivity] = { [] }
    var open: () -> Void = {}

    private var panel: NSPanel?
    private var timer: Timer?
    private let model = Model()

    final class Model: ObservableObject {
        @Published var top: NotchActivity?
        @Published var more = 0
    }

    func set(_ on: Bool) {
        if on, timer == nil {
            update()
            timer = Timer.every(2) { [weak self] _ in self?.update() }
            timer?.tolerance = 0.5
        } else if !on {
            timer?.invalidate()
            timer = nil
            panel?.orderOut(nil)
        }
    }

    private func update() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
              let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea,
              let picked = NotchActivity.pick(activities()) else {
            panel?.orderOut(nil)
            return
        }
        if model.top != picked.top { model.top = picked.top }
        if model.more != picked.more { model.more = picked.more }
        let height = screen.safeAreaInsets.top
        let wing: CGFloat = 92
        let frame = NSRect(x: left.maxX - wing, y: screen.frame.maxY - height, width: right.minX - left.maxX + wing * 2, height: height)
        let panel = self.panel ?? make()
        self.panel = panel
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func make() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: Pill(model: model, open: { [weak self] in self?.open() }))
        return panel
    }

    private struct Pill: View {
        @ObservedObject var model: Model
        let open: () -> Void

        var body: some View {
            if let top = model.top {
                HStack(spacing: 0) {
                    Image(systemName: top.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(top.tint))
                        .frame(width: 80, alignment: .center)
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Text(top.text).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                        if model.more > 0 { Text("+\(model.more)").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white.opacity(0.55)) }
                    }
                    .frame(width: 80, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(UnevenRoundedRectangleShim().fill(Color.black))
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(top.text))
            }
        }

        private func tint(_ name: String) -> Color {
            switch name {
            case "red": return Color(nsColor: .systemRed)
            case "green": return Color(nsColor: .systemGreen)
            case "blue": return Color(nsColor: .systemBlue)
            case "purple": return Color(nsColor: .systemPurple)
            default: return Color(nsColor: .systemOrange)
            }
        }
    }

    /// Square top corners (flush with the screen's edge), round bottom ones, like the notch.
    private struct UnevenRoundedRectangleShim: Shape {
        func path(in rect: CGRect) -> Path {
            let r = min(10, rect.height / 2)
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}
#endif
