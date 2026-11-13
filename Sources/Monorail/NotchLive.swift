#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI
import UniformTypeIdentifiers

/// The live notch, an island at the top of the screen. On a MacBook with a notch it grows out from under
/// the notch, black like it; on other Macs it's a pill at the top centre. It shows what's happening now
/// (screen sharing, a meeting, a focus timer, low battery, an AI limit running low, charging, Stay Awake),
/// grows into a card when the pointer rests on it, and keeps files dropped on it (the shelf) until you drag
/// them somewhere else. Nothing shows when nothing's happening. Click to open the panel.
final class NotchLive {
    static let shared = NotchLive()

    /// What's going on (set by the app delegate).
    var activities: () -> [NotchActivity] = { [] }
    var open: () -> Void = {}

    private var panel: NSPanel?
    private var timer: Timer?
    private var dragMonitor: Any?
    private var collapseWork: DispatchWorkItem?
    let model = Model()

    final class Model: ObservableObject {
        @Published var list: [NotchActivity] = []
        @Published var expanded = false
        @Published var dropping = false
        @Published var shelf = NotchShelf()
        @Published var hasNotch = true
        @Published var notchWidth: CGFloat = 190
        @Published var notchHeight: CGFloat = 32
        static let wing: CGFloat = 92
        var compactWidth: CGFloat { hasNotch ? notchWidth + Self.wing * 2 : 230 }
        var compactHeight: CGFloat { hasNotch ? notchHeight : max(notchHeight - 2, 22) }
        var expandedWidth: CGFloat { max(compactWidth, 440) }
        var expandedHeight: CGFloat { compactHeight + 210 }
        var big: Bool { expanded || dropping }
        var visible: Bool { !list.isEmpty || !shelf.isEmpty || big }
    }

    private static let shelfKey = "NotchShelf"

    init() {
        // Monorail keeps the shelf across restarts; the App Store edition only has access to dropped files
        // until it quits, so it starts empty.
        if !Edition.isAppStore, let saved = UserDefaults.standard.stringArray(forKey: Self.shelfKey) {
            model.shelf = NotchShelf(paths: saved.filter { FileManager.default.fileExists(atPath: $0) })
        }
    }

    func set(_ on: Bool) {
        if on, timer == nil {
            update()
            timer = Timer.every(2) { [weak self] _ in self?.update() }
            timer?.tolerance = 0.5
            watchDrags()
        } else if !on {
            timer?.invalidate()
            timer = nil
            if let dragMonitor { NSEvent.removeMonitor(dragMonitor) }
            dragMonitor = nil
            panel?.orderOut(nil)
        }
    }

    // MARK: Where it goes

    private var screen: NSScreen? { NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main }

    private func centreX(_ screen: NSScreen) -> CGFloat {
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { return (left.maxX + right.minX) / 2 }
        return screen.frame.midX
    }

    private func frame(big: Bool) -> NSRect? {
        guard let screen else { return nil }
        let width = big ? model.expandedWidth : model.compactWidth
        let height = big ? model.expandedHeight + 24 : model.compactHeight
        return NSRect(x: centreX(screen) - width / 2, y: screen.frame.maxY - height, width: width, height: height)
    }

    func update() {
        guard let screen else { panel?.orderOut(nil); return }
        let notch = screen.safeAreaInsets.top > 0
        if model.hasNotch != notch { model.hasNotch = notch }
        if notch, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            if model.notchWidth != width { model.notchWidth = width }
            if model.notchHeight != screen.safeAreaInsets.top { model.notchHeight = screen.safeAreaInsets.top }
        } else {
            let bar = screen.frame.maxY - screen.visibleFrame.maxY
            if model.notchHeight != max(bar, 24) { model.notchHeight = max(bar, 24) }
        }
        let list = NotchActivity.ranked(activities())
        if model.list != list { withAnimation(Motion.reorder) { model.list = list } }
        place()
    }

    private func place() {
        guard model.visible, let target = frame(big: model.big) else {
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? make()
        self.panel = panel
        // Growing: make room first, then the island springs into it. Shrinking waits for the spring.
        if target.width >= panel.frame.width || target.height >= panel.frame.height || !panel.isVisible {
            panel.setFrame(target, display: true)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
                guard let self, !self.model.big, let small = self.frame(big: false) else { return }
                self.panel?.setFrame(small, display: true)
            }
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func make() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: Island(model: model, actions: .init(
            open: { [weak self] in self?.open() },
            hover: { [weak self] inside in self?.hover(inside) },
            drop: { [weak self] urls in self?.keep(urls) },
            remove: { [weak self] url in self?.forget(url) },
            clear: { [weak self] in self?.clearShelf() })))
        return panel
    }

    // MARK: Hover, drags and the shelf

    private func hover(_ inside: Bool) {
        collapseWork?.cancel()
        if inside {
            guard !model.expanded else { return }
            let work = DispatchWorkItem { [weak self] in self?.setExpanded(true) }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        } else {
            let work = DispatchWorkItem { [weak self] in self?.setExpanded(false) }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        }
    }

    private func setExpanded(_ on: Bool) {
        guard model.expanded != on else { return }
        if on { model.expanded = true; place() } else { model.expanded = false; place() }
    }

    /// While files are being dragged near the top of the screen, the island opens as a drop target.
    private func watchDrags() {
        guard dragMonitor == nil else { return }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self, let screen = self.screen else { return }
            if event.type == .leftMouseUp {
                if self.model.dropping { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.model.dropping = false; self.place() } }
                return
            }
            let mouse = NSEvent.mouseLocation
            let near = abs(mouse.x - self.centreX(screen)) < 300 && screen.frame.maxY - mouse.y < 140 && screen.frame.contains(mouse)
            let files = NSPasteboard(name: .drag).types?.contains(.fileURL) == true
            if near, files, !self.model.dropping { self.model.dropping = true; self.place() }
        }
    }

    private func keep(_ urls: [URL]) {
        model.shelf.add(urls.map(\.path))
        model.dropping = false
        save()
        place()
    }

    private func forget(_ url: URL) { model.shelf.remove(url.path); save(); place() }
    private func clearShelf() { model.shelf.clear(); save(); place() }
    private func save() { if !Edition.isAppStore { UserDefaults.standard.set(model.shelf.paths, forKey: Self.shelfKey) } }

    // MARK: The view

    struct Actions {
        var open: () -> Void
        var hover: (Bool) -> Void
        var drop: ([URL]) -> Void
        var remove: (URL) -> Void
        var clear: () -> Void
    }

    private struct Island: View {
        @ObservedObject var model: Model
        let actions: Actions
        @State private var targeted = false

        private var spring: Animation { Motion.reduced ? .easeOut(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.76) }

        var body: some View {
            let big = model.big
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    IslandShape(radius: big ? 24 : (model.hasNotch ? 10 : model.compactHeight / 2), flatTop: model.hasNotch)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(big ? 0.45 : 0), radius: 18, y: 8)
                        .overlay(IslandShape(radius: big ? 24 : 10, flatTop: model.hasNotch)
                            .stroke(targeted ? Color(nsColor: .systemTeal) : Color.white.opacity(big ? 0.08 : 0), lineWidth: targeted ? 2 : 1))
                    VStack(spacing: 0) {
                        wings.frame(height: model.compactHeight)
                        if big { card.transition(.opacity.combined(with: .move(edge: .top))) }
                    }
                }
                .frame(width: big ? model.expandedWidth : model.compactWidth, height: big ? model.expandedHeight : model.compactHeight)
                .contentShape(Rectangle())
                .onHover(perform: actions.hover)
                .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
                    load(providers)
                    return true
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(spring, value: big)
            .animation(spring, value: targeted)
            .environment(\.colorScheme, .dark)
        }

        // The two sides of the notch: what's most important now, and how many more.
        private var wings: some View {
            HStack(spacing: 0) {
                Group {
                    if let top = model.list.first {
                        Image(systemName: top.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(top.tint))
                            .pulsing(top.kind == .sharing || top.kind == .call || top.kind == .recording)
                            .id(top.symbol)
                            .transition(.scale.combined(with: .opacity))
                    } else if !model.shelf.isEmpty {
                        Image(systemName: "tray.full.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(nsColor: .systemTeal))
                    } else if model.dropping {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(nsColor: .systemTeal))
                    }
                }
                .frame(width: Model.wing, alignment: .center)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    if let top = model.list.first {
                        Text(top.text).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                            .rolling(top.text)
                        if model.list.count > 1 { Text("+\(model.list.count - 1)").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white.opacity(0.55)) }
                    } else if !model.shelf.isEmpty {
                        Text("\(model.shelf.paths.count)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white).rolling(model.shelf.paths.count)
                    }
                }
                .frame(width: Model.wing, alignment: .center)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: actions.open)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(model.list.first?.text ?? (model.shelf.isEmpty ? "Monorail" : "\(model.shelf.paths.count) files on the shelf")))
        }

        // The card the island grows into: everything going on, then the shelf.
        private var card: some View {
            VStack(alignment: .leading, spacing: 10) {
                if model.dropping || targeted {
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(Color(nsColor: .systemTeal))
                            .bounces(on: targeted)
                        Text(targeted ? "Let go to keep it here" : "Drop files to keep them on the shelf").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Text("Drag them out again to wherever they're going.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(nsColor: .systemTeal).opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                } else {
                    if !model.list.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(model.list.prefix(3).enumerated()), id: \.offset) { _, activity in
                                HStack(spacing: 9) {
                                    Image(systemName: activity.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(activity.tint))
                                        .frame(width: 26, height: 26).background(Circle().fill(tint(activity.tint).opacity(0.18)))
                                    Text(title(activity.kind)).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white)
                                    Spacer()
                                    Text(activity.text).font(.system(size: 12.5, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white.opacity(0.85)).rolling(activity.text)
                                }
                            }
                        }
                    }
                    NowPlayingRow()
                    shelf
                }
                HStack {
                    Spacer()
                    Button(action: actions.open) { Label("Open \(Brand.name)", systemImage: "rectangle.on.rectangle") }
                        .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
        }

        private var shelf: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SHELF").font(.system(size: 10, weight: .semibold)).kerning(0.6).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    if !model.shelf.isEmpty {
                        Button("AirDrop") { NSSharingService(named: .sendViaAirDrop)?.perform(withItems: model.shelf.paths.map { URL(fileURLWithPath: $0) }) }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(nsColor: .systemTeal))
                        Button("Clear", action: actions.clear).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                if model.shelf.isEmpty {
                    Text("Drag files onto the notch to keep them here for a moment.").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(model.shelf.paths, id: \.self) { path in
                                let url = URL(fileURLWithPath: path)
                                VStack(spacing: 4) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 38, height: 38)
                                    Text(url.lastPathComponent).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.8)).lineLimit(1).frame(width: 64)
                                }
                                .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                                .contextMenu {
                                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                    Button("Open") { NSWorkspace.shared.open(url) }
                                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([url as NSURL]) }
                                    Button("AirDrop") { NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [url]) }
                                    Divider()
                                    Button("Remove from Shelf") { actions.remove(url) }
                                }
                                .help(path)
                            }
                        }
                    }
                }
            }
        }

        private func load(_ providers: [NSItemProvider]) {
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { urls.append(url) } }
                    group.leave()
                }
            }
            group.notify(queue: .main) { actions.drop(urls) }
        }

        private func title(_ kind: NotchActivity.Kind) -> String {
            switch kind {
            case .sharing: return "Sharing your screen"
            case .call: return "On a call"
            case .recording: return "Recording"
            case .timer: return "Focus"
            case .batteryLow: return "Battery low"
            case .aiLimit: return "AI limit"
            case .charging: return "Charging"
            case .awake: return "Staying awake"
            case .mode: return "Mode"
            case .music: return NowPlaying.shared.track.map { "\($0.title) · \($0.artist)" } ?? "Playing"
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

    /// The island's outline: square top corners flush with the screen's edge under a notch (round everywhere
    /// as a pill on Macs without one), round bottom corners that grow as it opens.
    private struct IslandShape: Shape {
        var radius: CGFloat
        var flatTop: Bool
        var animatableData: CGFloat { get { radius } set { radius = newValue } }

        func path(in rect: CGRect) -> Path {
            let r = min(radius, rect.height / 2, rect.width / 2)
            if !flatTop { return Path(roundedRect: rect, cornerRadius: r, style: .continuous) }
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

extension View {
    /// A gentle pulse for things that are live (sharing, a call, recording).
    @ViewBuilder func pulsing(_ on: Bool) -> some View {
        if #available(macOS 14, *), on, !Motion.reduced { self.symbolEffect(.pulse, options: .repeating) } else { self }
    }
}
#endif
